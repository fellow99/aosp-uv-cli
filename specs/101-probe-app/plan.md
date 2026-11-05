# 101-probe-app — 模块计划（plan.md，as-built 逆向）

> **模块**：101-probe-app · **性质**：技术实现文档（specs-as-built：逆向记录 probe-app 实际实现 + 101 补充探针）。
> **依据**：[`../constitution.md`](../constitution.md)（P1–P8）· [`../../docs/000-工程规划.md`](../../docs/000-工程规划.md)（规划 §）·
> 本模块 [`spec.md`](./spec.md)（FR-101-probe-xxx）· 003-cli [`plan.md`](../003-cli/plan.md) §1.5 / 003-cli §10（shell 域 harness 对照）。
> 修复设计：node-bridge-workspace `docs/20261105-cli-实测问题-修复设计.md`（§2.2/§4.2/§4.3/§5）。
> **标记**：✅ 已实现/实测 · ⬜ 规划/未实测 · ⚠️ 注意。**版本**：v1.0 · 2026-11-05 · 状态：✅ as-built。

---

## 1. 技术上下文

### 1.1 工程形态（as-built ✅，文件树与真实行数，2026-11-05 快照）

```
probe-app/                        # 独立 Gradle 工程（不进主仓 settings.gradle——000 单模块红线）
├── settings.gradle.kts           # rootProject=uv-cli-probe-app；include(":app")；pluginManagement google/mavenCentral
├── build.gradle.kts              # AGP 9.2.1（apply false）
├── gradle.properties             # org.gradle.jvmargs=-Xmx2g；android.useAndroidX=false
├── local.properties              # sdk.dir=C:/Users/Administrator/AppData/Local/Android/Sdk（.gitignore 不入库）
├── app/
│   ├── build.gradle.kts          # namespace org.fellow99.uvprobe；compileSdk36/minSdk24/targetSdk35
│   │                             #   abiFilters=arm64-v8a；packaging.jniLibs.useLegacyPackaging=true（D1）
│   │                             #   implementation(files("libs/uv-cli-release.aar"))
│   ├── libs/uv-cli-release.aar   # 16,133,475 B（2026-11-03 14:00；.gitignore 不入库，P3）
│   └── src/main/AndroidManifest.xml  # extractNativeLibs="true"（D1）；LAUNCHER intent；exported=true
│       └── java/org/fellow99/uvprobe/MainActivity.java   # 416 行（本批 271 → 416）
```

### 1.2 MainActivity 结构映射（as-built ✅，path:line）

| 段 | 行号 | 说明 | 覆盖 FR |
|---|---|---|---|
| 类注释（职责 1–5） | :22–33 | exec / 注入 / 判据 / 自动执行 / 101 补充探针 TC-UV-30~35 | — |
| `onCreate` | :41–70 | nativeDir/uvExe/filesDir 初始化；UI（Button+ScrollView+TextView）；启动即 `runAll()` | 007 |
| `log` | :72–77 | UI 同步日志（runOnUiThread） | 007 |
| `exec(cmd, envOverride)` | :80–117 | ProcessBuilder：`PATH=nativeDir:/system/bin`、`HOME=<filesDir>/home`、`TMPDIR=<filesDir>/tmp`、`UV_CACHE_DIR=<filesDir>/uv/cache`、`UV_HTTP_TIMEOUT=30`（SSL_CERT_FILE 永不注入 D4）；60s 超时 → destroyForcibly；rc∈{-1,-2,实际} | 003/004/016 |
| `read` | :119–124 | stdout/stderr 双线程读 | 003 |
| `record` / `recordStatus` / `recordFact` | :127–151 | 三态 verdict PASS/FAIL/FACT；`{id,title,verdict,exit,ms,stdout,stderr,detail}`；stdout/stderr 300 字符截断 | 006 |
| `trim` | :153–158 | 报告字段清洗 | 006 |
| `sniffSelfConsistentInterp` | :163–187 | 探测自洽 prefix（HOME/.pyruntime、filesDir/.pyruntime、filesDir/pyruntime、intent `probe_uv_python`），要求 `<p>/bin/python`+`<p>/pyvenv.cfg` 在场 | 012 |
| `runAll`（TC-003-20~27） | :188–277 | 既有 App 域 8 条（判据见 003 test-cases §E2）——**未改动断言逻辑** | 005 |
| `runAll`（TC-UV-30~35） | :279–375 | 101 新增边界事实探针（判据见本 plan §3 / test-cases §E） | 010~015 |
| `writeReport` | :384–401 | JSON 落盘 `filesDir/probe-report-app.json`；汇总 PASS/FAIL/FACT 计数 | 006 |
| `list` | :407–412 | argv 拼装助手 | — |

