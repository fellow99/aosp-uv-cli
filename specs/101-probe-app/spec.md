# 101 · App 域探针工程（probe-app）功能规格

> 模块：101-probe-app（工程搭建）· 状态：✅ 已实现（specs-as-built 逆向既有代码 + 补充边界探针）· 所属工程：aosp-uv-cli
> 规划基线：[`docs/000-工程规划.md`](../../docs/000-工程规划.md) §3（消费方环境引导层）/§7（环境变量契约 + 已知限制）；003-cli §2.5（FR-003-050~055）
> 修复设计（能力边界口径）：node-bridge-workspace `docs/20261105-cli-实测问题-修复设计.md`（下称「修复设计」）§2.2/§4.2/§4.3/§5
> 覆盖任务：003-cli T11（App 域探针载体 FR-003-050~055）+ 101 补充边界探针 TC-UV-30~35（工程搭建：规格化 + 能力披露 + 补充探针）
> 「工程搭建」属性说明：本模块无新工程源码骨架（probe-app 已在 003-cli 建成），本批作为独立规格模块逆向记录实现、补充能力边界披露与探针。

## 1. 目的

把 `probe-app/`（003-cli 的 App 域探针载体）作为**独立可归档模块**固定下来：逆向记录其实际实现
（MainActivity 结构、env 契约注入、报告形态），使**消费方真实形态**（untrusted_app SELinux 域 exec、
nativeLibraryDir 落盘 Phy、filesDir 注入）有可回溯的规格依据；并按修复设计 §4.3 落实**能力边界披露**
（uv 纯 py 域可用 / 含 C-Rust 扩展 ≈ 不可装 / sdist 不可设备编译 / 无编译器 / `uv python install` 不支持 /
解释器隔离模式检查依赖自洽 prefix），追加 6 条 TC-UV-* 边界事实探针。

**边界声明（防过度承诺）**：
- probe-app 验证的是 **App 域**的 uv 二进制本体行为（D1 落盘、app 域 SELinux exec、filesDir 注入、退出码）；
  组合链路（python-cli 自洽 prefix + `uv run`）的**一次成功验证**归属环境引导层（修复设计 §4.2/§5），本模块
  在自洽 prefix 在场时可验、缺席时如实记录边界事实（TC-UV-32）。
- E1 轮子选择文案（“无 android 轮子”）在 App 裸域被“无解释器/无环境”前置拦截时，按边界事实记录，
  不冒充轮子选择阶段结论（TC-UV-33/34）。
- 本模块不改 uv 本体；`uv venv` 的 pyvenv.cfg `home` 写死 realpath 属上游缺陷，自愈在环境层（修复设计 §2.2/§6）。

## 2. 功能需求（FR-101-probe-xxx，RFC 2119；判据可证伪）

### 2.1 探针载体工程（App 域，消费方形态）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-101-probe-001 | MUST | 载体为**独立** Gradle 工程（`probe-app/`，不进主仓 settings.gradle——000 单模块红线不动）：AGP 9.2.1、compileSdk 36、minSdk 24、targetSdk 35、仅 arm64-v8a abiFilters | `settings.gradle.kts` include `:app`；`app/build.gradle.kts` 版本/ABI 字段齐备；主仓 gradle 未纳入 | 
| FR-101-probe-002 | MUST | D1 exec 落盘：`useLegacyPackaging=true` + manifest `extractNativeLibs=true` ⇒ `libuv_cli.so` 物理落 `nativeLibraryDir` 且可执行位在 | APK 安装后 `ls -l natureLibraryDir/libuv_cli.so` 存在且 `-r-x`；`canExecute()==true`（TC-003-20） |
| FR-101-probe-003 | MUST | App 域 exec：`ProcessBuilder` 启动 `nativeLibraryDir/libuv_cli.so`，采集 exit/stdout/stderr/耗时；60s 超时保护 | TC-003-21 `--version` 回程 `uv 0.13.6 …` exit 0；`uv venv` 等不挂起（timeout 防护） |
| FR-101-probe-004 | MUST | env 契约注入（规划 §7 App 域实例化）：`PATH=<nativeDir>:/system/bin`、`HOME=<filesDir>/home`、`TMPDIR=<filesDir>/tmp`、`UV_CACHE_DIR=<filesDir>/uv/cache`、`UV_HTTP_TIMEOUT=30`；`SSL_CERT_FILE` **永不注入**（D4） | `uv cache dir` 输出逐字符 = 注入值（TC-003-22）；无 `SSL_CERT_*` 注入 |
| FR-101-probe-005 | MUST | 既有探针回归不破坏：TC-003-20~27 逐条 PASS/FAIL 且断言逻辑保持 | 本轮实测 8/8 仍 PASS（logs/20261105-1/probe-report-app.json） |
| FR-101-probe-006 | MUST | 结果结构化：逐条 `{id,title,verdict,exit,ms,stdout,stderr,detail}` → `filesDir/probe-report-app.json`，`adb` 可回读 | `run-as … cat files/probe-report-app.json` 为合法 JSON 且字段齐备 |
| FR-101-probe-007 | MUST | 自动执行：onCreate 起后台线程全量运行（无交互依赖），UI monospace 日志同步 | `am start` 后无需点击，报告自动落盘 |

