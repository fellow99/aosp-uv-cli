# 101-probe-app 任务拆解（as-built）

> 对应：[spec.md](./spec.md)（FR-101-probe-xxx）· [plan.md](./plan.md)。本批为规格化 + 能力披露 + 补充探针（既有工程已在 003-cli 建成）。

## 规格化（specs-as-built，逆向既有实现；本批完成）

- [x] T1 `specs/101-probe-app/spec.md`：技术无关 + FR-101-probe-001~017（RFC 2119）+ 实体 + 用户故事 + 验收场景 + NFR + 依赖 + 边界声明（FR-101-probe-005/006/007 落点）
- [x] T2 `specs/101-probe-app/plan.md`：probe-app 工程形态/行号映射/env 注入表/补充探针清单与判据/FR 交叉引用/构建运行实测/遗留
- [x] T3 `specs/101-probe-app/test-cases.md`：TC-003-20~27（既有）+ TC-UV-30~35（新增）判据与实测回填
- [x] T4 索引更新：specs/SPECS_CHECKLIST.md（新增 M-05 101-probe-app）、specs/README.md（模块目录/一览/导航）
- [ ] T5 规划 §10.2 登记编号 101（**本批未做**：不改规划文档；P8 登记留给编排者/后续批次）→ 已如实记录于 spec §8 / plan §6

## 能力边界披露（修复设计 §4.3）

- [x] T6 `README_zh.md` 新增“能力边界”小节（6 项边界：纯 py 可用 / C-Rust ≈ 不可装 / sdist 不可设备编译 / 无编译器 / `uv python install` 不支持 / 隔离模式检查依赖自洽 prefix）
- [x] T7 `README.md` 新增 “Capability boundary” 小节（同口径英文）

## 补充探针（MainActivity.java）

- [x] T8 三态 verdict 出口：`recordStatus`/`recordFact`（PASS/FAIL/FACT），`record` 委托不变（既有 TC-003 探针断言未改）
- [x] T9 `sniffSelfConsistentInterp`：自洽 prefix 探测（HOME/.pyruntime、filesDir/.pyruntime、filesDir/pyruntime、intent `probe_uv_python`）
- [x] T10 TC-UV-30（`uv --version` 事实）· TC-UV-31（`uv venv .v` 解释器检索文案）· TC-UV-32（自洽 prefix + UV_PYTHON）· TC-UV-33（纯 py 包边界）· TC-UV-34（C/Rust 扩展 E1 边界）· TC-UV-35（`uv python install` 不支持）
- [x] T11 `writeReport` 汇总计数扩展（PASS/FAIL/FACT 三态）

## 验证与归档（本批完成）

- [x] T12 构建：`probe-app` Gradle 9.4.1 `:app:assembleDebug` → BUILD SUCCESSFUL；产物 `probe-app/app/build/outputs/apk/debug/app-debug.apk`
- [x] T13 设备实跑（emulator-5554 ndk_translation App 域）：报告 14 条（PASS=8 / FACT=6 / FAIL=0）
- [x] T14 归档 `logs/20261105-1/DEV_CHECKLIST.md` + `probe-report-app.json`
