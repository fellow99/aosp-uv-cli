# ARCHITECTURE.md —— `aosp-uv-cli` 整体架构（as-built + 规划引用）

> **性质**：项目级架构规格。回答「分几层、构建怎么流转、exec 怎么跑、门禁落在哪一行、与 python-cli/node-runtime/git-cli 怎么组合」。
> **依据**：`specs/constitution.md`（P1–P8）· [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（唯一规划基线 v2.0，下称「规划 §」，决策 D1–D7 在 §3.1）· 源码 ✅实测（行号 = 2026-11-02 快照）。
> **标记**：✅实测 / ⬜规划引用（代码里**确实没有**，不得当既成事实）/ ⚠️事实性观察。
> **版本**：v1.0 · 2026-11-02 · 状态：**M0 骨架已完成**；M1 真实交叉编译、M2 真机回程未开工。

---

## ① 分层架构（构建期 as-built + 运行期规划引用）

```
【构建期（host 侧）───────────────────────────────────────────────────────────┐
│                                                                            │
│  上游 astral-sh/uv 源码 tarball（含 Cargo.lock）                            │
│        │  fetch（SHA-256 校验、源码不改 P1）  ⬜ M1-T2（scaffold 接口已固化 exit 2 ✅）│
│        ▼                                                                   │
│  .dist/src/uv-src/（源码树）──▶ cargo 交叉编译 ⬜ M1-T3                     │
│        rustup stable + aarch64-linux-android（tier2）+ cargo-ndk            │
│        RUSTFLAGS=-C link-arg=-Wl,-z,max-page-size=16384（16KB）             │
│        TLS：rustls 内嵌根证书（D4）；cc 类依赖试编 ⬜ M1-T1                  │
│        ▼                                                                   │
│  target/…/release/uv --llvm-strip--> 改名 libuv_cli.so ⬜ M1-T4（D6）       │
│        │                                                                   │
│        ▼                                                                   │
│  ┌─ 门禁层 tools/provision.mjs ✅（M0 已建成）─────────────────────────┐   │
│  │  七门禁（①ET_DYN ②PT_INTERP=/system/bin/linker64 ③AArch64           │   │
│  │  ④DT_NEEDED 白名单 ⑤sha256 ⑥size ⑦16KB）+ jniLibs 兄弟文件检查      │   │
│  │  + BANNED_IN_AAR(libnode.so)；退出码 0/2/1                          │   │
│  └──────────────┬─────────────────────────────────────────────────────┘   │
│                 │ 全过才投放（不过 exit 2，绝不就地找替代品 P4）           │
│                 ▼                                                          │
│  uv-cli/src/main/jniLibs/arm64-v8a/libuv_cli.so（不入库 P3）               │
│                 ▼                                                          │
│  :uv-cli AAR（useLegacyPackaging=true ✅ D1；无 Kotlin/Java 源）            │
│                 ▼                                                          │
│  GitHub Release（⬜ M1-T5）→ Maven Central（⬜ M3；RELEASE=true 门禁 ✅）    │
└────────────────────────────────────────────────────────────────────────────┘

【运行期（设备侧）⬜ 全部为规划引用（规划 §3 / §7）──────────────────────────┐
│                                                                            │
│  消费方 App 进程                                                            │
│   环境引导层注入：PATH / LD_LIBRARY_PATH / UV_PYTHON / UV_CACHE_DIR /       │
│                   XDG_CACHE_HOME / HOME / TMPDIR                           │
│        │  pty.spawn(<nativeLibraryDir>/libuv_cli.so, …)（node-pty）        │
│        ▼                                                                   │
│  uv 子进程（exec 型 PIE，forkpty → setsid → TIOCSCTTY，独立生命周期）       │
│   TLS：rustls 内嵌根证书；缓存/venv 全落 filesDir（无 assets）              │
│        │  组合契约（D7 ⬜ M2）                                              │
│        ▼                                                                   │
│  UV_PYTHON ← aosp-python-cli 物化解释器（python 环境与包管理全走 uv）       │
└────────────────────────────────────────────────────────────────────────────┘
```

**一条关键边界**：本仓是「**单文件 exec 型制品线**」——AAR 内没有嵌入 API、没有 assets、没有物化步骤（规划 §1.3/§5；与 python-cli 的 assets 物化、node-cli 的 npm 树物化形成对照）。

---

## ② 构建期模块与责任边界（as-built）

| 模块 | 责任 | 实现 | 不负责 |
|---|---|---|---|
| `:uv-cli`（`uv-cli/build.gradle.kts`） | AAR 容器：`useLegacyPackaging=true`（:42）、abiFilters（:33-35）、版本接线（:16-26） | ✅ | 不编译任何代码；不产 `.so`；不写 lock |
| `publish.gradle.kts` | Maven Central 发布面：coordinates、签名、RELEASE 门禁（:133-139） | ✅（发布动作 ⬜ M3） | 不决定版本值（唯一取 `CLI_VERSION`，:37-39） |
| `tools/provision.mjs` | 门禁 + 投放 + 元数据（`META-INF/uv-cli.properties`） | ✅ | 不构建；不下载；不改 lock |
| `scripts/fetch-uv-cli-source.mjs` | 取 uv 源码 tarball（不改源） | ⬜ M1-T2（接口 ✅ exit 2） | 不改源（P1）；不下载二进制（P7） |
| `scripts/build-uv-cli-android.sh` | cargo 交叉编译 + strip + 改名 | ⬜ M1-T3/T4（接口 ✅ exit 2） | 不跑门禁（交给 provision） |
| `uv-cli.lock.json` | 唯一事实源：版本/size/sha256/门禁/出处/白名单 | ✅ draft 态 | 不入库二进制（P2/P3） |
| `.github/workflows/build-uv-cli-android.yml` | 配置期门禁 + 工具纪律自检 | ✅ scaffold | 真实流水线 ⬜ M1 并入替换 |

---

## ③ exec 型制品的运行期形态（规划引用 ⬜，判据已固化 ✅）

| 项 | 形态 | 判据落点（已实现 ✅） | 事实核验 |
|---|---|---|---|
| ELF 类型 | `ET_DYN`（PIE 可执行） | 门禁 ①（`provision.mjs:146`） | ⬜ 首产实测 |
| 解释器 | **PT_INTERP 恰 1 个 = `/system/bin/linker64`**（由 Android 系统动态链接器启动） | 门禁 ②（:148-150） | ⬜ 首产实测 |
| 架构 | AArch64（e_machine 183） | 门禁 ③（:151） | ⬜ |
| 依赖 | DT_NEEDED ⊆ 白名单（系统库 + `libc++_shared.so` 登记但不随包） | 门禁 ④（:153-155）+ lock `matrix.allowedNeeded` | ⬜ DT_NEEDED 实测清单回填 |
| 页对齐 | 16KB（min LOAD align ≥ 0x4000） | 门禁 ⑦（:160） | ⬜ |
| 落盘 | `useLegacyPackaging=true` ⇒ 物理落 `nativeLibraryDir`（targetSdk≥29 下唯一合规执行位） | `uv-cli/build.gradle.kts:37-44` | ⬜ 消费方 AAR 核验 |
| 启动 | 消费方 `pty.spawn(<nativeLibraryDir>/libuv_cli.so, …)`；`forkpty` → `setsid` → `TIOCSCTTY` | 规划 §3 | ⬜ M2 P1 探针 |
| TLS | rustls 内嵌根证书（不探测系统证书目录、不消费 `SSL_CERT_FILE`） | 规划 §4.1 D4 | ⬜ M2 P3 探针 |

---

## ④ 与 dlopen 库线（aosp-node-pty）的架构对照（同一 workspace 两条形态）

| 维度 | 本仓（exec 型 CLI） | pty（dlopen 库） | 架构含义 |
|---|---|---|---|
| 产物角色 | **独立进程的可执行**（经系统 linker64 启动） | **进程内加载的库**（宿主引擎 `dlopen`） | 门禁语义相反的根源 |
| PT_INTERP | **必须恰 1 个**（linker64） | **必须为 0** | 门禁 ② 方向相反 |
| DT_NEEDED | **白名单制**（`matrix.allowedNeeded`） | **必须含 `libnode.so`** | ④ 语义相反 |
| NAPI 符号 | 无门禁（独立进程不解析） | 必须存在未定义 `napi_*` 引用 | 本仓删除该门禁 |
| 打包 | `useLegacyPackaging=true`（物理落盘才能 exec） | 默认（从 APK mmap 直接 dlopen） | D1 vs pty 相反 |
| 版本纪律 | = uv 上游版本，独立 semver，无配对 | = Node 版本，与 runtime 强配对 | D2 vs pty 相反 |
| C++ 运行时 | `libc++_shared.so` 登记白名单但**不随包**（消费方 node-runtime 供给 ⬜） | 不适用（链接 libnode） | D5 |

> 同族纪律保持一致：退出码 0/2/1、draft 不伪造哈希、二进制不入库、投放幂等、`_cli` 命名后缀。

---

## ⑤ 关键架构决策表（D1–D7，规划 §3.1；本表核对「as-built 落点」）

| # | 决策（规划） | as-built 落点 | 状态 |
|---|---|---|---|
| **D1** | exec 打包 `useLegacyPackaging=true` | `uv-cli/build.gradle.kts:37-44` + lock `matrix.execPackaging` | ✅ |
| **D2** | 版本 = uv 上游版本，独立 semver | `gradle.properties:4-7`（CLI_VERSION=0.9.0 draft）+ `build.gradle.kts:16-17` + lock `$comment` | ✅（版本值 ⬜ 首产钉选） |
| **D3** | 一律 CI 源码自建（不下载上游二进制） | fetch 骨架接口（⬜ 行为 M1-T2）；CI 尚为配置期 | ⬜（纪律已写入脚本头注释 ✅） |
| **D4** | TLS = rustls 自带根证书 | 脚本纪律注释（`build-uv-cli-android.sh:5-13` 之 5）+ README 构建口径 | ⬜（M1 编译期钉定 + M2 P3 核验） |
| **D5** | `libc++_shared.so` 不随包（消费方 node-runtime 供给） | lock `matrix.allowedNeeded`（登记不随包）+ `provision.mjs:37-38`（BANNED 注释）+ 兄弟文件检查 | ✅ 机制 / ⬜ 运行期（M2 P6） |
| **D6** | 命名 `libuv_cli.so`（禁区 `libuv.so`/`libnode.so`） | `provision.mjs:36` DEFAULT_BINARY + 兄弟文件检查（:222-225）+ `BANNED_IN_AAR`（:246-250） | ✅ |
| **D7** | 组合契约：解释器来自 python-cli，本仓不内嵌 python；`uv python install` 禁用 | 规划 §7（`UV_PYTHON` 注入表）；本仓代码无 python 逻辑（as-built 事实） | ⬜ 契约（M2 消费方接线） |

---

## ⑥ 组合架构（与 python-cli / node-runtime / git-cli，全部规划引用 ⬜）

> 依据：规划 §1.1/§3/§7、工作区 `docs/aosp+node+python+git运行方案.md` §3.2/§9。**以下组合均未实现/未实测，只有契约设计。**

```
                 ┌────────────────── 消费方 App（同一 APK）──────────────────┐
                 │  nativeLibraryDir/（各 AAR 的 lib*.so 汇聚）              │
                 │   ├─ libuv_cli.so      ← 本仓（⬜ M1 产物）                │
                 │   ├─ libpython_cli.so  ← aosp-python-cli（解释器本体）    │
                 │   ├─ libnode.so        ← aosp-node-runtime（引擎）        │
                 │   ├─ libc++_shared.so  ← node-runtime 携带 ⇒ 兼作 uv 的   │
                 │   │                       C++ 运行时供给（D5）             │
                 │   └─ git 二进制         ← aosp-git-cli（git 依赖源用）    │
                 │  环境引导层：PATH=nativeLibraryDir…；LD_LIBRARY_PATH=     │
                 │   nativeLibraryDir；UV_PYTHON=<filesDir>/…（python-cli    │
                 │   物化解释器）；UV_CACHE_DIR/XDG_CACHE_HOME/HOME/TMPDIR   │
                 └───────────────┬──────────────────────────────────────────┘
                                 │ pty.spawn(libuv_cli.so)（forkpty+execve）
                                 ▼
                 uv 子进程：venv/缓存落 filesDir；HTTPS 走 rustls 内嵌根证书
                 （uv pip install git+… 需 git 在 PATH；sdist 不可安装——无编译器）
```

**组合边界（写进消费方文档的四条已知限制，规划 §7）**：
1. `uv python install` / managed python **禁用**（P7 红线 + 构件非 Android 形态）；`UV_PYTHON` 钉死后 uv 不再自行找 python。
2. `uv pip install` **sdist 不可安装**（设备无编译器）；纯 wheel 域可用。
3. git 依赖源需 `git` 在 PATH（`aosp-git-cli` 线组合项 ⬜）。
4. 若产物 DT_NEEDED `libc++_shared.so`：未注入 `LD_LIBRARY_PATH` 时启动失败为**预期**，注入后回程成功（M2 P6 核验 ⬜）。

---

## ⑦ 门禁层（as-built 的强制点）

| 强制点 | 内容 | 实现落点 | 退出 |
|---|---|---|---|
| 七门禁 | ①ET_DYN ②PT_INTERP=linker64 ③AArch64 ④DT_NEEDED 白名单 ⑤sha256 ⑥size ⑦16KB | `provision.mjs` `gates()` :132-169 | 不过 ⇒ `exit 2`，**拒绝投放**（:235-238） |
| 兄弟文件检查 | jniLibs 目录内仅 `libuv_cli.so` | :222-225（`--check` 路径） | 混入 ⇒ `exit 2` |
| BANNED_IN_AAR | `libnode.so` 不得出现在投放目录 | :38,246-250 | 命中 ⇒ 抛错 `exit 1` |
| draft 语义 | sha/size 无锁值 ⇒ 仅记录不比对（绝不伪造） | :141-142,156-159,197 | — |
| 发布门禁 | `RELEASE=false` 或缺 Token ⇒ Central/签名任务全部禁用 | `publish.gradle.kts:133-139` | 任务 `enabled=false` |
| 配置期门禁 | 无 `.so` 时 `gradle :uv-cli:tasks` 必须成功 | workflow :34-35 | 失败 ⇒ job 红 |

---

## ⑧ 架构层面的已知缺口（阶段划分）

| 缺口 | 归属 | 影响 |
|---|---|---|
| fetch / build 脚本真实实现（下载+SHA-256 / cargo+strip+改名） | ⬜ M1-T2/T3/T4 | 无产物（当前 exit 2 SCAFFOLD 属预期） |
| C 依赖（ring/zstd-sys 等）NDK 可编性探针 | ⬜ M1-T1 | crypto/压缩依赖可能需降级（provider 切换 / feature 裁剪），先改规划再动实现 |
| CI 真实流水线（rustup/cargo-ndk/缓存/归档/Release） | ⬜ M1-T5 | 无 GitHub Release；lock 无法回写 released |
| lock `builtFrom.toolchain` 结构化扩展 + DT_NEEDED 实测清单回填 | ⬜ M1（规划 §8） | 出处不可自证（当前 prose/TBD，draft 语义如实） |
| 消费方环境注入 + 真机探针 P1–P6 | ⬜ M2 | 组合契约（UV_PYTHON/libc++_shared 供给）无回程证据 |
| Maven Central 发布 | ⬜ M3 | 发布面已就绪（RELEASE 门禁 ✅），动作未发生 |
| lock 回写自动化 | ⬜ M4（评估） | 首产依赖人工回写 |