### 2.2 能力边界事实探针（101 补充；依据修复设计 §2.2/§4.2/§4.3）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-101-probe-010 | MUST | `uv --version` 行为事实：记录 exit 与回程版本串 | TC-UV-30 记录 FACT：exit=0 且 `uv 0.13.6 (aarch64-linux-android)` |
| FR-101-probe-011 | MUST | `uv venv .v` 行为事实：捕获解释器检索失败文案（重点匹配 `Failed to inspect Python interpreter …`；实测可能为 `No interpreter found …`，如实记录）与 exit | TC-UV-31 记录 FACT：exit≠0，detail 含实际文案 |
| FR-101-probe-012 | MUST | 自洽 prefix 边界：探测 `<prefix>/bin/python` + `<prefix>/pyvenv.cfg`（候选 HOME/.pyruntime、filesDir/.pyruntime、filesDir/pyruntime；及 intent extra `probe_uv_python`）。命中 ⇒ `UV_PYTHON=<prefix>/bin/python uv venv` 单次成功验证（PASS/FAIL）；未命中 ⇒ 记为“依赖环境层自洽 prefix”边界事实 | TC-UV-32：命中自洽 prefix 时 exit=0 且 pyvenv.cfg 生成；未命中时 FACT 且 detail 明示归属环境引导层 |
| FR-101-probe-013 | MUST | `uv pip install <纯 py 包>`（`six`/本地轮子）边界事实：非静默失败或成功的 exit/stdout/err 如实记录 | TC-UV-33：失败则 exit≠0 且 detail 含实际文案；成功则记录 case（FACT 语义） |
| FR-101-probe-014 | MUST | 含 C/Rust 扩展包（`fastapi`→`pydantic-core`）E1 边界：期望按 E1 失败且文案含“无 android 轮子”类语义、**非静默**；App 裸域被“无 virtual environment/解释器”前置拦截时如实记录拦截事实 | TC-UV-34：rc≠0 且（命中 E1 文案 = FACT；被前置拦截 = FACT 并明示）≠0 时 FAIL |
| FR-101-probe-015 | MUST | `uv python install` 不支持事实：失败形态（`No download found`/`unsupported`）记录，**绝不静默成功**（C2/D7） | TC-UV-35：rc≠0 且 detail 含实际文案 |
| FR-101-probe-016 | MUST NOT | 探针不得越出 filesDir 域 / 写入系统分区；不得运行期下载可执行件（C2） | 全探针活动限于 filesDir；无网络安装成功路径依赖下载可执行件 |
| FR-101-probe-017 | SHOULD | 载体可在真实/模拟 App 域安装并自动执行，报告可回读 | `adb install -r` 成功；`am start` 后 `probe-report-app.json` 落盘（实测 emulator-5554 ndk_translation 域名） |

## 3. 实体

