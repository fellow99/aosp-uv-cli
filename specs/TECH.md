# TECH.md —— `aosp-uv-cli` 技术选型（as-built + 规划引用）

> **性质**：项目级技术选型规格。回答「用了什么、什么版本、为什么、**否掉了什么**」；**每行带状态列**（✅已实现 / ⬜规划引用）。
> **依据**：`specs/constitution.md`（P1–P8）· [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（唯一规划基线 v2.0，下称「规划 §」）· 本仓库文件 ✅实测。
> **版本**：v1.0 · 2026-11-02 · 状态：**M0 骨架已完成**（规划 §10）；M1 真实交叉编译未开工。
> **纪律**：⬜ 条目只允许以「规划引用」出现（宪法 P6）；「选定」一律给理由，「否掉」一律给替代方案。

---

## 1. 选型总表（含已实现 vs 规划状态列）

| 类别 | 技术/版本 | 用途 | 选型理由 | 状态 |
|---|---|---|---|---|
| **构建系统** | Gradle **9.4.1**（CI `setup-gradle@v4` 钉版；本地执行记录同版） | 配置/打包 AAR | 与 workspace 其余四条 CLI 线（pty/python/git/pnpm）同代；scaffold CI 已验证「无 `.so` 可配置」 | ✅（仓库无 Wrapper，见 STRUCTURE §2.2-2） |
| **Android 插件** | AGP **9.2.1**（`gradle/libs.versions.toml:2`） | `com.android.library` 模块 | workspace 统一口径；`compileSdk 36` / `minSdk 24` | ✅ |
| **模块形态** | `:uv-cli` Android library，**无任何 Kotlin/Java 源**——纯 AAR 容器 | 承载 `jni/arm64-v8a/libuv_cli.so` | exec 型工具的发布物只是「一个原生可执行的容器」；`useLegacyPackaging=true`（D1）物理落盘 `nativeLibraryDir` | ✅（`uv-cli/build.gradle.kts:11,28-44`） |
| **发布插件** | `com.vanniktech:gradle-maven-publish-plugin` **0.37.0**（settings pluginManagement） | Maven Central 发布面 | workspace 统一；`coordinates(io.github.fellow99, uv-cli, CLI_VERSION)`；RELEASE=false 默认禁用 Central/签名任务 | ✅（发布动作 ⬜ M3） |
| **坐标版本源** | `CLI_VERSION` = **uv 上游版本，独立 semver**（当前 draft `0.9.0`） | 制品版本 | D2：无 NODE_MODULE_VERSION 约束 ⇒ 不与 node 系配对；uv 发版频繁，跟随节奏独立于 python-cli | ✅ 接线（`build.gradle.kts:16-17` + publication 反射覆写 :19-26）；版本值 ⬜ 首产按 CI 实际钉选回写 |
| **打包语义** | `useLegacyPackaging = true`（=`extractNativeLibs=true`） | exec 型硬要求 | D1：targetSdk≥29 SELinux 禁止从 app 数据目录 exec ⇒ 必须物理落盘 `nativeLibraryDir`；`false` 时库从 APK mmap 不落盘，`execve` ENOENT | ✅（`build.gradle.kts:42` + lock `matrix.execPackaging`） |
| **目标 ABI** | 仅 **arm64-v8a**（`abiFilters`） | 产物平台 | workspace 纪律：一条制品线一个 ABI（规划 §13；工作区方案 §9.2） | ✅ |
| **门禁工具（host）** | 纯 Node `.mjs`（`tools/provision.mjs`，276 行；内置极简 ELF64 小端解析，零第三方依赖） | 投放 + exec 七门禁 + 元数据 | 「一个 `node` 就能跑」⇒ CI/消费方机器零依赖；与 pty/python/git/pnpm 各仓 provision 同族同纪律（退出码 0/2/1） | ✅ |
| **事实源** | `uv-cli.lock.json`（严格 JSON） | 版本 + size + sha256 + 门禁 + 出处 + `matrix.allowedNeeded` | P2：lock 唯一事实源；draft 不伪造哈希（`size:0`/`sha256:""`） | ✅（draft 态；released 回写 ⬜ M1） |
| **源获取（host）** | `scripts/fetch-uv-cli-source.mjs`（53 行骨架，exit 2 SCAFFOLD） | 拉 uv 官方源码 tarball（不改源，P1） | scaffold 只固化 `--uv/--out` 接口；下载/SHA-256/解压 ⬜ M1-T2 | ✅ 接口 / ⬜ 行为 |
| **交叉编译（host）** | `scripts/build-uv-cli-android.sh`（58 行骨架，exit 2 SCAFFOLD） | Rust 交叉编译 + strip | scaffold 固化 `--uv/--api/--src/--ndk/--out` 与七条纪律注释；真实编译链 ⬜ M1-T3/T4 | ✅ 接口 / ⬜ 行为 |
| **Rust 工具链** | rustup stable（钉版）+ target `aarch64-linux-android`（官方 tier2）+ cargo-ndk（备选 `.cargo/config.toml` linker） | 编译 uv 为 Android arm64 exec 型 PIE | tier2 target rustup 直装 std，无需自建；cargo-ndk 失败退 config.toml（两路径等价）；工具链版本是可复现性输入，钉进 lock | ⬜ 规划引用（规划 §4.1） |
| **16KB 页** | `RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"` | 16KB 页设备硬要求 | 门禁 ⑦（min LOAD align ≥ 0x4000）强制；仅 bring-up 可 `--allow-page-align-4k` 放行 | 门禁 ✅ / 编译接线 ⬜ |
| **TLS 栈** | rustls + 编译期内嵌根证书（webpki-roots 口径）；禁用系统证书目录探测；crypto provider（ring / aws-lc-rs）以 M1 试编定 | uv 的 HTTPS | D4：Android 无 `/etc/ssl/certs`；单二进制自包含；`SSL_CERT_FILE` 是 python-cli 侧 pip 口径，与 uv 无关 | ⬜ 规划引用（规划 §4.1/§4.3） |
| **C 依赖探针** | ring（预生成 arm64 汇编 + cc）/ zstd-sys（cc 编 vendored C 源）等 `*-sys` | M1-T1 首项试编 | 本工程最大新工：cc 类依赖在 NDK clang 下的可编性先证后编；降级路径（provider 切换 / feature 裁剪）如实记录 | ⬜ 规划引用（规划 §4.3/§11 R1/R2） |
| **CI** | GitHub Actions，`ubuntu-24.04` + JDK 21（temurin）+ Gradle 9.4.1 + Node | scaffold 配置期门禁 | M0 只验证「配置期不求值失败 + 工具纪律」；真实流水线（rustup/cargo-ndk/缓存/Release）M1 并入同文件替换 | ✅ scaffold / ⬜ 真实流水线（规划 §9） |
| **发布** | 两段式：① GitHub Release 先行（归档 + `.sha256` + cargo license 清单，lock 回写 `released`）；② Maven Central 随后（M3，runbook 口径） | 分发 | workspace 统一两段式；`RELEASE=false` + 用户级凭据防误发（P5） | 发布面 ✅ / 两段动作 ⬜（规划 §10.1） |
| **许可** | 本仓 **MIT**（`LICENSE` 21 行）；uv 本体 **MIT OR Apache-2.0**（`uv-cli/THIRD-PARTY-NOTICES.md`） | 合规交付物 | cargo 依赖许可清单随 GitHub Release 归档（规划 §12） | ✅（清单归档 ⬜ M1） |

---

## 2. 被**否掉**的选型及替代方案（含规划依据）

| 被否对象 | 否掉理由（一手依据） | 替代方案（现状） |
|---|---|---|
| **`useLegacyPackaging=false`**（dlopen 库口径） | exec 要求物理落盘 `nativeLibraryDir`；targetSdk≥29 SELinux 禁止从 filesDir exec，不落盘 `execve` ENOENT（规划 §3.1 D1） | `useLegacyPackaging=true` ✅（与 pty 的 dlopen 线**相反**，见 ARCHITECTURE §④） |
| **AAR 自带 `libc++_shared.so`** | D5：同 App 内 node-runtime 已供给，重复携带会包内同名冲突；exec 子进程走默认 linker namespace 看不到 App 库目录 ⇒ 靠消费方注入 `LD_LIBRARY_PATH` | jniLibs 仅 `libuv_cli.so`（provision 兄弟文件检查 + `BANNED_IN_AAR` 纪律）；替代：`-static-libstdc++` 静态链 ⬜（规划 §4.4，须先改规划拍板） |
| **`libuv.so` / 无 `_cli` 后缀命名** | Android 打包只认 `lib*.so`；`libuv.so` 与 libuv 库同名混淆（D6） | `libuv_cli.so`（`provision.mjs:36` DEFAULT_BINARY）✅ |
| **拉取上游任何平台二进制改名复用**（含构建期） | D3/C2（P7）：上游无 Android 官方产物；可执行代码不下载，构建期同纪律 | 一律 CI 源码自建（源码 tarball + Cargo.lock 钉版，`--locked`）⬜ M1 |
| **`uv python install` / managed python** | 运行期下载可执行 = P7 红线；且 python-build-standalone 构件非 Android 形态（D7） | 解释器来自 `aosp-python-cli`（`UV_PYTHON` 组合契约 ⬜ M2）；边界写入消费方文档 |
| **uv 内嵌 python** | 一仓一版本线、职责单一（D7） | 组合契约：`UV_PYTHON` 指向 python-cli 物化解释器 ⬜ |
| **与 node 系版本配对**（NODE_MODULE_VERSION 约束） | Rust 产物无该 ABI 约束（D2） | 版本 = uv 上游版本独立 semver ✅ |
| **运行期下载可执行（任何形式）** | P7 红线（宪法） | 缓存/venv 全落 filesDir；不随包、不物化、不下载 ⬜（运行期契约，规划 §7） |

---

## 3. 版本矩阵与兼容口径（as-built 值）

| 维度 | 值 | 来源 |
|---|---|---|
| 工程名 / 模块 | `aosp-uv-cli` / 仅 `:uv-cli` | `settings.gradle.kts:20-21` ✅ |
| 制品坐标 | `io.github.fellow99:uv-cli:<CLI_VERSION>`（当前 draft **0.9.0**） | `gradle.properties:7` + `uv-cli.lock.json:3-6` ✅ |
| CLI_VERSION 语义 | = uv 上游版本，独立 semver，无配对 | 规划 §2 ✅ |
| compileSdk / minSdk | 36 / 24 | `uv-cli/build.gradle.kts:30-32` ✅ |
| ABI | `arm64-v8a`（唯一） | `uv-cli/build.gradle.kts:33-35` + lock `matrix.abi` ✅ |
| namespace | `org.fellow99.uvcli` | `uv-cli/build.gradle.kts:29` ✅ |
| 门禁基线 | PT_INTERP=`/system/bin/linker64`；DT_NEEDED ⊆ `matrix.allowedNeeded`（6 项，含 `libc++_shared.so` 不随包）；16KB 页 | `provision.mjs:146-160` + lock `matrix.allowedNeeded` ✅ |
| lock 状态 | `status="draft"`（size=0 / sha256=""） | `uv-cli.lock.json:9-14,34` ✅ |
| 真实产物基线 | **尚无**（首产 M1 实测后回填：size/sha256/DT_NEEDED 实测清单/NDK/rust 版本） | ⬜ 规划 §8 |

---

## 4. 依赖清单（运行时 / 构建期）

| 依赖 | 谁提供 | 何时需要 | 缺失后果 | 状态 |
|---|---|---|---|---|
| Gradle 9.4.1 + JDK 21 | runner / 本机（无 Wrapper） | 配置 + 打包 | 配置期失败 | ✅ |
| AGP 9.2.1 + vanniktech 0.37.0 | google()/mavenCentral()/gradlePluginPortal | 配置 | 同上 | ✅ |
| Node（支持 ESM 即可） | 开发机 / runner | provision + fetch 脚本 | 门禁/投放跑不了 | ✅ |
| uv 源码 tarball（含 `Cargo.lock`） | 上游 releases（fetch 校验 SHA-256） | M1 构建 | 无从构建 | ⬜ |
| rustup stable + `aarch64-linux-android` target + cargo-ndk | rustup / cargo install | M1 交叉编译 | 无产物 | ⬜ |
| Android NDK（与 aosp-node-runtime 对齐线，r28c 或更高 ⬜） | runner | M1 编译/strip（`llvm-strip`） | 无产物 | ⬜ |
| `libc++_shared.so`（若产物 DT_NEEDED） | **消费方包内 node-runtime**（不随包，D5） | 运行期 + 消费方注入 `LD_LIBRARY_PATH` | exec 启动失败（P6 探针核验项） | ⬜ 运行期契约（规划 §4.4/§7） |
| `git`（PATH，仅 git 依赖源场景） | `aosp-git-cli` 线组合 | 运行期 `uv pip install git+…` | 该功能不可用（边界，见 overall-spec §4） | ⬜ 组合项 |
| python 解释器 | `aosp-python-cli` 物化产物 | 运行期 venv / `uv run` | uv 无默认 python（`UV_PYTHON` 钉死） | ⬜ 组合契约（D7） |

---

## 5. 选型层面的未决 / 风险（⬜，规划引用）

| # | 项 | 现状 | 处置（规划锚点） |
|---|---|---|---|
| 1 | ring / zstd-sys 等 cc 类依赖的 NDK 可编性 | ⬜ M1-T1 首项试编 | 判据先行（`cargo build --target --locked` 过 + provision 全门禁）；降级：crypto provider 切换 / feature 裁剪，如实回写规划（§4.3 / R1/R2） |
| 2 | aws-lc-rs 若入依赖树（cmake/go 构建复杂） | ⬜ 以 Cargo.lock 实际清单为准 | 优先钉 provider=ring（R2） |
| 3 | 体积超标（预估 25–40 MB 量级 ⬜） | ⬜ 无实测 | strip + 首产实测回填 lock；超标评估 release profile 收缩，先改规划（R3） |
| 4 | `libc++_shared.so` 运行期供给依赖消费方含 node-runtime | ⬜ P6 探针核验 | 消费方文档写明；静态链替代 ⬜ 需求真实出现再拍板（§4.4 / R5） |
| 5 | rustls 根证书是否默认内嵌生效 | ⬜ P3 真机 HTTPS 探针 | M1 编译期特性钉定 + 探针核验（R6） |
| 6 | Cargo 依赖 sha 记录粒度（方案 A：Cargo.lock 整文件 + license 清单；方案 B：逐 crate sha） | ⬜ M1 拍板 | 倾向 A + cc 类 C 依赖逐条；拍板后回写规划并按新粒度回填 lock（§8 / R7） |
| 7 | uv 对平台的隐含假设（python 发现、临时目录、git 探测） | ⬜ 无实测 | 环境注入矫正（规划 §7）+ P1–P6 事实记录（R8） |

---

## 6. 关键技术口径（实现必须对齐的硬数据）

### 6.1 exec 型七门禁（✅ 已实现，`tools/provision.mjs` `gates()` :132-169）

| # | 判据 | 实现落点（行号 = 2026-11-02 快照） | 与 pty（dlopen 库）门禁的差异 |
|---|---|---|---|
| ① | `e_type == ET_DYN`（PIE 可执行，值 3） | `provision.mjs:146` | 同 |
| ② | **PT_INTERP 恰 1 个且内容 = `/system/bin/linker64`** | `provision.mjs:148-150`（`parseElf` :76-90 提取 interp 内容） | **相反**（pty 要求 PT_INTERP=0） |
| ③ | `e_machine == AArch64`（值 183） | `provision.mjs:151` | 同 |
| ④ | **DT_NEEDED 全部在白名单**（`lock.matrix.allowedNeeded`，6 项） | `provision.mjs:153-155` | pty 是「必须含 libnode.so」；本仓是**白名单制** |
| ⑤ | SHA-256 与锁一致（draft 无锁值 ⇒ 仅记录） | `provision.mjs:141,156-157` | 同（draft 语义同 pty） |
| ⑥ | 大小与锁一致（draft ⇒ 仅记录） | `provision.mjs:142,158-159` | 同 |
| ⑦ | **16KB 页对齐**（min LOAD align ≥ 0x4000） | `provision.mjs:140,160`（`--allow-page-align-4k` 仅 bring-up，:162-167） | 同 |
| 附 | **无 NAPI 门禁**（CLI 是独立进程，不解析 napi_*） | 设计说明 `provision.mjs:14` | pty 有「未定义 napi_* 引用」门禁，本仓删除 |
| 附 | jniLibs **兄弟文件检查**：目录内仅 `libuv_cli.so` | `provision.mjs:222-225`（`--check` 路径） | 本仓特有（exec 型单文件纪律） |
| 附 | `BANNED_IN_AAR=['libnode.so']` 投放后校验 | `provision.mjs:38,246-250` | 同族纪律（node-runtime 统一供给） |

### 6.2 退出码纪律（✅ 三条工具同口径）

| 退出码 | 语义 | 实现落点 |
|---|---|---|
| `0` | 门禁全过 / 投放成功 / `--help` | `provision.mjs:205,228,268`；fetch `:43` |
| `2` | 门禁不合格 / **未投放**（`--check` 且目标缺失）/ SCAFFOLD 未实现 | `provision.mjs:215-217,236-238`；fetch `:53`；build.sh `:58` |
| `1` | 用法 / IO / 未知 release / 顶层异常 | `provision.mjs:231,271-276`；fetch `:43`；build.sh `:50-53` |

### 6.3 命令速查（host 侧，全部 ✅ 可跑）

| 目的 | 命令 |
|---|---|
| 配置期门禁（无 `.so` 必须过） | `gradle :uv-cli:tasks --console=plain` |
| 校验已投放产物（未投放 = exit 2） | `node tools/provision.mjs --check` |
| 打印某产物门禁报告（不写文件） | `node tools/provision.mjs --inspect <libuv_cli.so>` |
| 投放 | `node tools/provision.mjs --out uv-cli/src/main/jniLibs --from build/out/libuv_cli.so` |
| 选定 release | `--version <ver> --abi <abi>`（默认取 `lock.active`） |
| 取源（M1 前为 SCAFFOLD exit 2） | `node scripts/fetch-uv-cli-source.mjs --uv <ver> --out .dist/src` |
| 编译（M1 前为 SCAFFOLD exit 2） | `bash scripts/build-uv-cli-android.sh --uv <ver> --api 24 --src <树> --ndk <dir> --out <dir>` |