### 1.3 env 契约注入表（规划 §7 的 App 域实例化；代码 :88–92/94）

| 变量 | 值 | 说明 |
|---|---|---|
| `PATH` | `<nativeDir>:/system/bin` | uv 直呼 + 系统工具；Symlink 农场由 harness（shell 域）承担，App 域无需 |
| `HOME` / `TMPDIR` | `<filesDir>/home` / `<filesDir>/tmp` | 落 filesDir（FR-101-probe-004） |
| `UV_CACHE_DIR` | `<filesDir>/uv/cache` | P5：`uv cache dir` = 注入值 |
| `UV_HTTP_TIMEOUT` | 30 | 网络用例防挂 |
| `SSL_CERT_FILE` | 永不注入 | D4（rustls 内嵌根证书） |

### 1.4 与 003-cli / shell 域 harness 的关系

- 003-cli 交付 shell 域 harness：`scripts/test-on-device/run-probes.sh`（**host 侧执行器**，adb 驱动）+
  `env-contract.sh`（env 单一事实源）`probe-lib.sh`（run_case 三值）+ 用例 TC-003-00~17；
- 本模块是 **App 域**载体（消费方真实形态）：shell 域覆盖不到的「untrusted_app SELinux 域 exec、nativeLibraryDir 落盘、
  filesDir 注入、启动即自动执行」在此验证；两者判据互补，探针 ID 同族（TC-003-20~27 / TC-UV-30~35）。
- `probe-app` 依赖 `uv-cli-release.aar`（本仓 `tools/provision.mjs --out` 投放 + `assembleRelease` 产出，见 001/002）。

---

## 2. 构建与运行（as-built ✅ 2026-11-05 实测）

- 构建：`probe-app` 用项目自带发行版 **Gradle 9.4.1**（`/d/Java/gradle-9.4.1`）：
  `gradle :app:assembleDebug --console=plain` → **BUILD SUCCESSFUL**（本批追加探针后二次重编 4 tasks executed，exit 0，36s）。
- 产物：`probe-app/app/build/outputs/apk/debug/app-debug.apk`（17,995,930 B，sha256 c52e62a4…c29c75）。
- 运行载体：`emulator-5554`（sdk_gphone64_x86_64 API 37 × ndk_translation，App 域 ABI=arm64）——`adb install -r` 成功、
  `am start` 自动执行、`run-as org.fellow99.uvprobe cat files/probe-report-app.json` 回读合法 JSON。
- ⚠️ 真机 `cd3fac61`（Mi MIX，arm64-v8a/API 26）安装被 `INSTALL_FAILED_USER_RESTRICTED` 拒（MIUI 用户侧限制）——未在其上跑；
  实际验证载体为 ndk_translation App 域（与 003 §E2 先例一致）。
- 报告归档：`logs/20261105-1/probe-report-app.json`（本批）+ `logs/20261105-1/DEV_CHECKLIST.md`。

## 3. 补充探针清单与判据（FR 交叉引用；代码 :279–375）

| ID | 判据 | 期望（FACT=事实捕获 / PASS=成功 / FAIL=不符） | FR |
|---|---|---|---|
| TC-UV-30 | `uv --version` 行为事实 | exit=0 且 `uv…` 回程 ⇒ FACT；否则 FAIL | 010 |
| TC-UV-31 | `uv venv <filesDir>/uvpv/.v` 解释器检索行为 | exit≠0 且含 interpreter/python 语义词 ⇒ FACT；rc=0 ⇒ FAIL（矛盾）；detail 含实测文案（匹配 `Failed to inspect Python interpreter` 或 `No interpreter found …`） | 011 |
| TC-UV-32 | 自洽 prefix + `UV_PYTHON` venv 单次成功 | 命中自洽 prefix ⇒ `UV_PYTHON=… uv venv` 成功= PASS / 失败= FAIL；未命中 ⇒ FACT（致环境引导层） | 012 |
| TC-UV-33 | `uv pip install six`（纯 py 域） | rc≠0 且含 environment/interpreter/python/network/timeout ⇒ FACT；rc=0 ⇒ FAIL（复核） | 013 |
| TC-UV-34 | `uv pip install fastapi`（C/Rust 扩展，E1） | rc≠0 且（E1 文案：pydantic-core/maturin/linux-android/no matching distribution/wheel ⇒ FACT；被前置拦截 ⇒ FACT 并明示）；rc=0 ⇒ FAIL | 014 |
| TC-UV-35 | `uv python install 3.12`（C2/D7） | rc≠0 且 No download found/unsupported ⇒ FACT；rc=0 ⇒ FAIL（红线矛盾） | 015 |

