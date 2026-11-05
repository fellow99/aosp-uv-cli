# 101-probe-app 测试用例（App 域探针全集 + 101 补充边界探针）

> 对应：[spec.md](./spec.md)（FR-101-probe-xxx）· [plan.md](./plan.md)（结构/判据/实测）。
> 层：**L4（App 域）**；载体：probe-app APK（uv-cli AAR 依赖，`useLegacyPackaging=true`）。壳型：独立 Gradle 工程，Gradle 9.4.1 构建。
> 前置：`libuv_cli.so` 在 `nativeLibraryDir`（D1 落盘 + 可执行位）。
> 判据沿 003 §“可证伪”纪律：PASS/FAIL 二元 + FACT（PASS-FACT，事实捕获非成败）；网络/前置产物不可得 ⇒ 记录为边界事实（非 SEG）。

## E2. 既有 App 域探针（TC-003-20~27；reverse 自 003 test-cases §E2，断言未改动）

| # | 用例 | 覆盖 FR(003) | 步骤 | 期望 | 状态（本批） |
|---|---|---|---|---|---|
| TC-003-20 | App 域环境快照 + D1 落盘 | 050 | 读 nativeDir/SELinux 域/文件标签/filesDir/制品存在与可执行位 | 字段齐备入报告；`libuv_cli.so` 存在且 `canExecute()` | ✅ PASS |
| TC-003-21 | App 域版本回程（P1 等价） | 051 | exec `nativeDir/libuv_cli.so --version` | `uv 0.13.6 …` 回程；exit 0；SELinux 不拒 | ✅ PASS |
| TC-003-22 | filesDir 注入（P5 等价） | 052 | 注入 `UV_CACHE_DIR=<filesDir>/uv/cache` → `uv cache dir` | 输出逐字符 = 注入值 | ✅ PASS |
| TC-003-23 | venv 失败形态（App 域） | 053 参考 | 注入后 `uv venv <filesDir>/venvs/t1` | 失败形态记录（无解释器语义）；目录落 filesDir 域 | ✅ PASS |
| TC-003-24 | `uv python install` 禁用（C2/D7） | 053 | App 域执行 | 失败形态含 `No download found`；绝不静默成功 | ✅ PASS |
| TC-003-25 | XDG 兜底（App 域） | 052 | 去 UV_CACHE_DIR、设 XDG → `uv cache dir` | 输出 = `<XDG>/uv` 形态 | ✅ PASS |
| TC-003-26 | 退出码采样（App 域） | — | `--bogus-flag`；`no-such-command` | exit=2 / exit=2（clap 口径） | ✅ PASS |
| TC-003-27 | help 直出（App 域） | 051 | `uv help` | 直出完成不挂起；exit 0 | ✅ PASS |

## E. 101 补充边界探针（TC-UV-30~35；依据修复设计 §2.2/§4.2/§4.3）

| # | 用例 | 覆盖 FR | 步骤 | 期望判据 | 实测（2026-11-05，emulator-5554 ndk_translation App 域） | 状态 |
|---|---|---|---|---|---|---|
| TC-UV-30 | `uv --version` 行为事实（能力基线） | 010 | exec `uv --version` | 记录 exit + 版本串；exit=0 且 `uv …` ⇒ FACT | exit=0 · `uv 0.13.6 (aarch64-linux-android)` | ✅ FACT |
| TC-UV-31 | `uv venv .v` 解释器检索行为事实 | 011 | `uv venv <filesDir>/uvpv/.v` | 捕获解释器失败文案（`Failed to inspect Python interpreter …`/`No interpreter found …`）+ exit；exit≠0 且含 interpreter/python ⇒ FACT；rc=0 ⇒ FAIL | exit=2 · `error: No interpreter found in managed installations or search path`（PATH 无 python 故非 “Failed to inspect” 文案，如实记录） | ✅ FACT |
| TC-UV-32 | 自洽 prefix + `UV_PYTHON` venv 单次成功 | 012 | 探测 `<p>/bin/python`+`pyvenv.cfg`（含 intent `probe_uv_python`）；命中则 `UV_PYTHON=… uv venv` | 命中：exit=0 且 pyvenv.cfg 生成 = PASS，否则 FAIL；未命中：FACT（依赖环境层自洽 prefix） | HOME 下无 `.pyruntime` → FACT：边界事实，验证归属环境引导层（§4.2/§5-3） | ✅ FACT |
| TC-UV-33 | `uv pip install six`（纯 py 域）边界 | 013 | `uv pip install six`（默认 env） | rc≠0 且含 environment/interpreter/python/network/timeout ⇒ FACT；rc=0 ⇒ FAIL | exit=2 · `No virtual environment found; run 'uv venv' …`——无解释器/环境前置拦截（非静默） | ✅ FACT |
| TC-UV-34 | `uv pip install fastapi`（含 C/Rust 扩展）E1 边界 | 014 | `uv pip install fastapi`（默认 env） | rc≠0 且（E1 文案：pydantic-core/maturin/linux-android/no matching distribution/wheel ⇒ FACT；被前置拦截 ⇒ FACT 明示）；rc=0 ⇒ FAIL | exit=2 · `No virtual environment found; run 'uv venv' …`——E1 轮子选择被无环境前置拦截，需 UV_PYTHON+网络 到轮子选择阶段 | ✅ FACT |
| TC-UV-35 | `uv python install` 不支持（C2/D7） | 015 | `uv python install 3.12` | rc≠0 且 `No download found`/unsupported ⇒ FACT；rc=0 ⇒ FAIL（红线矛盾） | exit=2 · `No download found for request: cpython-3.12-linux-aarch64-none`（上游无 android managed python） | ✅ FACT |

> 注：TC-UV-33/34 在裸 App 域的实测失败形态为 **“无 virtual environment/解释器”前置拦截**，这正是能力边界披露的
> 事实（uv 需要解释器/环境才进入包解析；见修复设计 §4.3）。若注入自洽 prefix（intent `probe_uv_python`）+ 可联网，
> TC-UV-34 期望升级为 E1 文案（“无 android 轮子”），届时判据自动按 FACT 命中。

## F. 执行记录（2026-11-05 回填）

- 构建：`gradle :app:assembleDebug --console=plain`（Gradle 9.4.1）→ **BUILD SUCCESSFUL**（exit 0）。
- 载体：`emulator-5554`（sdk_gphone64_x86_64 API 37 × ndk_translation；App 域 ABI=arm64）；`adb install -r` 成功；`am start` 自动执行。
- 报告：`logs/20261105-1/probe-report-app.json`（App 侧 `filesDir/probe-report-app.json`，`run-as` 回读）。
- 汇总：**PASS=8（TC-003-20~27）· FACT=6（TC-UV-30~35）· FAIL=0**（14 条）。
- 遗留：真机 Mi MIX（cd3fac61，arm64-v8a/API 26）安装被 `INSTALL_FAILED_USER_RESTRICTED` 拒（MIUI 用户侧限制），真机域补跑待解锁后。

## 附、统一队列跑批记录（2026-11-06）

- 载体：`emulator-5554`（sdk_gphone64_x86_64 API 37 × ndk_translation；App 域 ABI=arm64）；由编排者统一排队串行执行（安装→`--ez autorun true`→`run-as cat` 回读报告）。
- 报告：`logs/20261105-1/report-uv.json`（工程内留档，不入库）。
- 汇总：14 探针：PASS 8 / FACT 6 / FAIL 0。
- 判读纪律：翻译模拟器结果**仅记录**，正式 G3 需原生 arm64 复测；FAIL/BLOCKED 均按本节/Spec 既有分类如实记录，未伪造 PASS。
