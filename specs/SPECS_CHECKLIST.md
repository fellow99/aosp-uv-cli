# SPECS_CHECKLIST.md —— 规格文档完成度追踪

> 工程：`aosp-uv-cli`（`io.github.fellow99:uv-cli`）· 需求编号/名称：**000-scaffold 工程搭建**
> 规范文档存放目录：`specs/` · 生成日期：**2026-11-02**
> 权威规划文档：[`../docs/000-工程规划.md`](../docs/000-工程规划.md)（v2.0，**结论以它为准**）
>
> 状态口径：✅ 已完成 · ⚠️ 已完成但含未闭合项（见备注）· ⬜ 待生成

---

## 一、项目级文档

| # | 文档 | 路径 | 状态 | 说明 |
|---|---|---|---|---|
| P-01 | 项目宪法 | [constitution.md](./constitution.md) | ✅ | 8 条不可协商原则（P1 fetch 不改源 · P2 lock 唯一事实源 · P3 二进制不入库 · P4 门禁强制 · P5 发布卫生 · P6 未实测 ⬜ · P7 不下载上游二进制 · P8 先改文档再改实现）+ 10 条规约（S1–S10）+ 证据纪律 + 评审清单 + 变更流程 |
| P-02 | 整体架构 | [ARCHITECTURE.md](./ARCHITECTURE.md) | ✅ | 构建期分层（as-built）+ 运行期形态（规划引用）+ 与 pty（dlopen 线）的架构对照 + D1–D7 落点核对 + 组合架构（python-cli/node-runtime/git-cli，规划标注）+ 门禁层 + 缺口 |
| P-03 | 技术选型 | [TECH.md](./TECH.md) | ✅ | 技术/版本/用途/理由 + **已实现 vs 规划状态列** + 被否方案 + 版本矩阵 + 依赖清单 + exec 七门禁硬数据 + 退出码纪律 + 命令速查 |
| P-04 | 目录结构 | [STRUCTURE.md](./STRUCTURE.md) | ✅ | 逐文件目录树（真实行数）+ 关键配置 + 产物落点 + 需求映射 + 不入库清单 + 规划不存在路径 + 2 处 ⚠️ 事实性观察 |
| P-05 | 整体规格 | [overall-spec.md](./overall-spec.md) | ✅ | 技术无关需求（FR-000-xxx 沿用，RFC 2119）+ 用户故事 + 系统边界 + 六条边界限制（`uv python install` 禁用 / sdist 不可 / git 依赖源需 git-cli / libc++ 不随包 / filesDir / TLS）+ 非功能需求 + 可证伪验收 |
| P-06 | 整体技术方案 | [overall-plan.md](./overall-plan.md) | ✅ | 技术上下文 + 宪法符合性逐条检查 + M1 实现顺序 + 横切关注点（可复现/错误处理/供应链/组合契约/体积）+ 测试策略 + 两段式发布 |
| P-07 | 测试用例索引 | [overall-test-cases.md](./overall-test-cases.md) | ✅ | 五层测试分层 + 用例族索引（已执行 TC-000-01~05 / M1 待跑 TC-M1 / M2 探针 P1–P6）+ 禁止的判据 + 基线数值现状 |
| P-08 | 规格检查清单 | SPECS_CHECKLIST.md | ✅ | 本文件 |
| P-09 | 规格索引 | [README.md](./README.md) | ✅ | 按实际产出扫描生成；链接已全验 |
| — | `API.md` / `overall-api.md` | — | ⛔ 刻意不生成 | 本系统**不对外提供任何 API**：AAR 容器无 Kotlin/Java 源、无嵌入接口（exec 型独立进程）；对外契约 = Maven 坐标 + AAR 内容 + 运行期环境契约（见 [overall-spec.md](./overall-spec.md) §3.3/§5） |
| — | `overall-data-model.md` | — | ⛔ 刻意不生成 | 唯一数据实体是 `uv-cli.lock.json`（53 行），其全字段模型已完整落在 [`000-scaffold/plan.md`](./000-scaffold/plan.md) §3（含 `builtFrom.toolchain` 结构化扩展设计），单开一份数据模型文档无增量 |

---

## 二、模块级文档

