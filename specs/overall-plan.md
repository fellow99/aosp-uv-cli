# overall-plan.md —— `io.github.fellow99:uv-cli` 整体技术方案

> **性质**：项目级**实现计划**（怎么做、按什么顺序做、宪法如何逐条对齐、跨切面怎么处理）。
> **上位约束**：`specs/constitution.md`（P1–P8 / S1–S10）· [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（唯一规划基线 v2.0，下称「规划 §」）。本文引用其 § 号，不复制正文。
> **标记**：✅实测 / ⬜规划引用 / ⚠️事实性观察。
> **版本**：v1.0 · 2026-11-02 · 状态：**M0 已完成**（规划 §10；scaffold 提交前验证 2026-11-02，见 `000-scaffold/test-cases.md`）；M1 未开工。

---

## 1. Technical Context

### 1.1 运行环境与工具链

| 项 | 值 | 证据 |
|---|---|---|
| Gradle | 9.4.1（CI `setup-gradle@v4` 钉版；无 Wrapper ⚠️） | workflow `:29-32` ✅ · `000-scaffold/test-cases.md` 头注 |
| AGP / JDK | 9.2.1 / 21（temurin） | `gradle/libs.versions.toml:2` ✅ · workflow `:23-27` ✅ |
| 发布插件 | vanniktech maven-publish **0.37.0**（settings pluginManagement） | `settings.gradle.kts:3` ✅ |
| 模块 | 仅 `:uv-cli`（Android library，纯 AAR 容器，无 Kotlin/Java 源） | `settings.gradle.kts:20-21` · `uv-cli/build.gradle.kts:11` ✅ |
| SDK / ABI | compileSdk 36 / minSdk 24 / arm64-v8a（唯一） | `uv-cli/build.gradle.kts:29-35` ✅ |
| host 工具 | Node（ESM `.mjs`；provision/fetch 零第三方依赖） | `tools/provision.mjs` ✅ |
| 交叉编译（M1） | rustup stable（钉版）+ `aarch64-linux-android`（tier2）+ cargo-ndk（备选 `.cargo/config.toml`）+ NDK（与 aosp-node-runtime 对齐线 r28c+ ⬜） | 规划 §4.1 ⬜ |
| 16KB 页 | `RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"` | 规划 §4.1 ⬜（门禁 ⑦ ✅） |

### 1.2 里程碑现状（规划 §10）

| 里程碑 | 内容 | 现状 |
|---|---|---|
| **M0 骨架** | Gradle 骨架 + exec 门禁 provision + draft lock（`uv-cli:0.9.0`）+ 骨架脚本（exit 2）+ 配置期 CI | ✅ 完成（scaffold 提交前验证全过） |
| M1（T1–T5） | C 依赖试编探针 → fetch 完整实现 → rust 工具链装配 → strip/改名/门禁 → CI 真实流水线 + Release + lock 回写 | ⬜ |
| M2（T1–T2） | 消费方环境注入 + 真机回程探针 P1–P6 | ⬜ |
| M3 | Maven Central 发布（workspace runbook 口径） | ⬜（发布面 ✅ 就绪） |
| M4 | uv 新版跟随 runbook + lock 回写自动化评估 | ⬜ |

---

## 2. 宪法符合性检查（逐条）

| 原则 | 判定 | 理由（含证据） | 待处置 |
|---|---|---|---|
| **P1 fetch 不改源** | ✅ 符合（纪律层） | 脚本头注释与规划 §4.1 均固定「源码不改；参数经 cargo 配置/RUSTFLAGS 注入」；仓库无任何 patch 文件 | M1 实现 fetch 时保持：只下载+校验+解压 |
| **P2 lock 唯一事实源** | ✅ 符合 | `uv-cli.lock.json` 为唯一来源；坐标版本唯一取 `CLI_VERSION`（`build.gradle.kts:16-17`、`publish.gradle.kts:37-39`）；draft 不伪造哈希（`size:0`/`sha256:""`） | ⚠️ `gradle.properties:3` 的 `VERSION_NAME=0.1.0` 是**未生效遗留元数据**（两个版本消费点都不读它）；建议 M1 顺手删除或注释，防误读 |
| **P3 二进制不入库** | ✅ 符合 | `.gitignore:23,26-28`（jniLibs `.so` / `.dist/` / `build/out/` / `target/`）；lock 只记 size/sha256 | 保持：任何新产物路径先补 gitignore |
| **P4 门禁强制** | ✅ 符合 | 七门禁 + 兄弟文件检查 + BANNED_IN_AAR 全部实现；`--out` 不过门禁即 `exit 2` 拒投（`provision.mjs:235-238`）；CI 断言未投放=2（workflow `:37-45`） | M1 CI 全链必须把 provision 放在打包/归档**之前** |
| **P5 发布卫生** | ✅ 符合 | `RELEASE=false`（`gradle.properties:19`）；缺 Token/未开启时 Central/签名任务 `enabled=false`（`publish.gradle.kts:133-139`）；凭据模板单独 example | M3 实发时按 runbook 走 §4 发布前检查 |
| **P6 未实测 ⬜** | ✅ 符合 | 规划 §4/§7/§8/§9/§11 的 ⬜ 全部保留；本 specs 体系所有 M1/M2 结论均标 ⬜ 规划引用 | 首产后按宪法 P6 逐项转 ✅ |
| **P7 不下载上游二进制** | ✅ 符合（纪律层） | 规划 D3/D7 + fetch 骨架只固化源码 tarball 接口；README 明文「不下载上游二进制」 | M1 fetch 实现与 CI 装机不得引入任何可执行下载 |
| **P8 先改文档再改实现** | ✅ 符合 | 规划文件头即「变更走先改本文件再改实现」；降级路径/依赖 sha 粒度均要求先回写规划 | M1 拍板事项（§4.3/§8）严格执行 |

**结论**：0 条违背（P1–P8 无 ❌）；1 条 ⚠️ 观察（`VERSION_NAME` 遗留元数据，不影响行为）。

---

## 3. 实现策略总览

### 3.1 M0 已落地（as-built 构成）

| 层 | 文件 | 状态 |
|---|---|---|
| 工程骨架 | `settings.gradle.kts` / `gradle.properties` / `gradle/libs.versions.toml` / `uv-cli/build.gradle.kts` | ✅ |
| 发布面 | `publish.gradle.kts` + `gradle.properties.local.example`（RELEASE 门禁 + 签名 + POM 补丁） | ✅（动作 ⬜ M3） |
| 事实源 | `uv-cli.lock.json`（draft 0.9.0 + allowedNeeded + execPackaging 语义注释） | ✅ |
| 门禁/投放 | `tools/provision.mjs`（exec profile；与 workspace 各仓同族） | ✅ |
| 构建脚本 | `scripts/fetch-uv-cli-source.mjs` / `build-uv-cli-android.sh`（接口 + 纪律注释，exit 2 SCAFFOLD） | ✅ 接口 / ⬜ 行为 |
| CI | `.github/workflows/build-uv-cli-android.yml`（配置期 + 退出码自检 + 语法门） | ✅ |
| 文档/许可 | `README.md` / `README_zh.md` / `uv-cli/THIRD-PARTY-NOTICES.md` / `LICENSE` / `docs/000-工程规划.md` v2.0 | ✅ |

### 3.2 M1 实现顺序（依赖关系，规划 §10 展开）

```
① M1-T1 C 依赖试编探针（ring/zstd-sys/… 在 NDK 下 --locked 试编）
      └─ 失败 ⇒ 降级拍板（crypto provider 切换 / feature 裁剪），先回写规划（P8）
② M1-T2 fetch 完整实现（tarball 钉选 + SHA-256 + Cargo.lock 记录；粒度方案 A/B 拍板后回写规划）
③ M1-T3 rust 工具链装配（rustup+target+cargo-ndk / config.toml 备选）+ 16KB RUSTFLAGS + cc 环境变量
④ M1-T4 strip（llvm-strip --strip-unneeded）+ 改名 libuv_cli.so + provision 全门禁
      └─ DT_NEEDED 实测清单回填 lock；sha/size 回填；status=released
⑤ M1-T5 CI 真实流水线（缓存 + 归档 + cargo license 清单 + GitHub Release，tag 钉 commit）
      └─ 出口：G1 编译过门禁并 Release / G2 归档完整过校验 / G4 lock=released
```

纪律：④ 的 provision 必须在 ⑤ 的任何发布动作之前；⑤ 未完成前 ④ 的「门禁全过」不构成 G1。

### 3.3 M2/M3 概要（规划引用）

- **M2**：消费方注入（`PATH`/`LD_LIBRARY_PATH`/`UV_PYTHON`/`UV_CACHE_DIR`/`XDG_CACHE_HOME`/`HOME`/`TMPDIR`，规划 §7 表）→ 真机探针 P1–P6（§7.1）⇒ G3；`uv python install` 禁用等边界回写 README。
- **M3**：Maven Central（`RELEASE=true` + 用户级 Token/GPG；runbook §4 发布前检查 → §5 上传 → §6 回填 `mavenCentral.published=true`）。

---

## 4. 跨切面关注点

### 4.1 可复现性（Reproducibility）

| 输入 | 钉选方式 | 现状 |
|---|---|---|
| uv 版本 | lock `active` + CI 参数（tag `v<uvver>` / dispatch） | ✅ 机制（0.9.0 为 draft 计划值，首产钉选 ⬜） |
| rust 工具链 | rustup stable 钉版 → lock `builtFrom.toolchain.rustVersion` | ⬜ 结构化字段 M1 落地（规划 §8；现 draft 为 prose） |
| cargo 依赖 | tarball 内 `Cargo.lock` + 一律 `--locked`；依赖 sha 记录粒度方案 A/B M1 拍板 | ⬜（规划 §8） |
| NDK | 与 aosp-node-runtime 对齐线（r28c+）→ lock `builtFrom.ndk` | ⬜ |
| 链接参数 | `RUSTFLAGS` 16KB 固定值 → lock `builtFrom.flags` | ⬜（门禁 ⑦ ✅ 兜底） |

### 4.2 错误处理（全 host 工具统一）

| 层 | 策略 | 依据 |
|---|---|---|
| provision | 解析失败 ⇒ `{ok:false,gate:'parse'}` 类结构化输出；CLI 顶层 catch ⇒ `exit 1`；门禁不过/未投放 ⇒ `exit 2`；**绝不就地找替代品** | `provision.mjs:271-276` · 宪法 P4/S1 |
| fetch/build（骨架） | 显式 `exit 2`（SCAFFOLD）+ 打印计划输入/输出；M1 实现后：缺参/缺 NDK/校验失败 ⇒ 非零并说明原因 | `fetch:46-53` · `build.sh:50-58` · 宪法 S7 |
| CI | 每步显式断言预期退出码（未投放=2）；其它非零视为工具缺陷 | workflow `:37-45`（⚠️ `bash -e` 下断言分支不可达，登记于 000-scaffold/plan.md §7；M1-T5 修复） |
| 发布面 | `RELEASE=false` 或缺 Token ⇒ 任务禁用（静默不发，但不报错——这是**有意**的防误发语义） | `publish.gradle.kts:133-139` |

### 4.3 供应链与许可

- 出处记录：lock `builtFrom`（source/ndk/flags 现为 draft 占位；M1 回写真实值并做 `toolchain` 结构化扩展，规划 §8）。
- 许可：本仓 MIT + uv 双许可已声明 ✅；cargo 依赖许可清单随 Release 归档 ⬜（规划 §12）。
- 禁区：`libnode.so`（BANNED_IN_AAR）、`libuv.so`（命名混淆）。

### 4.4 组合契约（消费方义务，规划 §7 ⬜ M2）

| 注入项 | 值 | 目的 |
|---|---|---|
| `PATH` | `<nativeLibraryDir>:$HOME/bin:/system/bin` | uv 直呼或 symlink 农场 |
| `LD_LIBRARY_PATH` | `<nativeLibraryDir>`（仅当 DT_NEEDED `libc++_shared.so` ⬜ P6 定） | exec 子进程解析 C++ 运行时 |
| `UV_PYTHON` | python-cli 物化解释器 | D7 组合契约；钉死后 uv 不自行找 python |
| `UV_CACHE_DIR` / `XDG_CACHE_HOME` | filesDir 子目录 | 缓存不落未知处 |
| `HOME` / `TMPDIR` | filesDir 子目录 | venv/临时文件（Android 无 `/tmp`） |
| `SSL_CERT_FILE` | **不注入** | rustls 内嵌根证书（D4） |

### 4.5 体积

预估 25–40 MB 量级（工作区方案 §3.2 口径）⬜；治理第一手段 = `llvm-strip --strip-unneeded`；超标处置 = release profile 收缩（LTO/opt-level），**先改规划再动**（规划 §11 R3）。

---

## 5. 测试策略（详见 [overall-test-cases.md](./overall-test-cases.md)）

| 层 | 内容 | 需要产物 | 现状 |
|---|---|---|---|
| L1 配置期/语法门 | `gradle :uv-cli:tasks` + `node --check` ×2 + `bash -n` | 否 | ✅（TC-01/02/04） |
| L1 工具纪律 | provision 退出码（未投放=2）+ 门禁位逐项负例 | 否（负例可用任意非合格 `.so`） | ✅ TC-03 / ⬜ 负例矩阵（M1 补） |
| L2 CI 端到端 | fetch→build→strip→门禁→归档→Release | 是（首产） | ⬜ M1-T5（G1/G2/G4） |
| L3 真机回程 | 探针 P1–P6（版本/venv/HTTPS/组合/cache/libc++） | 是 + 消费方 App | ⬜ M2（G3） |

判据纪律：每条判据必须有二元出口（通过/不通过）；「门禁全过」≠「真机可用」（宪法 §三-3）；禁止用「编译成功」替代门禁结论。

---

## 6. 发布策略

### 6.1 两段式（规划 §10.1）

1. **GitHub Release 先行（M1-T5）**：tag `v<uvver>` push 触发；归档 `uv-cli-v<ver>-android-arm64-v8a.tar.gz`（libuv_cli.so + BUILD/FETCH-METADATA + LICENSES + cargo license 清单）+ `.sha256`；tag 钉 commit；lock 人工回写 `status=released`（M4 再评估自动化）。
2. **Maven Central 随后（M3）**：`-PCLI_VERSION=<ver> -PRELEASE=true` + 用户级 Portal Token/GPG；runbook §4 发布前检查（provision `--check` 全过 + lock=released）→ §5 上传 → §6 核验回填 `mavenCentral.published=true`。

### 6.2 版本演进（规划 §2）

- 制品版本 = uv 上游版本，独立 semver；升级 = lock 增项（draft）+ CI 重建 + 回写 released。
- uv 发版频繁（数周一级）⇒ 跟随节奏独立于 python-cli；不追每个 patch，按消费方需求钉选（R4）。

### 6.3 发布前最终检查清单（库侧，M1/M3 适用）

- [ ] `node tools/provision.mjs --check` 全过（含兄弟文件与 BANNED 检查）
- [ ] lock：`status=released`；size/sha256/DT_NEEDED 实测清单/builtFrom（含 toolchain 结构化字段）齐备
- [ ] 归档完整：二进制 + 元数据 + LICENSES + cargo license 清单 + `.sha256` 可回算
- [ ] `RELEASE=true` 仅在正式发布命令中出现；凭据只在用户级
- [ ] git 状态无 jniLibs `.so` / `.dist/` / `target/` 条目（宪法 P3）
