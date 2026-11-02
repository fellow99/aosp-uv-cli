# overall-test-cases.md —— `aosp-uv-cli` 全模块测试用例索引

> **性质**：**索引文档**（不是逐条用例全集）。逐条用例的完整步骤写在 [`000-scaffold/test-cases.md`](./000-scaffold/test-cases.md)；本文负责①分层口径 ②用例族索引与状态 ③规划中的验收探针（规划引用）④禁止的判据 ⑤基线数值现状。
> **依据**：`specs/constitution.md`（P1–P8 / S1–S10）· [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（唯一规划基线 v2.0，下称「规划 §」）。
> **标记**：✅已实现可跑（且有执行记录）/ ⬜规划未实现（M1/M2）/ ⚠️风险项。
> **版本**：v1.0 · 2026-11-02。**判据纪律：每条判据必须可证伪；无「通过/不通过」二元出口的条目不得进表。**

---

## 1. 测试分层

| 层 | 代号 | 需要真实产物 | 跑在哪 | 目的 | 现状 |
|---|---|---|---|---|---|
| **配置期/语法门** | **L1a** | ❌ | 开发机 / CI（Gradle 9.4.1 + JDK 21 + Node） | 无 `.so` 可配置；脚本语法；工程结构有效 | ✅（TC-01/02/04） |
| **工具纪律门禁** | **L1b** | ❌（负例可用任意非合格文件） | 开发机 / CI（Node） | provision 退出码纪律（未投放=2）；门禁位逐项判定；投放卫生 | ✅ TC-03 / ⬜ 门禁负例矩阵（M1 随真实产物补） |
| **CI 端到端** | **L2** | ✅ | GitHub Actions（ubuntu-24.04 + NDK + rustup） | fetch→交叉编译→strip/改名→全门禁→归档→Release→lock 回写 | ⬜ M1-T5（出口 G1/G2/G4） |
| **真机回程探针** | **L3** | ✅ + 消费方 App | 真机（node-pty 终端） | `uv --version` / venv / HTTPS 安装 / 组合链路 / cache / libc++ 供给 | ⬜ M2（出口 G3，规划 §7.1 P1–P6） |
| **回归基线** | **L4** | ✅ | CI + 真机 | 产物 sha256 / 体积 / 归档校验 / `/facts` 式回程快照对比 | ⬜ 首产后建立（当前**无基线**，见 §5） |

**顺序纪律**：L1 可随时跑，但**不能替代** L2/L3——「门禁全过 ≠ 真机可用」（宪法 §三-3）；L2 未完成前不得声称 G1；L3 未完成前不得声称组合契约可用。

---

## 2. 用例族索引

### 2.1 已执行（✅，记录见 [`000-scaffold/test-cases.md`](./000-scaffold/test-cases.md)，2026-11-02）

| 用例族 ID | 名称 | 层 | 覆盖 | 判据（可证伪） | 命令 | 状态 |
|---|---|---|---|---|---|---|
| TC-000-01 | 干净工程可配置 | L1a | 骨架 | `:uv-cli:tasks` BUILD SUCCESSFUL | `gradle :uv-cli:tasks` | ✅ |
| TC-000-02 | AAR 容器可产出 | L1a | 骨架 | aar 产物存在（uv-cli-debug.aar） | `gradle :uv-cli:assembleDebug` | ✅ |
| TC-000-03 | provision 未投放语义 | L1b | 门禁 | `--check` 退出码 = 2 且文案含「未投放」 | `node tools/provision.mjs --check` | ✅ |
| TC-000-04 | 脚本语法门 | L1a | 脚本 | `node --check` ×2 + `bash -n` 全过 | 同左 | ✅ |
| TC-000-05 | 二进制不入库 | L1a | 卫生 | `git status --porcelain` 无 jniLibs/target 条目 | 同左 | ✅ |
| TC-CI-01 | CI 配置期门禁 | L1a | CI | 远端 workflow 的 config-check job 全绿 | GitHub Actions | ✅（scaffold CI 设计即此；本地同口径已验）⚠️ 远端 run 结果**未随本快照核对**，以 Actions 页为准 |
| TC-CI-02 | CI 退出码断言 | L1b | CI | `--check` 返回非 2 ⇒ job 失败 | workflow `:37-45` | ✅（逻辑在库） |

### 2.2 M1 待跑（⬜ 规划引用，规划 §9/§10；出口 G1/G2/G4）

| 用例族 ID | 名称 | 层 | 判据（可证伪） | 状态 |
|---|---|---|---|---|
| TC-M1-01 | fetch 可复现取源 | L2 | 同一 uv 版本两次 fetch：目录内容与 tarball SHA-256 一致 | ⬜ |
| TC-M1-02 | C 依赖试编探针（ring/zstd-sys/…） | L2 | `cargo build --target aarch64-linux-android --locked` 通过；失败即触发降级拍板（先回写规划） | ⬜（M1-T1） |
| TC-M1-03 | 门禁① `ET_DYN` | L2 | 首产 e_type=3 | ⬜ |
| TC-M1-04 | 门禁② PT_INTERP = `/system/bin/linker64` | L2 | 恰 1 个且内容精确匹配；dlopen 库形态产物必须 FAIL（负例） | ⬜ |
| TC-M1-05 | 门禁③ AArch64 | L2 | e_machine=183 | ⬜ |
| TC-M1-06 | 门禁④ DT_NEEDED 白名单 | L2 | NEEDED ⊆ `matrix.allowedNeeded`；实测清单回填 lock；越白名单产物 FAIL（负例） | ⬜ |
| TC-M1-07 | 门禁⑦ 16KB 对齐 | L2 | min LOAD align ≥ 0x4000；4K 产物 FAIL（负例；`--allow-page-align-4k` 仅 bring-up 打印警告） | ⬜ |
| TC-M1-08 | 门禁⑤⑥ sha/size 回填后比对 | L2 | lock 回写真实值后再投放：改动 1 字节 ⇒ FAIL | ⬜ |
| TC-M1-09 | 兄弟文件/BANNED 负例 | L1b/L2 | jniLibs 混入第二个 `.so` 或 `libnode.so` ⇒ 拒绝/失败 | ⬜ |
| TC-M1-10 | 归档完整性与 `.sha256` 回算 | L2 | 归档含二进制 + 元数据 + LICENSES + license 清单；下载回算哈希一致（G2） | ⬜ |
| TC-M1-11 | lock 回写为 released | L2 | `status=released` 且字段与产物一致（G4） | ⬜ |
| TC-M1-12 | 发布卫生 | L1a | `RELEASE` 缺省时 Central/签名任务禁用；凭据不在仓库 | ⬜（M3 前置检查） |

> **模块化落点（2026-11-03，规划 §10.2）**：本族已细化为逐条用例——fetch/试编/门禁 ①—⑦/strip/投放 → [`001-building/test-cases.md`](./001-building/test-cases.md)（TC-001-01~17）；lock 回写/CI 流水线/归档/断言修复 → [`002-building-workflow/test-cases.md`](./002-building-workflow/test-cases.md)（TC-002-01~16）。执行后先回模块文件，本表族级状态随之更新。

### 2.3 M2 真机探针（⬜ 规划引用，规划 §7.1；出口 G3）

| 探针 | 判据 | 状态 |
|---|---|---|
| P1 版本回程 | `pty.spawn(libuv_cli.so, ['--version'])`：版本串回程、exit/close 齐全 | ⬜ |
| P2 venv | `uv venv <filesDir>/uv/venvs/t1`：venv 落 filesDir、`pyvenv.cfg` 生成；bin/python symlink 可用性记录事实 | ⬜ |
| P3 HTTPS（rustls 根证书） | `uv pip install <纯py包>`（如 `packaging`）：安装进 filesDir venv site-packages | ⬜ |
| P4 组合链路 | `UV_PYTHON` 指向 python-cli 物化解释器后 `uv venv` → `uv run python -c …` 成功 | ⬜ |
| P5 cache 生效 | `uv cache dir` 输出 = `UV_CACHE_DIR` 值且目录落 filesDir | ⬜ |
| P6 libc++ 供给 | 若 NEEDED 含 `libc++_shared.so`：未注入 `LD_LIBRARY_PATH` 启动失败为预期；注入后回程成功 | ⬜ |

> **模块化落点（2026-11-03）**：P1–P6 已在 [`003-cli/test-cases.md`](./003-cli/test-cases.md) 展开为 **CLI 主用例全集 TC-003-00~17**（shell 域等价载体：adb `/data/local/tmp`；App 域/PTY 结论仍归消费方）。映射：P1→TC-003-01、P2→TC-003-05、P3→TC-003-07、P4→TC-003-14、P5→TC-003-03、P6→TC-003-12。

---

## 3. 禁止的判据（写进每条用例的验收纪律）

| 禁止的判据 | 为什么是假信号 | 必须改用的判据 |
|---|---|---|
| **「cargo build 成功 ⇒ 产物合格」** | 编译成功不保证 PIE/linker64/白名单/16KB | provision 七门禁全过（`--inspect`） |
| **「门禁全过 ⇒ 真机可用」** | 门禁只覆盖 ELF 形态，不覆盖 exec 落盘/环境注入/TLS 根证书 | M2 真机探针 P1–P6 回程 |
| **「本地试编通过 ⇒ CI 可复现」** | 本地 NDK/缓存与 runner 不同（本机无 NDK 亦可） | 干净 runner 单条 workflow 重出（G1） |
| **「`--allow-page-align-4k` 放行 ⇒ 可发布」** | 该开关仅 bring-up，16KB 设备必炸 | 门禁 ⑦ 无放行的全过 |
| **「draft lock 的 0/空值 ⇒ 工具缺陷」** | draft 语义就是「仅记录不比对」（S6） | 以 `--inspect`/`--check` 的其它门禁位为准 |
| **「AAR 构建成功 ⇒ 发布就绪」** | 发布需 RELEASE=true + Token + lock=released + 门禁全过 | overall-plan §6.3 检查清单 |
| **「sdist 安装失败 ⇒ uv 坏了」** | sdist 不可安装是**已登记能力边界**（B-2），非缺陷 | 只用纯 wheel 域判 P3 |

---

## 4. 取证通道（L3，规划引用 ⬜）

| # | 通道 | 判定方式 | 现状 |
|---|---|---|---|
| ① | PTY 回程（node-pty `forkpty`） | 终端输出直接可读（`uv --version` 等），exit/close 事件齐全 | ⬜ M2（消费方 App 提供 PTY） |
| ② | 文件系统回读 | filesDir 下 venv/cache 目录结构与 `pyvenv.cfg` 核对 | ⬜ M2 |
| ③ | 网络回程 | `uv pip install` 成功即 rustls 根证书生效的端到端证书 | ⬜ M2 P3 |
| ④ | AAR 内容核对 | 解包 AAR 核对 `jni/arm64-v8a/` 清单与 `META-INF/uv-cli.properties` 字段 | ⬜ 首产后 |

> 依据：规划 §7.1 探针表（P1–P6）；本仓无自建端点（非服务型工具），回程判据以**终端输出 + 文件系统**为准。

---

## 5. 已知基线数值

**当前无真实产物基线** ⬜——首个 M1 产物落地后在此登记并冻结：

| 指标 | 计划登记项 | 现状 |
|---|---|---|
| `libuv_cli.so` size / sha256 | lock `releases[0]` 回写值 | ⬜（draft：0 / ""） |
| DT_NEEDED 实测清单 | 回填 lock + §2.2 TC-M1-06 | ⬜ |
| 产物体积量级 | 预估 25–40 MB（工作区方案 §3.2 口径，未实测 ⚠️） | ⬜ |
| rust / cargo-ndk / NDK 版本 | lock `builtFrom`（M1 结构化扩展） | ⬜ |
| 归档 sha256 | Release 资产 `.sha256` | ⬜ |

**基线使用方式**：每次重建/换版本后，把新产物指标与本节（届时已回填）逐项 diff；任何变化都必须给出输入层面的解释（uv 版本 / rust 版本 / NDK / flags），否则视为回归。