- 三态语义：`FACT`（PASS-FACT）= “已捕获确定性事实，detail 承载明确判定/原因”，不算 FAIL；仅“与预期矛盾”才 FAIL。
- 已实测结论：**PASS=8（TC-003-20~27）· FACT=6（TC-UV-30~35）· FAIL=0**（logs/20261105-1/probe-report-app.json）。
- 关键事实回读（2026-11-05，emulator-5554 ndk_translation App 域）：
  - TC-UV-31：`error: No interpreter found in managed installations or search path`（exit=2）——PATH 无 python 时 uv 的隔离式检索结论；
    `Failed to inspect Python interpreter …` 文案对应“检索到不自洽解释器”场景（修复设计 §2.2），本载体 PATH 无 python 故取前者，如实记录。
  - TC-UV-32：App 裸域无 `.pyruntime`（HOME 下无自洽 prefix）→ 边界事实；单次成功验证需环境引导层注入。
  - TC-UV-33/34：`error: No virtual environment found; run 'uv venv' …`（exit=2）——无解释器/环境前置拦截，E1 轮子选择文案不可达于裸域。
  - TC-UV-35：`No download found for request: cpython-3.12-linux-aarch64-none`（exit=2）——上游无 android managed python。

## 4. FR 交叉引用（spec ↔ 实现 ↔ 状态）

| FR | 实现落点 | 状态 |
|---|---|---|
| FR-101-probe-001 | probe-app 工程文件（§1.1） | ✅ |
| FR-101-probe-002 | app/build.gradle.kts `useLegacyPackaging` + manifest `extractNativeLibs` | ✅（TC-003-20） |
| FR-101-probe-003 | MainActivity.exec :80–117 | ✅（TC-003-21） |
| FR-101-probe-004 | exec env 注入 :88–94 | ✅（TC-003-22） |
| FR-101-probe-005 | runAll TC-003-20~27 :188–277（未改） | ✅（8/8 PASS 回归） |
| FR-101-probe-006 | recordStatus/writeReport :137–151/:384–401 | ✅ |
| FR-101-probe-007 | onCreate runAll :69/:188 | ✅ |
| FR-101-probe-010 | :284–292 | ✅ FACT |
| FR-101-probe-011 | :294–302 | ✅ FACT |
| FR-101-probe-012 | sniffSelfConsistentInterp :163–187 + :304–333 | ✅ FACT（裸域边界） |
| FR-101-probe-013 | :335–350 | ✅ FACT |
| FR-101-probe-014 | :352–367 | ✅ FACT（前置拦截） |
| FR-101-probe-015 | :369–375 | ✅ FACT |
| FR-101-probe-016 | 全探针限 filesDir / 无下载 | ✅ |
| FR-101-probe-017 | 构建 + 模拟器实跑 | ✅（emulator-5554） |

## 5. 测试考虑（呼应 [test-cases.md](./test-cases.md)）

- 既有族（TC-003-20~27）判据不变，作为回归基线（spec.md FR-101-probe-005）；
- 新增族（TC-UV-30~35）以“FACT 捕获为准”；E1/单次成功类探针在自洽 prefix + 网络在场时可升级为真值验证；
- 报告字段与 shell 域 `probe-report-device.json` 同口径（id/title/verdict/exit/ms/stdout），App 域多 stderr 字段。

## 6. 遗留记录

| # | 事项 | 出口 |
|---|---|---|
| 1 | 编号 101 未注册于规划 §10.2（P8 先注册再建目录） | 编排者/后续批次补登记 |
| 2 | TC-UV-32/34 真值验证（全成功 + E1 轮子文案）需 python-cli 自洽 prefix + 设备网络 | 环境引导层（修复设计 §4.2）就绪后复核 |
| 3 | 真机（Mi MIX）未实跑（MIUI INSTALL_FAILED_USER_RESTRICTED） | 真机解锁 USB 安装后补跑 |
