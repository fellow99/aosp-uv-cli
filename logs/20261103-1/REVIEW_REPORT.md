# REVIEW_REPORT — 20261103-1（代码评审阶段报告）

> 评审方式：requesting-code-review（code-reviewer 子代理，只读评审）
> 范围：`68d56e3..HEAD`（specs 立项 + 001/002/003 实现 + CI/harness）
> 基准：specs/001~003 FR 判据 + constitution P1–P8
> 评审结论：**无 Critical**；Important×7、Minor×11；overall = needs-fixes ⇒ 已按 receiving-code-review 纪律逐条核实并处置

## 一、Important 处置（7/7 已修）

| # | 评审发现（文件:行） | 核实 | 修复 | 验证 |
|---|---|---|---|---|
| 1 | lock-writeback 幂等早退死代码（FR-002-005 名不副实） | ✅ 属实（守卫④先 die，`before===after` 永不可达） | 重构：字段应用移到克隆（draft）上计算，released 判定在赋值 status 之前；released+一致 ⇒ no-op 放行 | T2/T3：回写 exit 0 → 同素材再跑 exit 0（幂等） |
| 2 | needed/toolchain 等出处字段无实物复算（伪造面） | ✅ 属实 | 新增守卫②b：素材 needed 与 provision `--inspect` ELF 实解析比对，漂移即 exit 2 | T4：伪造 libEVIL.so ⇒ exit 2（`needed 漂移：素材 ≠ ELF 实解析`） |
| 3 | released 后同 tag 重跑 CI 必红（干跑门禁 vs 回写拒绝冲突） | ✅ 属实（由 #1 派生） | 幂等放行（#1 修复）即解除：released+一致干跑 exit 0 | T3 同源验证 |
| 4 | workflow `UV_VERSION` 死变量 = 第二版本源（P2） | ✅ 属实（全文零引用） | 删除，注释明示「版本唯一事实源 = lock active」 | grep = 0 |
| 5 | harness `expect=fail` 把任意非零退出判 PASS（假阳性污染 P7 红线证据） | ✅ 属实（评审聚焦项命中） | run_case：rc=127 判环境错 FAIL；新增第 6 参 fail_pat（-E 断言失败原因语义）；TC-003-09/10/15 传入预期文案 | 复跑：TC-003-10 PASS 且 stdout 含 `No download found for cpython-3.12-linux-aarch64-none`（真实策略拒绝，非 exec 失败） |
| 6 | Windows 双环境 cc/linker 用 POSIX sh 包装脚本不可 spawn | ✅ 属实（本地构建曾断于此） | `pick`/`pickexe`：MSYS 下 cc/linker 选 `.cmd`、bin 工具选 `.exe`；CI(linux) 走原名 | bash -n + CI config-check 语法门 |
| 7 | lock 回写素材不进 artifact ⇒ 人工回写闭环断裂 | ✅ 属实 | artifact path 补 `lock-writeback-inputs.json` + `gates-report.txt` | workflow 静态检查；下轮 CI 生效 |

## 二、Minor 处置（8 修 / 3 记录不修）

已修：M1 build 注释残缺；M2 flags 元数据补 `-L native=<shim>`（可复现输入入 METADATA）；M4 FETCH-METADATA version 与 `--uv` 错配校验；M5 fetch HTTP 非 2xx 进重试；M6 spec 布局判据统一为 `uv-src`；M7 JSON.parse/releases 守卫（exit 1 纪律化）；M8 设备侧 sha256 与 host 强比对（不一致即中止）；M9/M10-adjacent 手拼 JSON 全部废除 → **TSV 中转 + node 统一构造**（转义陷阱根治）；M11 可执行位判据 `cut -c1-10` 精确化。

不修（记录理由）：
- M3 strip 前体积在续跑场景可能失真——sha/size 正确，lock 不受影响；cargo 增量语义固有，记录为已知边界；
- M10 build job 持 `contents: write` 于非 tag 触发——发布卫生已由步骤条件（FR-002-015）保证；最小权限拆独立 release job 属流水线重构，归 M4 跟随机制评估；
- M6' probe-lib `snapshot` 命名与注释 snapshot_case 漂移——重写时已顺带统一。

## 三、处置过程中的回归防护

修复过程中 harness 曾两度引入回归（fail_pat 参数错位致 prefix 被 export 覆盖 → TC-003-10 exit 127；TSV 迁移中 skip_case/合并段损坏），均在复跑中暴露并即时修复；**最终复跑 PASS=6 / FAIL=0 / SKIP=11 维持全绿**（含新断言的 TC-003-10 真实 PASS），JSON 报告由 TSV 合并生成、合法可解析。

## 四、结论

评审 Important 全部闭环、Minor 8 修 3 记录；设备与 host 用例全绿维持；workflow 变更随下一轮 CI push 验证。**满足进入 Testing 收尾的门槛（no Critical / Important fixed）**。