| 实体 | 位置 | 说明 |
|---|---|---|
| `libuv_cli.so` | `nativeLibraryDir`（`useLegacyPackaging` 物理落盘） | uv 命令本体（exec 型，arm64-v8a）；D1 落盘判据目标 |
| `uv-cli-release.aar` | `probe-app/app/libs/`（`.gitignore` 不入库） | 本仓 provision 投放 + assembleRelease 产物；AAR 依赖 |
| `probe-report-app.json` | `filesDir/` | 逐条三态 verdict 结构化报告，`adb run-as` 回读 |
| venv 目录 | `filesDir/uvpv/`（`.v`/`pv` 探针工作区） | TC-UV-31/32 venv 行为/成功验证目标 |
| 自洽 prefix | `filesDir/{home/.pyruntime, .pyruntime, pyruntime}` 或 `intent:probe_uv_python` | 修复设计 §4.2 C1 形态；TC-UV-32 探测对象 |
| env 契约 | exec 时 `ProcessBuilder.environment()` | 规划 §7 App 域实例化（PATH/HOME/TMPDIR/UV_CACHE_DIR + UV_HTTP_TIMEOUT） |

## 4. 用户故事

- 作为**消费方 App 开发者**，我想在 untrusted_app 域直接 `execve` 一个真实 `uv`（D1 物理落盘 + 目标文件标签放行），
  从而在终端里 `uv venv` / `uv pip`。
- 作为**发布/组合层维护者**，我想知道 uv 在设备上能力边界（哪些包装得动、哪些装不动、解释器怎么找），
  以便在 README 与 dsh 能力清单如实披露（修复设计 §4.3）。
- 作为**回归执行者**，我想一条命令（安装 + 启动）自动拿到全部 App 域判据（既有 8 条 + 边界 6 条）的 JSON 报告，
  而不依赖交互点击。

## 5. 验收场景

- 构建：`probe-app` 用项目自带发行版 **Gradle 9.4.1** 跑 `gradle :app:assembleDebug --console=plain` 通过，产出 APK。
- 安装运行：`adb install -r app-debug.apk` + `am start` 后自动全量执行；`run-as … cat files/probe-report-app.json` 回读。
- 判据齐备：报告含 **14 条**探针（既有 TC-003-20~27 全 PASS + 补充 TC-UV-30~35 各带 detail 事实）；FAIL=0 不强制
  （FACT 探针以“捕获到事实”为达标，非成败）。
- 能力披露：`README.md`/`README_zh.md` 的“能力边界/Capability boundary”小节与修复设计 §4.3 口径一致。
- 任一既有 MUST 探针（TC-003-20~27）FAIL ⇒ 本模块回归不达标；补充探针 FAIL ⇒ 判据与预期不符需复核。

## 6. 非功能需求

| 项 | 要求 |
|---|---|
| 性能 | 单命令 exec 60s 超时保护；全量 14 条实测约 35s（logs/20261105-1 报告 ms 汇总） |
| 可观测 | UI monospace 同步日志 + JSON 落盘 + `adb` 回读双通道 |
| 可维护 | 三态 verdict（PASS/FAIL/FACT）统一 `recordStatus` 出口；探针按族分节注释 |
| 安全 | 不越 filesDir、不写系统分区、不下载可执行件（C2/D7）；`SSL_CERT_FILE` 永不注入（D4） |
| 兼容 | minSdk 24（真机 API 26 可装）；仅 arm64-v8a（x86_64 模拟器 ndk_translation 域可装可跑） |

## 7. 依赖

- 本工程内：`uv-cli` AAR（`probe-app/app/libs/uv-cli-release.aar`，provision 投放）。
- 规格/组合契约：003-cli FR-003-050~055、规划 §7 env 契约、修复设计 §4.2（自洽 prefix）/§4.3（能力披露）/§5（验证口径）。
- 非本模块：python-cli 自洽解释器（`UV_PYTHON`）、设备编译器（无——E1 边界成立的前提）。

## 8. 遗留记录（非占位，属事实/后续批次）

- 编号 101 **未注册** 于规划 §10.2（P8「先注册再建目录」；本批不改规划文档，登记留给编排者/后续批次）。
- TC-UV-32/34 的“轮子/单次成功”方向验证需 python-cli 自洽 prefix + 网络；裸 App 域只记录边界事实——已在 §1 边界声明与 README 披露。
