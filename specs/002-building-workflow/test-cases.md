# 002-building-workflow 测试用例

> 对应：[spec.md](./spec.md)（FR-002-xxx）· [plan.md](./plan.md)。
> 层：**L1b（工具纪律）/ L2（CI，本地以静态检查代行）**。环境：host（Git Bash + Node ≥18）+ 001 产出的真实制品。
> 前置：`build/out/libuv_cli.so` + `lock-writeback-inputs.json` 在位（001 已全链跑通）。
> 判据：可证伪；状态 ⬜ 执行后回填。

## A. lock 回写工具（正例 + 守卫负例矩阵）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 状态 |
|---|---|---|---|---|---|
| TC-002-01 | 语法门 | — | `node --check tools/lock-writeback.mjs` | exit 0 | ⬜ |
| TC-002-02 | 干跑校验 | 002-001 | `node tools/lock-writeback.mjs --inputs … --so … --check` | 打印将写入字段 diff；exit 0；lock 未变 | ⬜ |
| TC-002-03 | 正式回写 | 002-001/004 | 去掉 `--check` 执行（lock 副本上） | size/sha256/gates/toolchain/needed 落笔；`status=released`；`active.version`/`coordinates` 同步；`published=false`；JSON 合法 | ✅（2026-11-03 tag v0.13.6 Release 后正式落笔，CI 素材 + 本地制品复算一致） |
| TC-002-04 | released 单向守卫 | 002-002 | 对已 released 条目再次回写同素材 | exit 2；lock 不变 | ⬜ |
| TC-002-05 | 版本不匹配守卫 | 002-002 | 素材 version ≠ lock 条目 version | exit 2；提示版本差异 | ⬜ |
| TC-002-06 | 制品漂移守卫 | 002-003 | 素材 sha256 与目标 `.so` 复算不一致（改 1 字节） | exit 2；lock 不变 | ⬜ |
| TC-002-07 | 门禁前置守卫 | 002-006 | 用坏 ELF（如文本文件）当 `.so` | exit 2；lock 不变 | ⬜ |
| TC-002-08 | 幂等 | 002-005 | draft 态对同素材连续两次回写（先副本恢复 draft） | 二次 diff 为空；无重复 releases 条目 | ⬜ |
| TC-002-09 | 回写后硬比对 | 002-001 判据 | 回写后 `provision --inspect`（⑤⑥ 有锁值态） | ⑤⑥ 变硬比对且通过；整体 exit 0 | ⬜ |

## B. CI workflow（静态检查代行 L2）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 状态 |
|---|---|---|---|---|---|
| TC-002-10 | YAML 可解析 | — | `node -e` 或 python/yq 解析 workflow | 语法合法 | ⬜ |
| TC-002-11 | 装机钉版 | 002-010 | 人工核对步骤清单含 JDK21/Gradle9.4.1/Node20/NDK/rustup+target/cargo-ndk | 逐项在且钉版 | ⬜ |
| TC-002-12 | 流水顺序 | 002-011 | 核对步骤顺序 fetch→build→provision→归档→Release | 与规划 §9 一致；任一步失败即红（`if: always()` 不掩盖） | ⬜ |
| TC-002-13 | 退出码断言修复 | 002-012 | grep workflow 中 `code=$?` 口径；本地构造 exit 1 场景验证失败 | 未投放=2 判过；意外 1 判红（负例可区分） | ⬜ |
| TC-002-14 | tag 门 | 002-014/015 | 核对 Release 步骤仅 tag 触发；tag↔lock active 校验存在 | 非 tag 路径无 Release 步骤 | ⬜ |
| TC-002-15 | 配置期门禁保留 | 002-020/021 | 干净检出跑 `gradle :uv-cli:tasks` + 语法门（含新脚本） | 全绿；语法门覆盖 lock-writeback 与 003 harness | ⬜ |
| TC-002-16 | 归档清单 | 002-013 | 本地按同口径组包后核对清单 | libuv_cli.so + 双 METADATA + LICENSES + .sha256 逐项在 | ⬜ |

## C. 执行记录（回填区）

- 环境快照：⬜（host/Node/时间；CI 真实 runner ⬜ 首轮 tag 后回填）。
- 结果汇总：⬜（PASS x / FAIL x / SKIP x）。
- CI 真实执行（L2 端到端）⬜：属 T11，tag `v<uvver>` 首推后回填本文件与规划 §9。
