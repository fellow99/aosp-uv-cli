# 002-building-workflow 任务拆解

> 对应：[spec.md](./spec.md)（FR-002-xxx）· [plan.md](./plan.md）。原则：先回写闭环（防人工改错 lock），再换真实流水线（保配置期门禁不回归）。

- [ ] T1 `tools/lock-writeback.mjs` 实现：素材读取 + 制品复算比对 + 逐字段回写 + `--check` 干跑（FR-002-001/003；python-cli 同款先例）
- [ ] T2 回写字卫：status 单向 / 版本匹配 / 幂等 / 门禁自检前置（FR-002-002/005/006）
- [ ] T3 回写后 `provision --check` ⑤⑥ 变硬比对验证（draft→released 语义切换）（FR-002-001 判据）
- [ ] T4 workflow 重写：config-check 前置 job 保留 + build-android-arm64 真实 job（装机/fetch/build/门禁/归档）（FR-002-010/011）
- [ ] T5 退出码断言修复（`code=… || code=$?` 口径）+ 负例自证（FR-002-012）
- [ ] T6 归档清单实现（tar.gz + .sha256 + LICENSES + cargo 许可清单）（FR-002-013）
- [ ] T7 Release 触发门（tag-only + tag↔lock active 一致性校验）（FR-002-014/015）
- [ ] T8 缓存接线（rust/cargo registry + target；key= rustver+cargolock sha）（FR-002-016）
- [ ] T9 语法门扩展覆盖新脚本（lock-writeback / 003 harness）（FR-002-021）
- [ ] T10 用例执行（TC-002-*）+ workflow 静态检查清单
- [ ] T11 首轮真实 tag 构建后回填（CI 实测 ⬜ → ✅；规划 §9 缓存策略钉选）（C8）
