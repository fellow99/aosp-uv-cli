# 003-cli 任务拆解

> 对应：[spec.md](./spec.md)（FR-003-xxx）· [plan.md](./plan.md)。原则：harness 先行（部署/农场/env/运行器），再逐族用例，结论回写事实。

- [ ] T1 `scripts/test-on-device/` 脚手架：run-probes.sh + probe-lib.sh + env-contract.sh（FR-003-001~003；语法门纳入 002 T9）
- [ ] T2 部署 + 农场 + env 注入自检用例（TC-003-00/00b）（FR-003-001/002/003/005）
- [ ] T3 版本/帮助/cache 用例（TC-003-01~04）（FR-003-010/011/012/018；P1/P5）
- [ ] T4 venv 用例（TC-003-05）+ venv 内 python 形态记录（FR-003-013；P2）
- [ ] T5 pip 装列卸闭环 + sdist 拒收 + python install 禁用事实化（TC-003-06~10）（FR-003-015/016/017）
- [ ] T6 TLS 用例：默认 env HTTPS + SSL_CERT_FILE 反证（TC-003-11/13）（FR-003-040/041；P3/R6）
- [ ] T7 LD_LIBRARY_PATH 双向反证（TC-003-12）（FR-003-033；P6，视 DT_NEEDED 实测）
- [ ] T8 组合探针 UV_PYTHON + uv run python（TC-003-14；python-cli 产物在场则跑，否则 SKIP）（FR-003-034；P4）
- [ ] T9 git 依赖源限制事实化（TC-003-15）（FR-003-042）
- [ ] T10 报告生成（JSON + Markdown 摘要 + 设备快照）+ test-cases.md 回填（FR-003-004/044）
- [ ] T11 probe-app 实现（FR-003-050~055）：独立 Gradle 工程 + AAR 依赖 + App 域探针 8 条（TC-003-20~27）+ 自动执行 + JSON 落盘
