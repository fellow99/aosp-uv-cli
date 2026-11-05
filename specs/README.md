# 规格文档索引 —— `aosp-uv-cli`

**项目名称：** `aosp-uv-cli`（Maven 坐标 `io.github.fellow99:uv-cli`）
**需求编号/名称：** **000-scaffold 工程搭建** · 规范文档存放目录：`specs/`
**制品版本：** `0.9.0`（**draft** 计划值；= uv 上游版本，独立 semver，首产按 CI 实际钉选回写）
**技术栈：** Gradle 9.4.1 / AGP 9.2.1 / vanniktech maven-publish 0.37.0（AAR 容器，`useLegacyPackaging=true`）+ 纯 Node host 工具链（exec 门禁 provision）+ Rust 交叉编译（`aarch64-linux-android`，M1 规划）/ rustls（M1 规划）
**文档生成时间：** 2026-11-02 · **最后更新：** 2026-11-05 · **阶段：M0 骨架已完成；001/002/003 已立项（规划 §10.2）；101-probe-app 本批新增（as-built + 能力披露 + 补充探针）；M1 实现未开工**

> **权威规划文档是 [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（v2.0，含 D1–D7 决策与 §10.2 模块注册）。**
> 本目录是它的**收敛/展开版**：只做细化与验收，**不复制粘贴**，所有结论回引规划的 § 号。
> 新增平台结论必须先写进规划文档，再回到这里引用（宪法 P8）。
> **as-built 纪律**：本目录只把已建成部分当事实（✅）；M1/M2/M3/M4 的设计一律以「规划引用 ⬜」出现（宪法 P6）。

---

## 一、文档总览

| 层级 | 分类 | 文档数量 | 说明 |
|---|---|---|---|
| 整体 | 项目级顶层文档 | 5 | `constitution.md` · `ARCHITECTURE.md` · `TECH.md` · `STRUCTURE.md` · `SPECS_CHECKLIST.md` |
| 整体 | 整体规格文档 | 3 | `overall-spec.md` · `overall-plan.md` · `overall-test-cases.md` |
| 索引 | 本索引 | 1 | `README.md` |
| 模块 | `000-scaffold` | 4 | spec · plan（as-built）· tasks · test-cases |
| 模块 | `001-building` | 4 | spec · plan · tasks · test-cases（FR-001-xxx；⬜ M1-T1~T4） |
| 模块 | `002-building-workflow` | 4 | spec · plan · tasks · test-cases（FR-002-xxx；⬜ M1-T5） |
| 模块 | `003-cli` | 4 | spec · plan · tasks · test-cases（FR-003-xxx；⬜ M2-T1/T2；**主用例全集 TC-003-00~17**） |
| 模块 | `101-probe-app` | 4 | spec · plan · tasks · test-cases（FR-101-probe-xxx；**as-built 逆向** + 修复设计 §4.3 能力披露 + 补充探针 TC-UV-30~35） |
| **合计** | **6 目录 / 29 文件** | | 项目级 9 + 模块 20 |

> **刻意不生成** `API.md` / `overall-api.md`：本系统**不对外提供任何 API**——AAR 容器无 Kotlin/Java 源、无嵌入接口（exec 型独立进程）。对外契约 = Maven 坐标 + AAR 内容边界 + 运行期环境契约，见 [`overall-spec.md`](./overall-spec.md) §3.3/§5。
> **刻意不生成** `overall-data-model.md`：唯一数据实体 `uv-cli.lock.json` 的全字段模型（含 `builtFrom.toolchain` 结构化扩展设计）已完整落在 [`000-scaffold/plan.md`](./000-scaffold/plan.md) §3。

---

## 二、项目级顶层文档

| 文档 | 路径 | 行数 | 说明 |
|---|---|---|---|
| **项目宪法** | [constitution.md](./constitution.md) | 154 | 8 条不可协商原则（P1 fetch 不改源 · P2 lock 唯一事实源 · P3 二进制不入库 · P4 门禁强制 · P5 发布卫生 · P6 未实测 ⬜ · P7 不下载上游二进制（uv 无 Android 产物一律自建）· P8 先改文档再改实现）+ 10 条规约（S1–S10）+ 证据纪律 + 评审清单 + 变更流程 |
| **整体架构** | [ARCHITECTURE.md](./ARCHITECTURE.md) | 172 | 构建期分层（as-built ASCII 图）+ 运行期 exec 形态（规划引用）+ 与 pty（dlopen 库线）的门禁/打包对照 + D1–D7 as-built 落点核对 + 与 python-cli/node-runtime/git-cli 的组合架构（规划标注）+ 门禁层 + 已知缺口 |
| **技术选型** | [TECH.md](./TECH.md) | 131 | 选型总表（**含已实现 vs 规划状态列**：Gradle 9.4.1 / AGP 9.2.1 / vanniktech 0.37.0 / exec 门禁纯 Node ✅；rust tier2 + cargo-ndk + rustls ⬜ 规划）+ 被否方案（`useLegacyPackaging=false`、AAR 自带 libc++、`libuv.so` 命名、上游二进制、`uv python install`…）+ 版本矩阵 + exec 七门禁硬数据 + 退出码纪律 + 命令速查 |
| **项目结构** | [STRUCTURE.md](./STRUCTURE.md) | 147 | 逐文件目录树（真实行数）+ 关键配置位置 + 产物落点 + 需求映射 + 不入库清单 + 规划不存在路径 + 2 处 ⚠️ 事实性观察（`VERSION_NAME` 遗留元数据 / 无 Gradle Wrapper） |
| **检查清单** | [SPECS_CHECKLIST.md](./SPECS_CHECKLIST.md) | 78+ | 规格文档完成度追踪（项目级 + 模块级）+ 生成纪律 + 质量检查 + 未闭合项 |

### 整体规格文档

| 文档 | 路径 | 行数 | 说明 |
|---|---|---|---|
| **整体规格** | [overall-spec.md](./overall-spec.md) | 171 | 技术无关需求：目的/用户故事/边界 + `FR-000-xxx` 沿用（RFC 2119，逐条可证伪验收判据与现状列）+ 六条边界限制（**`uv python install` 禁用 / sdist 不可安装 / git 依赖源需 git-cli / `libc++_shared.so` 不随包 / filesDir 注入 / TLS 内嵌根证书**）+ 非功能需求 + 项目级出口判据 A1–A6 |
| **整体方案** | [overall-plan.md](./overall-plan.md) | 165 | 技术上下文（M0–M4 里程碑现状）+ 宪法符合性逐条检查（P1–P8 全 ✅，1 条 ⚠️）+ M1 实现顺序（T1 试编→T2 fetch→T3 工具链→T4 strip/门禁→T5 CI/Release）+ 横切关注点（可复现/错误处理/供应链/组合契约/体积）+ 测试策略 + 两段式发布（GitHub Release 先行 → Maven Central 随后） |
| **测试用例索引** | [overall-test-cases.md](./overall-test-cases.md) | 111 | 五层测试分层（L1a/L1b/L2/L3/L4）+ 用例族索引（已执行 TC-000-01~05 ✅ / M1 待跑 ⬜ / M2 探针 P1–P6 ⬜）+ **模块化落点映射（TC-001/002/003）** + 禁止的判据 + 基线数值现状 |

---

## 三、模块级文档

### 000-scaffold — 工程搭建（✅ M0）

> `aosp-uv-cli` 的立项骨架：Gradle 多模块骨架（仅 `:uv-cli` AAR 容器）、`useLegacyPackaging=true` exec 打包、
> `uv-cli.lock.json` 唯一事实源（draft 0.9.0，不伪造哈希）、`tools/provision.mjs` exec 型七门禁（退出码 0/2/1、
> jniLibs 单文件纪律、BANNED `libnode.so`）、fetch/build 脚本骨架（exit 2 SCAFFOLD）、配置期 CI。
> **uv 本体尚未构建（M1）**——fetch/build 的真实行为、CI 真实流水线与 Release 全部为规划引用。

| 文档 | 链接 | 行数 | 说明 |
|---|---|---|---|
| 功能规格 | [000-scaffold/spec.md](./000-scaffold/spec.md) | 27 | 技术无关：目的 + FR-000-001~005 / 010~013 / 030~036 / 040~042（摘要口径）+ 验收场景 |
| 技术方案（as-built） | [000-scaffold/plan.md](./000-scaffold/plan.md) | 222 | 实现特定：技术上下文 + 宪法合规 + **lock JSON 数据模型**（根结构 / ReleaseRecord draft 真实值 / `builtFrom.toolchain` 结构化扩展设计 ⬜）+ **provision CLI 与退出码契约**（六种用法 × 退出码 / 七门禁逐项落点 / 兄弟文件 / BANNED / 元数据字段）+ 文件清单（真实行数）+ FR 全量交叉引用 + 测试考虑 + 待实现清单（含 §7 退出码断言缺陷登记与模块归属） |
| 任务拆解 | [000-scaffold/tasks.md](./000-scaffold/tasks.md) | 13 | T1–T8 全部完成（8/8） |
| 模块测试用例 | [000-scaffold/test-cases.md](./000-scaffold/test-cases.md) | 17 | TC-01~05 + 执行记录（2026-11-02，scaffold 提交前，全过） |

### 001-building — 构建（⬜ M1-T1~T4）

> 官方 uv 源码 tarball → **过 exec 门禁的 Android arm64 单文件制品** `libuv_cli.so`：fetch 钉选（PINS + sha256）、
> rust 工具链装配（rustup + cargo-ndk，config.toml 回退）、C 依赖可编性探针（ring/zstd-sys/aws-lc-rs，降级先回写规划）、
> `--locked` 交叉编译 + 16KB RUSTFLAGS、strip/改名/双 METADATA/门禁自检/lock 回写素材。

| 文档 | 链接 | 行数 | 说明 |
|---|---|---|---|
| 功能规格 | [001-building/spec.md](./001-building/spec.md) | 73 | FR-001-001~006（fetch）/010~015（工具链）/020~026（编译+探针）/030~035（整理） |
| 技术方案 | [001-building/plan.md](./001-building/plan.md) | 159 | PINS 表、S1–S9 流程、cargo-ndk 双路线、cc 环境接线、TLS/D5 口径、lock 扩展落地、待定项 |
| 任务拆解 | [001-building/tasks.md](./001-building/tasks.md) | 16 | T1–T12 |
| 测试用例 | [001-building/test-cases.md](./001-building/test-cases.md) | 43 | TC-001-01~17（L1/L1.5） |

### 002-building-workflow — 构建流水线（⬜ M1-T5）

> lock 回写工具化闭环（draft → released，素材强校验 + 单向守卫）+ CI 真实流水线（rustup/cargo-ndk 装机、缓存、
> 归档 + cargo 许可清单、tag-only Release）+ **退出码断言语义修复**（000 plan §7 缺陷）+ 配置期门禁保留。
> 本仓无 provision 门禁扩展（单 `.so`、无 assets，规划 §6）。

| 文档 | 链接 | 行数 | 说明 |
|---|---|---|---|
| 功能规格 | [002-building-workflow/spec.md](./002-building-workflow/spec.md) | 59 | FR-002-001~006（lock 回写）/010~016（CI）/020~021（不回归） |
| 技术方案 | [002-building-workflow/plan.md](./002-building-workflow/plan.md) | 118 | 回写命令面/字段映射/守卫、workflow job 结构、断言修复口径、归档清单 |
| 任务拆解 | [002-building-workflow/tasks.md](./002-building-workflow/tasks.md) | 15 | T1–T11 |
| 测试用例 | [002-building-workflow/test-cases.md](./002-building-workflow/test-cases.md) | 38 | TC-002-01~16（守卫负例矩阵 + CI 静态检查） |

### 003-cli — CLI 运行期验证（⬜ M2-T1/T2）

> adb shell 域 L3 探针：部署 + `bin/uv` symlink 农场 + env 契约注入（规划 §7 表；`SSL_CERT_FILE` 永不注入）+
> **CLI 主用例全集**（版本/venv/pip 装-列-卸/HTTPS/rustls 根证书反证/LD_LIBRARY_PATH 双向/组合 python-cli/限制事实化）。
> 设备策略：真机 → x86_64 模拟器（ARM 翻译）→ arm64 AVD；载体形态必须入报告。

| 文档 | 链接 | 行数 | 说明 |
|---|---|---|---|
| 功能规格 | [003-cli/spec.md](./003-cli/spec.md) | 76 | FR-003-001~005（harness）/010~018（主行为）/030~034（env 契约）/040~044（限制事实化） |
| 技术方案 | [003-cli/plan.md](./003-cli/plan.md) | 92 | harness 三件套、env 注入表（shell 域实例化）、P1–P6 映射、设备策略、SKIP 语义 |
| 任务拆解 | [003-cli/tasks.md](./003-cli/tasks.md) | 14 | T1–T10 |
| 测试用例 | [003-cli/test-cases.md](./003-cli/test-cases.md) | 58 | **TC-003-00~17 主用例全集**（A 自检/B 版本/C venv+pip/D TLS 反证/E 组合与限制） |

### 101-probe-app — App 域探针工程（✅ 本批新增，as-built）

> 003-cli 的 App 域探针载体独立成模块（specs-as-built 逆向既有实现）：untrusted_app SELinux 域 exec、
> nativeLibraryDir 落盘（D1）、filesDir env 注入、启动即自动执行 + JSON 报告。本批补充**能力边界披露**
> （修复设计 §4.3：纯 py 域可用 / C-Rust ≈ 不可装 / sdist 不可设备编译 / 无编译器 / `uv python install` 不支持 /
> 隔离模式检查解释器依赖自洽 prefix）与 **6 条 TC-UV-30~35 边界事实探针**（verdict 三态 PASS/FAIL/FACT）。
> 设备实测（2026-11-05，emulator-5554 ndk_translation App 域）：14 条 = PASS 8 + FACT 6 + FAIL 0。

| 文档 | 链接 | 行数 | 说明 |
|---|---|---|---|
| 功能规格 | [101-probe-app/spec.md](./101-probe-app/spec.md) | 100 | FR-101-probe-001~017（技术无关 + RFC 2119）+ 实体 + 用户故事 + 验收场景 + NFR + 依赖 + 边界声明 |
| 技术方案（as-built） | [101-probe-app/plan.md](./101-probe-app/plan.md) | 130 | 工程形态/行号映射（MainActivity 416 行）、env 注入表、补充探针判据、FR 交叉引用、构建/运行实测 |
| 任务拆解 | [101-probe-app/tasks.md](./101-probe-app/tasks.md) | 29 | T1–T14（as-built 完成态；T5 规划 §10.2 登记未做→已记录） |
| 测试用例 | [101-probe-app/test-cases.md](./101-probe-app/test-cases.md) | 42 | TC-003-20~27（既有）+ TC-UV-30~35（新增）判据与实测回填 |

---

## 四、模块编号一览（注册于规划 §10.2，2026-11-03）

| 编号 | 模块名 | 目录 | 状态 | 规划出处 |
|---|---|---|---|---|
| 000 | 工程搭建（scaffold） | [`000-scaffold/`](./000-scaffold/) | ✅ M0 完成 | 规划 §10 M0 + §10.2 |
| 001 | 构建（源钉选 + Rust 交叉编译） | [`001-building/`](./001-building/) | ⬜ 立项 | 规划 §10 M1-T1~T4 + §10.2 |
| 002 | 构建流水线（lock 回写 + CI + 发布） | [`002-building-workflow/`](./002-building-workflow/) | ⬜ 立项 | 规划 §10 M1-T5 + §10.2 |
| 003 | CLI 运行期验证（shell 域探针） | [`003-cli/`](./003-cli/) | ⬜ 立项 | 规划 §10 M2-T1/T2 + §10.2 |
| 101 | App 域探针工程（probe-app） | [`101-probe-app/`](./101-probe-app/) | ✅ 本批新增（as-built） | **§10.2 待登记**（本批不改规划文档；P8 登记留给编排者/后续批次）· 修复设计 §4.3 |

> 编号分配须**先写进规划 §10.2 再建目录**（P8）；FR 族 = `FR-<模块号>-xxx`。
> 本仓无 M1-T6/T7 类任务（provision 无扩展、无独立探针 App——shell 域 harness 即 003-cli 交付物，规划 §10.2 注）。
> ⚠️ 101 编号按 P8 应先注册于规划 §10.2 于建目录前；本批按需求范围未改规划文档，登记待补（见 SPECS_CHECKLIST §五）。

---

## 五、快速导航

| 目标读者 | 推荐阅读顺序 |
|---|---|
| **新加入维护者** | [`docs/000-工程规划.md`](../docs/000-工程规划.md) → [constitution.md](./constitution.md) → [STRUCTURE.md](./STRUCTURE.md) → [overall-spec.md](./overall-spec.md) |
| **架构 / Tech Lead** | [ARCHITECTURE.md](./ARCHITECTURE.md) → [TECH.md](./TECH.md) → [overall-plan.md](./overall-plan.md) → 规划 §3.1（D1–D7）/ §4 / §9 |
| **M1 实现者** | [001-building/plan.md](./001-building/plan.md) → 规划 §4（构建设计）/§4.3（探针）→ [002-building-workflow/plan.md](./002-building-workflow/plan.md) → [000-scaffold/plan.md](./000-scaffold/plan.md) §8（待实现清单） |
| **消费方（App 开发者）** | [`../README.md`](../README.md) → [overall-spec.md](./overall-spec.md) §5（边界与环境契约）→ 规划 §7（注入表） |
| **测试 / QA** | [overall-test-cases.md](./overall-test-cases.md) → [003-cli/test-cases.md](./003-cli/test-cases.md)（主用例全集）→ [SPECS_CHECKLIST.md](./SPECS_CHECKLIST.md) §五 |
| **发布工程师** | [overall-plan.md](./overall-plan.md) §6 → [002-building-workflow/plan.md](./002-building-workflow/plan.md) → [TECH.md](./TECH.md) §6.3 → 规划 §10.1 / §12 |
| **101 探针 / App 域验证** | [101-probe-app/plan.md](./101-probe-app/plan.md)（as-built）→ [101-probe-app/test-cases.md](./101-probe-app/test-cases.md)（TC-UV-30~35）→ [003-cli/test-cases.md](./003-cli/test-cases.md) §E2 → 修复设计 §4.2/§4.3（能力边界口径） |

### 快照命令（先看证据，再看结论；均 ✅ 可跑）

```bash
gradle :uv-cli:tasks --console=plain                                # 配置期门禁（无 .so 必须过）
node tools/provision.mjs --check                                    # 未投放 ⇒ exit 2（预期语义）
node tools/provision.mjs --inspect <libuv_cli.so>                   # 打印某产物七门禁报告（不写文件）
node --check tools/provision.mjs && node --check scripts/fetch-uv-cli-source.mjs && bash -n scripts/build-uv-cli-android.sh   # 语法门
cat uv-cli.lock.json                                                # 唯一事实源（当前 draft）
```

---

**文档维护者：** `aosp-uv-cli` 维护团队 · **权威来源：** [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（v2.0 + §10.2）· **证据标记口径：** [constitution.md](./constitution.md) §三