| # | 模块 | 目录 | spec.md | plan.md | tasks.md | test-cases.md | 状态 | 备注 |
|---|---|---|---|---|---|---|---|---|
| M-01 | 工程搭建（scaffold） | [`000-scaffold/`](./000-scaffold/) | ✅（既有） | ✅（既有，含 §7 缺陷登记与模块归属注） | ✅（既有，8/8 完成） | ✅（既有，TC-01~05 已执行） | ⚠️ | scaffold 全过；`spec.md` 为摘要口径（FR-000-xxx 分组呈现），`plan.md` 补齐 as-built 技术方案并交叉引用全部 FR |
| M-02 | 构建（building） | [`001-building/`](./001-building/) | ✅ **本批新增** | ✅ **本批新增**（planned，实现后回写 as-built） | ✅ **本批新增**（T1–T12 ⬜） | ✅ **本批新增**（TC-001-01~17 ⬜） | ✅ 文档 / ⬜ 实现 | FR-001-xxx；覆盖 M1-T1~T4（规划 §10.2） |
| M-03 | 构建流水线（building-workflow） | [`002-building-workflow/`](./002-building-workflow/) | ✅ **本批新增** | ✅ **本批新增**（planned） | ✅ **本批新增**（T1–T11 ⬜） | ✅ **本批新增**（TC-002-01~16 ⬜） | ✅ 文档 / ⬜ 实现 | FR-002-xxx；覆盖 M1-T5（lock 回写闭环 + CI 真实流水线） |
| M-04 | CLI 运行期验证（cli） | [`003-cli/`](./003-cli/) | ✅ **本批新增** | ✅ **本批新增**（planned） | ✅ **本批新增**（T1–T10 ⬜） | ✅ **本批新增**（**主用例全集 TC-003-00~17** ⬜） | ✅ 文档 / ⬜ 实现 | FR-003-xxx；覆盖 M2-T1/T2（shell 域探针 P1–P6 等价） |
| M-05 | App 域探针工程（probe-app） | [`101-probe-app/`](./101-probe-app/) | ✅ **本批新增**（as-built 逆向） | ✅ **本批新增**（as-built） | ✅ **本批新增**（T1–T14） | ✅ **本批新增**（TC-003-20~27 既有 + TC-UV-30~35 新增，14 条实测） | ✅ 文档 / ✅ 实现（probe-app 已建成于 003-cli；本批规格化 + 能力披露 + 补充探针） | FR-101-probe-xxx；App 域消费方形态（untrusted_app exec / filesDir 注入）+ 修复设计 §4.3 能力边界披露 |

> 模块编号注册于规划 **§10.2**（2026-11-03，P8：先改规划再建目录）。FR 族 = `FR-<模块号>-xxx`；各模块四件套（spec/plan/tasks/test-cases）齐备方可标 ✅ 文档。

---

## 三、生成顺序与依据

1. **先整体、后模块**：项目级文档（P-01…P-07）先建立术语、宪法与证据口径，模块 `plan.md` 再细化——避免前后引用不存在的文件。
2. **最后生成索引**：`README.md` 与本清单按**实际目录内容**扫描生成，不预测结构。
3. **不复制粘贴**：所有结论回引 `docs/000-工程规划.md` 的 § 号（D1–D7 / §4 / §6 / §7 / §8 / §9 / §10 / §12 / §13）；规格只做收敛/展开与验收判据。
4. **证据标记**：每条非显然结论带 ✅实测 / ⬜规划引用 / ⚠️观察（口径见 `constitution.md` P6 / §三）。
5. **as-built 纪律**：只写已建成事实；规划（M1 rust 交叉编译、ring/zstd 探针、rustls、libc++_shared 供给、两段式发布）一律以「规划引用 ⬜」出现并标注规划 §。

---

## 四、质量检查

| 检查项 | 结果 |
|---|---|
| 每条结论可回溯到源码（path:line，2026-11-02 快照）或规划 § 号 | ✅ |
| 无占位内容（文档内无 `TODO`/`TBD` 作为文档自身的未完成项；lock/脚本中的 `TBD`/`SCAFFOLD` 是**被记录的 as-built 事实**而非文档缺口） | ✅ |
| `overall-spec.md` 技术无关（无文件路径级实现描述；坐标/SDK 值属需求口径） | ✅ |
| `000-scaffold/plan.md` 引用真实文件路径与真实行数 | ✅ |
| `plan.md` 交叉引用本模块 `spec.md` 的 `FR-000-*` | ✅（§6 全量对照） |
| 模块 spec 与 plan 成对 | ✅（1/1） |
| 规划 vs as-built 逐条区分（⬜ 标记） | ✅ |
| `README.md` 链接全部指向存在的文件 | ✅（生成后已逐链接核验） |
| 文档数与 `specs/` 实际文件数一致 | ✅（29 文件 = 项目级 9 + 模块 20；000/001/002/003/101 五模块 ×4） |
| 各文档 `[NEEDS CLARIFICATION]` ≤ 3 | ✅（全部为 0——所有论断均有源码/规划出处） |

---

## 五、未闭合项（不属文档缺失，属**实现**阶段工作；全部规划引用 ⬜）

| 项 | 归属 | 依据 |
|---|---|---|
| fetch / build 脚本完整实现（当前 exit 2 SCAFFOLD，属预期骨架语义） | M1-T2/T3/T4 | 规划 §4.2 / §10 |
| C 依赖（ring/zstd-sys/…）NDK 可编性探针与降级拍板 | M1-T1 | 规划 §4.3 / §11 R1/R2 |
| CI 真实流水线（rustup/cargo-ndk/缓存/归档/Release）替换 scaffold CI | M1-T5 | 规划 §9 / §10 |
| lock 回写 released + `builtFrom.toolchain` 结构化扩展 + DT_NEEDED 实测清单 | M1 首产后 | 规划 §6 / §8 |
| Cargo 依赖 sha 记录粒度（方案 A/B）拍板 | M1 | 规划 §8 / R7 |
| 消费方环境注入 + 真机探针 P1–P6（G3） | M2 | 规划 §7 / §7.1 |
| Maven Central 首发与 runbook 实走回填 | M3 | 规划 §10.1 |
| lock 回写自动化评估 | M4 | 规划 §10 M4 |
| ⚠️ `gradle.properties` 的 `VERSION_NAME=0.1.0`（未生效遗留元数据）清理 | M1 顺手项 | STRUCTURE §2.2-1 |
| ⚠️ 编号 101（probe-app）未注册于规划 §10.2（P8「先注册再建目录」）——本批不改规划文档 | 编排者/后续批次 | P8 · 101-probe-app spec §8 |
