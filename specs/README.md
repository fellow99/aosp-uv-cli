# 规格文档索引 —— `aosp-uv-cli`

**项目名称：** `aosp-uv-cli`（Maven 坐标 `io.github.fellow99:uv-cli`）
**需求编号/名称：** **000-scaffold 工程搭建** · 规范文档存放目录：`specs/`
**制品版本：** `0.9.0`（**draft** 计划值；= uv 上游版本，独立 semver，首产按 CI 实际钉选回写）
**技术栈：** Gradle 9.4.1 / AGP 9.2.1 / vanniktech maven-publish 0.37.0（AAR 容器，`useLegacyPackaging=true`）+ 纯 Node host 工具链（exec 门禁 provision）+ Rust 交叉编译（`aarch64-linux-android`，M1 规划）/ rustls（M1 规划）
**文档生成时间：** 2026-11-02 · **最后更新：** 2026-11-02 · **阶段：M0 骨架已完成；M1 真实交叉编译未开工**

> **权威规划文档是 [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（v2.0，含 D1–D7 决策）。**
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
| 模块 | `000-scaffold` | 4 | `spec.md`（既有）· `plan.md`（本批新增）· `tasks.md`（既有）· `test-cases.md`（既有） |
| **合计** | **2 目录 / 13 文件** | | 项目级 9 + 模块 4 |

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
| **检查清单** | [SPECS_CHECKLIST.md](./SPECS_CHECKLIST.md) | 78 | 规格文档完成度追踪（项目级 + 模块级）+ 生成纪律 + 质量检查 + 未闭合项 |

### 整体规格文档

| 文档 | 路径 | 行数 | 说明 |
|---|---|---|---|
| **整体规格** | [overall-spec.md](./overall-spec.md) | 171 | 技术无关需求：目的/用户故事/边界 + `FR-000-xxx` 沿用（RFC 2119 MUST，逐条可证伪验收判据与现状列）+ 六条边界限制（**`uv python install` 禁用 / sdist 不可安装 / git 依赖源需 git-cli / `libc++_shared.so` 不随包 / filesDir 注入 / TLS 内嵌根证书**）+ 非功能需求 + 项目级出口判据 A1–A6 |
| **整体方案** | [overall-plan.md](./overall-plan.md) | 165 | 技术上下文（M0–M4 里程碑现状）+ 宪法符合性逐条检查（P1–P8 全 ✅，1 条 ⚠️）+ M1 实现顺序（T1 试编→T2 fetch→T3 工具链→T4 strip/门禁→T5 CI/Release）+ 横切关注点（可复现/错误处理/供应链/组合契约/体积）+ 测试策略 + 两段式发布（GitHub Release 先行 → Maven Central 随后） |
| **测试用例索引** | [overall-test-cases.md](./overall-test-cases.md) | 107 | 五层测试分层（L1a 配置期 / L1b 工具纪律 / L2 CI 端到端 / L3 真机探针 / L4 回归基线）+ 用例族索引（已执行 TC-000-01~05 ✅ / M1 待跑 TC-M1-01~12 ⬜ / M2 探针 P1–P6 ⬜）+ **禁止的判据** + 基线数值现状 |

---

## 三、模块级文档：000-scaffold（工程搭建）

> `aosp-uv-cli` 的立项骨架：Gradle 多模块骨架（仅 `:uv-cli` AAR 容器）、`useLegacyPackaging=true` exec 打包、
> `uv-cli.lock.json` 唯一事实源（draft 0.9.0，不伪造哈希）、`tools/provision.mjs` exec 型七门禁（退出码 0/2/1、
> jniLibs 单文件纪律、BANNED `libnode.so`）、fetch/build 脚本骨架（exit 2 SCAFFOLD）、配置期 CI。
> **uv 本体尚未构建（M1）**——fetch/build 的真实行为、CI 真实流水线与 Release 全部为规划引用。

| 文档 | 链接 | 行数 | 说明 |
|---|---|---|---|
| 功能规格 | [000-scaffold/spec.md](./000-scaffold/spec.md) | 27 | 技术无关：目的 + FR-000-001~005 / 010~013 / 030~036 / 040~042（摘要口径）+ 验收场景 |
| 技术方案（**本批新增，as-built**） | [000-scaffold/plan.md](./000-scaffold/plan.md) | 221 | 实现特定：技术上下文（Gradle 9.4.1/AGP 9.2.1/vanniktech 0.37.0/exec 打包）+ 宪法合规 + **lock JSON 数据模型**（根结构 / ReleaseRecord draft 真实值 / `builtFrom.toolchain` 结构化扩展设计 ⬜ / 依赖 sha 粒度方案 A/B ⬜）+ **provision CLI 与退出码契约**（六种用法 × 退出码 / 七门禁逐项落点 / 兄弟文件 / BANNED / 元数据字段）+ 文件清单（真实行数）+ FR 全量交叉引用 + 测试考虑 + 待实现清单 |
| 任务拆解 | [000-scaffold/tasks.md](./000-scaffold/tasks.md) | 13 | T1–T8 全部完成（8/8） |
| 模块测试用例 | [000-scaffold/test-cases.md](./000-scaffold/test-cases.md) | 17 | TC-01~05 + 执行记录（2026-11-02，scaffold 提交前，全过） |

---

## 四、模块编号一览

| 编号 | 模块名 | 目录 | 状态 |
|---|---|---|---|
| 000 | 工程搭建（scaffold） | [`000-scaffold/`](./000-scaffold/) | ✅ M0 完成（骨架）/ ⬜ M1 真实构建、M2 真机回程（同一需求线的里程碑，规划 §10） |

> 本仓为单模块工程（`settings.gradle.kts` 仅 include `:uv-cli`）。M1/M2 不另设模块编号，其任务与出口判据（G1–G4）见规划 §10；若未来拆分模块，自 `001` 起新建目录并在本表与 `SPECS_CHECKLIST.md` 登记。

---

## 五、快速导航

| 目标读者 | 推荐阅读顺序 |
|---|---|
| **新加入维护者** | [`docs/000-工程规划.md`](../docs/000-工程规划.md) → [constitution.md](./constitution.md) → [STRUCTURE.md](./STRUCTURE.md) → [overall-spec.md](./overall-spec.md) |
| **架构 / Tech Lead** | [ARCHITECTURE.md](./ARCHITECTURE.md) → [TECH.md](./TECH.md) → [overall-plan.md](./overall-plan.md) → 规划 §3.1（D1–D7）/ §4 / §9 |
| **M1 实现者** | 规划 §4（构建设计）→ [000-scaffold/plan.md](./000-scaffold/plan.md) §3/§4/§8 → [000-scaffold/spec.md](./000-scaffold/spec.md) → [overall-test-cases.md](./overall-test-cases.md) §2.2 |
| **消费方（App 开发者）** | [`../README.md`](../README.md) → [overall-spec.md](./overall-spec.md) §5（边界与环境契约）→ 规划 §7（注入表） |
| **测试 / QA** | [overall-test-cases.md](./overall-test-cases.md) → [000-scaffold/test-cases.md](./000-scaffold/test-cases.md) → [SPECS_CHECKLIST.md](./SPECS_CHECKLIST.md) §五 |
| **发布工程师** | [overall-plan.md](./overall-plan.md) §6 → [TECH.md](./TECH.md) §6.3 → 规划 §10.1 / §12 |

### 快照命令（先看证据，再看结论；均 ✅ 可跑）

```bash
gradle :uv-cli:tasks --console=plain                                # 配置期门禁（无 .so 必须过）
node tools/provision.mjs --check                                    # 未投放 ⇒ exit 2（预期语义）
node tools/provision.mjs --inspect <libuv_cli.so>                   # 打印某产物七门禁报告（不写文件）
node --check tools/provision.mjs && node --check scripts/fetch-uv-cli-source.mjs && bash -n scripts/build-uv-cli-android.sh   # 语法门
cat uv-cli.lock.json                                                # 唯一事实源（当前 draft）
```

---

**文档维护者：** `aosp-uv-cli` 维护团队 · **权威来源：** [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（v2.0）· **证据标记口径：** [constitution.md](./constitution.md) §三
