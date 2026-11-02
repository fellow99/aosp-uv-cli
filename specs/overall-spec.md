# overall-spec.md —— `io.github.fellow99:uv-cli` 整体规格（技术无关）

> **性质**：项目级**需求规格**。只写「要什么、验收判据是什么、不在范围内的是什么」，**不写实现**（不出现文件路径、构建方式、工具内部结构）。
> **上位约束**：`specs/constitution.md`（原则 P1–P8）与 [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（唯一规划基线 v2.0，下称「规划 §」）。功能需求编号 **沿用 `000-scaffold/spec.md` 的 `FR-000-xxx`**（本文件不新增编号）。
> **标记**：✅实测（已实现并验证）/ ⬜规划（实现属 M1/M2，规划引用）/ ⚠️边界或限制。
> **版本**：v1.0 · 2026-11-02 · 状态：M0 骨架已完成；M1 真实构建未开工。

---

## 1. 系统用途与目标用户

### 1.1 一句话

本系统提供一个**可发布的 Android 原生 `uv` 命令行制品**（AAR 形式，arm64-v8a，独立进程 exec 型可执行），使 Android 终端场景（经 PTY）能使用真正的 `uv`（python 环境/包管理），并保证该制品**可复现、可门禁、可自证出处**。

### 1.2 目标用户

| 用户 | 他们要什么 | 本系统给什么 |
|---|---|---|
| **终端/工具链消费者**（最终用户，经消费方 App） | 在 Android 终端里直接使用 `uv` 命令（`uv venv` / `uv pip` / `uv run`） | 一个 exec 型原生 `uv`，由消费方以 PTY 启动 ⬜ |
| **消费方 App 开发者** | 一个依赖即得、内容可校验的原生工具 AAR，以及明确的运行期环境契约 | `io.github.fellow99:uv-cli:<CLI_VERSION>` + 环境注入契约（规划 §7）⬜ |
| **维护者** | 一条可复现的构建发布线：换 uv 版本只需 lock 增项 + CI 重建 | lock 纪律 + 门禁工具 + CI（M0 配置期 ✅ / M1 真实流水线 ⬜） |
| **发布工程师** | 防误发、防凭据泄漏、两段式发布 | 默认禁用的发布面 + 用户级凭据约定 ✅ |
| **组合产品线（python-cli / git-cli / node-runtime）** | 明确的组合边界：谁供给解释器、git、C++ 运行时 | 组合契约（`UV_PYTHON`、git 依赖源、`libc++_shared.so` 供给）⬜ 全部为规划引用 |

### 1.3 非目标（明确不做）

1. **不做 python 解释器本体**（属 `aosp-python-cli`；本系统只管 uv）。
2. **不做任何嵌入 API / NAPI / Kotlin-Java 桥**——exec 型独立进程，无进程内接口（AAR 容器不含任何 Java/Kotlin 源语义）。
3. **不提供 git 二进制**（git 依赖源属 `aosp-git-cli` 线，运行期 PATH 组合即可）。
4. **不托管 managed python**：`uv python install` 及一切「运行期下载可执行」被禁止（P7 红线）。
5. **不扩多 ABI / 多 API 矩阵**（当前仅 arm64-v8a / minSdk 24 一条线）。
6. **不在仓库托管二进制**（二进制只存在于 CI 产物与 Release 归档）。

---

## 2. 用户故事

- 作为**维护者**，我希望工程骨架（Gradle/发布面/门禁/lock）一次搭好，使后续「交叉编译 uv」只需填充实现而无需再做工程决策 ✅（M0）。
- 作为**维护者**，我希望版本 = uv 上游版本（独立 semver），升级时只改 lock 并重跑 CI，不被任何 node 系配对约束 ✅（接线）/ ⬜（首产钉选）。
- 作为**维护者**，我希望任何不合格产物（非 PIE、非系统 linker 启动、依赖越白名单、未 16KB 对齐、哈希不符）**无法进入 AAR** ✅（门禁已实现）。
- 作为**消费方开发者**，我希望依赖坐标清晰、版本跟随 uv 上游、README 写明 exec 打包要点与运行期环境契约 ✅（契约内容）/ ⬜（M2 补运行期回程结论）。
- 作为**发布工程师**，我希望默认绝不发布、凭据只存用户级、发布前必须门禁全过且 lock 已 released ✅（机制）。
- 作为**组合产品线维护者**，我希望本系统明确承认：解释器来自 python-cli、git 来自 git-cli、C++ 运行时来自 node-runtime，本仓一律不自带 ⬜（组合契约，规划 D5/D7）。

---

## 3. 系统边界

### 3.1 在范围内

| 域 | 内容 |
|---|---|
| 构建工程骨架 | Gradle 多模块骨架、坐标与版本接线、发布面（默认禁用）✅ |
| 版本事实源 | lock（版本 + size + sha256 + 门禁 + 出处 + 依赖白名单）✅（draft 态） |
| 产物门禁 | exec 型 ELF 门禁、哈希/大小校验、16KB 页、投放卫生 ✅ |
| 构建/获取流水线 | 源码获取（不改源）、交叉编译、strip、改名、CI、Release ⬜ M1 |
| 分发 | GitHub Release 先行 + Maven Central 随后（两段式）⬜ |
| 运行期契约（只定义，不实现） | 环境注入（`PATH`/`LD_LIBRARY_PATH`/`UV_PYTHON`/`UV_CACHE_DIR`/…）、组合边界 ⬜ M2 |

### 3.2 不在范围内（见 §1.3 非目标）

python 解释器 · 任何嵌入 API · git 二进制 · managed python · 多 ABI 矩阵 · 仓库内二进制。

### 3.3 交付边界（一次分发到底含什么）

发布物（AAR）MUST 且仅含：`jni/arm64-v8a/libuv_cli.so`（exec 型 PIE）与投放生成的版本元数据。
发布物 MUST NOT 含：`libc++_shared.so`（运行期由消费方包内 node-runtime 供给，⬜ 运行期）、任何 assets、任何 Java/Kotlin 代码语义、`libnode.so`/`libuv.so`（命名/供给禁区）。
Release 归档（⬜ M1）MUST 含：二进制 + 构建/获取元数据 + LICENSES + cargo 依赖许可清单 + `.sha256`。

---

## 4. 功能需求（RFC 2119；编号沿用 000-scaffold/spec.md，不新增）

### 4.1 Gradle 工程与坐标（骨架 ✅）

| 编号 | 级别 | 需求 | 可证伪的验收判据 | 状态 |
|---|---|---|---|---|
| FR-000-001 | MUST | root 工程名为 `aosp-uv-cli`，且仅 include 一个模块 `:uv-cli` | 配置期工程列表恰含根 + `:uv-cli` | ✅ |
| FR-000-002 | MUST | `:uv-cli` 为 Android library，namespace `org.fellow99.uvcli`，minSdk 24 / compileSdk 36，ABI 仅 arm64-v8a | 模块配置求值输出上述值 | ✅ |
| FR-000-003 | MUST | 制品坐标 `io.github.fellow99:uv-cli:<CLI_VERSION>`；`CLI_VERSION` = uv 上游版本，独立 semver | 坐标三元组与 lock 的 release 一致；不存在第二版本源 | ✅（版本值 ⬜ 首产钉选） |
| FR-000-004 | MUST | 打包启用 `useLegacyPackaging`（exec 型硬要求） | 打包配置该项为 true；AAR/APK 内原生库物理落盘 | ✅（打包语义 ⬜ 消费方核验） |
| FR-000-005 | MUST | 无 `.so` 时 Gradle 配置/任务求值必须成功 | 干净检出跑配置期任务 BUILD SUCCESSFUL | ✅（TC-01/02） |

### 4.2 唯一事实源 lock（draft 态 ✅）

| 编号 | 级别 | 需求 | 可证伪的验收判据 | 状态 |
|---|---|---|---|---|
| FR-000-010 | MUST | 仓库根存在 `uv-cli.lock.json`，含 `active` 与至少一条 `releases` 记录 | 文件可解析且结构齐备 | ✅ |
| FR-000-011 | MUST | release 记录版本/ABI/androidApi/产物名/出处/门禁集合齐备 | 每个字段有值或明确的 draft 表达 | ✅（builtFrom.toolchain 为 prose、ndk/flags 为 TBD——**如实占位** ⚠️） |
| FR-000-012 | MUST | 门禁集合与依赖白名单（含 `libc++_shared.so` 登记）固化在 lock | 门禁位与 `matrix.allowedNeeded` 与门禁实现一致 | ✅ |
| FR-000-013 | MUST | 无 CI 产物时 size/sha256 以占位（0/空串）表达且 `status="draft"`，**不得伪造哈希** | draft 记录 size=0、sha256 为空串 | ✅ |

### 4.3 投放与门禁（provision ✅）

| 编号 | 级别 | 需求 | 可证伪的验收判据 | 状态 |
|---|---|---|---|---|
| FR-000-030 | MUST | 提供校验/查看/投放三类操作（对应 `--check` / `--inspect` / `--out --from`） | 三种调用各自产生规定效果 | ✅ |
| FR-000-031 | MUST | 退出码纪律 `0` 全过 / `2` 门禁不合格或未投放 / `1` 用法或 IO 错误 | 三类场景各得对应退出码；CI 断言未投放 = 2 | ✅（TC-03） |
| FR-000-032 | MUST | 门禁断言 exec 型 ELF 形态：PIE、解释器恰为系统 64 位 linker、AArch64、16KB 页对齐 | 各判据有独立布尔位与失败文案 | ✅（判据实现；真实产物过门禁 ⬜） |
| FR-000-033 | MUST | 依赖白名单门禁：DT_NEEDED 全部在 lock 登记集合内（越界即拒） | 构造越白名单依赖的产物 ⇒ 门禁失败 | ✅（机制；实测清单回填 ⬜） |
| FR-000-034 | MUST | 投放仅复制本工具二进制，**绝不**复制引擎库/C++ 运行时；jniLibs 内出现其它 `.so` 视为不合格 | 投放后目录仅含 `libuv_cli.so`；混入即失败 | ✅ |
| FR-000-035 | MUST | draft（无锁值）时 sha/size 仅记录不判失败；有锁值时必须比对 | draft 产物可投放并记录实测值 | ✅ |
| FR-000-036 | MUST | 投放后生成版本元数据（tool.version/abi/name/size/sha256/provisionedAt） | 元数据文件存在且字段与投放产物一致 | ✅（随首产回验 ⬜） |

### 4.4 CI（配置期 ✅ / 真实流水线 ⬜）

| 编号 | 级别 | 需求 | 可证伪的验收判据 | 状态 |
|---|---|---|---|---|
| FR-000-040 | MUST | CI 存在且在无二进制的检出上可绿（配置期门禁） | CI 配置期 job 全过（`gradle :uv-cli:tasks`） | ✅ |
| FR-000-041 | MUST | CI 断言投放工具的退出码纪律：未投放时 `--check` 必须 = 2，其它非零视为工具缺陷 | 注入其它非零 ⇒ job 失败 | ✅ |
| FR-000-042 | MUST | CI 对全部构建脚本做语法门（`.mjs` 语法检查 + shell 语法检查） | 任一脚本语法错误 ⇒ job 失败 | ✅ |
| （规划引用） | — | 真实流水线：源码钉选下载 → 交叉编译（`--locked`）→ strip/改名 → 全门禁 → 归档 + `.sha256` + license 清单 → GitHub Release（tag 钉 commit）→ lock 人工回写 | 首个 Release 存在且 lock 变 released（规划 §9/§10 M1-T5，目标 G1/G2/G4） | ⬜ |

### 4.5 卫生、许可与文档 ✅

| 编号 | 级别 | 需求 | 可证伪的验收判据 | 状态 |
|---|---|---|---|---|
| （卫生） | MUST | 二进制/构建目录/凭据不入库（gitignore 覆盖 jniLibs `.so`、`.dist/`、`target/`、keystore） | 状态检查无上述条目 | ✅（TC-05） |
| （许可） | MUST | 声明本仓 MIT 与 uv 双许可（MIT OR Apache-2.0），并声明 cargo 依赖许可清单随 Release 归档的纪律 | 第三方许可文件存在且含上述声明 | ✅（清单归档 ⬜ M1） |
| （文档） | MUST | 中英 README 说明定位、坐标、exec 打包要点、锁定与校验、退出码语义 | 两份 README 存在且口径一致 | ✅ |

> 说明：卫生/许可/文档三条在 `000-scaffold/spec.md` 以摘要与任务清单（T6）承载，未单设 FR 号；上表沿用其验收事实，不新增编号。

---

## 5. 边界与已知限制（MUST 写入消费方文档；全部规划引用 ⬜）

| # | 限制 | 级别 | 说明与依据 |
|---|---|---|---|
| B-1 | **`uv python install` / managed python 禁用** | MUST NOT（运行期） | 运行期下载可执行违反 P7；python-build-standalone 构件非 Android 形态。`UV_PYTHON` 钉死默认解释器（规划 §7 已知限制 1、D7） |
| B-2 | **sdist 不可安装**：`uv pip install <sdist>` MUST 视为不可用；纯 wheel 域可用 | ⚠️ 能力边界 | 设备无编译器（python-cli 同款边界；规划 §7 已知限制 2、工作区方案 §3.2） |
| B-3 | **git 依赖源需 git-cli**：`uv pip install git+…` / lock 中 git 源 MUST 依赖 `git` 在 PATH（`aosp-git-cli` 线组合项） | ⚠️ 组合边界 | 规划 §7 已知限制 3；本仓不提供 git |
| B-4 | **`libc++_shared.so` 不随包**：若产物 DT_NEEDED 该库，运行期由消费方包内 node-runtime 供给并注入 `LD_LIBRARY_PATH`；未注入时启动失败为**预期行为** | ⚠️ 组合边界 | 规划 §4.4 D5、§7 已知限制 4、探针 P6 |
| B-5 | **缓存/venv 落 filesDir**：`UV_CACHE_DIR`/`XDG_CACHE_HOME`/`HOME`/`TMPDIR` 由消费方注入；Android 无 `/tmp` | MUST（消费方契约） | 规划 §7 |
| B-6 | **TLS 不依赖系统证书目录**：不注入 `SSL_CERT_FILE`；HTTPS 走 rustls 内嵌根证书 | MUST（构建契约 ⬜ M1 + 探针 P3） | 规划 §4.1 D4、§7 |

---

## 6. 非功能需求

| 编号 | 需求 | 判据 |
|---|---|---|
| NFR-REP-1 | **可复现**：干净 runner 单条流水线可重出同口径产物（uv 版本 + rust 钉版 + Cargo.lock + NDK + flags 全钉选） | ⬜ M1：同输入两次构建哈希一致（规划 §12 可复现行） |
| NFR-SEC-1 | **供应链可自证**：二进制的来源/大小/摘要/出处可从 lock 与 Release 元数据核对 | lock 字段齐备 ✅（值 ⬜）；归档 `.sha256` 可回算 ⬜ |
| NFR-SEC-2 | **可执行代码零下载**：构建期与运行期均不引入上游二进制 | 依赖清单只含源码 tarball + crates.io（规划 §1.2/D3） |
| NFR-PORT-1 | **工具零依赖**：门禁/投放工具在任何装 Node 的机器可跑（无第三方包） | 依赖为零 ✅ |
| NFR-HYG-1 | **发布安全**：默认不发布；发布动作需要显式属性 + 用户级凭据 | 默认配置下发布任务被禁用 ✅ |
| NFR-COMPAT-1 | **组合一致**：与 python-cli/git-cli/node-runtime 的边界如 §5；本仓不自带任何组合件 | lock 白名单 + 消费方文档（⬜ M2） |

---

## 7. 验收判据（可证伪，项目级出口）

| # | 判据 | 证伪方式 | 状态 |
|---|---|---|---|
| A1 | 干净工程配置期成功，坐标版本解析为 lock 值 | 配置失败或版本不符即不达标 | ✅（TC-01） |
| A2 | 无产物时投放校验返回「未投放」语义退出码 | 退出码 ≠ 2 即不达标 | ✅（TC-03） |
| A3 | 二进制/凭据不入库 | 状态检查出现 `.so`/凭据条目即不达标 | ✅（TC-05） |
| A4 | 首个真实产物过全门禁并发布 GitHub Release；lock 回写 released | 任一门禁失败或 lock 仍 draft 即不达标 | ⬜ M1（G1/G2/G4） |
| A5 | 真机回程：PTY 内 `uv --version` / `uv venv` / `uv pip install <纯py包>` / 与 python-cli 组合成功 | 任一回程失败即不达标 | ⬜ M2（G3，探针 P1–P6） |
| A6 | Maven Central 制品可拉取且坐标正确 | 解析失败即不达标 | ⬜ M3 |

---

## 8. 假设与依赖

- 消费方 App 同时携带 `aosp-python-cli`（解释器）与 `aosp-node-runtime`（引擎 + `libc++_shared.so`）⬜（组合前提，规划 D5/D7）。
- CI runner 为 `ubuntu-24.04`，具备 NDK（与 aosp-node-runtime 对齐线）与 rustup ⬜（M1 装机）。
- 上游 uv 无 Android 官方产物（本仓存在的前提）；上游源码 tarball 含 `Cargo.lock` ⬜（首产核实）。
- 版本跟随节奏独立于 python-cli（uv 发版频繁，不互相触发重建）（规划 §2）。
