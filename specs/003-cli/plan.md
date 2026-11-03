# 003-cli — 模块计划（plan.md，planned → 开发后回写 as-built）

> **模块**：003-cli CLI 运行期验证 · **性质**：技术实现计划（实现落地后回写 as-built 与行号）。
> **依据**：[`../constitution.md`](../constitution.md)（P1–P8）· [`../../docs/000-工程规划.md`](../../docs/000-工程规划.md)（下称「规划 §」）· 本模块 [`spec.md`](./spec.md)（FR-003-xxx）。
> **标记**：✅实测 / ⬜未实测 / ⚠️风险。**版本**：v1.0 · 2026-11-03 · 状态：⬜ 未实现。

---

## 1. 技术上下文

### 1.1 设备策略（as-built ✅ 2026-11-03 环境盘点）

| 优先级 | 载体 | 说明 |
|---|---|---|
| 1 | 真机（arm64-v8a） | `adb devices` 有真机即用；页大小如实记录（FR-003-043） |
| 2 | x86_64 模拟器（含 ARM 翻译） | 本机已有 `Medium_Phone_API_37.0`（API 37，google_apis，4K 页）在线；arm64 产物经 ndk_translation 运行（python-cli 先例：arm64 libpython_cli.so 在同款镜像 PASS） |
| 3 | arm64 AVD | `python_arm64_api35`（API 35 arm64-v8a google_apis）真 arm 镜像兜底（慢） |

- 选用规则：`scripts/test-on-device/run-probes.sh --device <serial>` 自动探测；结论中**必须**记录
  载体形态（真机/翻译/arm64 AVD）——翻译层结论标注「ndk_translation 域」⚠️ 与真机域区分（P6）。

### 1.2 工具形态（沿 000 工具族：零第三方依赖 Node + bash）

```
scripts/test-on-device/
├── run-probes.sh        # 主入口：部署→农场→env→逐用例→报告（host 侧驱动 adb）
├── probe-lib.sh         # shell 函数库：run_case（编号/timeout/exit/耗时/stdout 采集）
└── env-contract.sh      # env 契约注入表（单一事实源，FR-003-003）
```

- 设备工作目录：`/data/local/tmp/uv-probe/`（`bin/`、`home/`、`tmp/`、`cache/`、`ws/<TC-ID>/`）；
- host 侧产物：`logs/<date>-N/probe-report-device.json`（结构化，python-cli probe-app 同款字段口径）。

### 1.3 env 契约注入表（规划 §7 的 shell 域实例化；单一事实源 `env-contract.sh`）

| 变量 | 值（shell 域实例化） | 说明 |
|---|---|---|
| `PATH` | `<work>/bin:/system/bin` | 农场直呼（FR-003-032） |
| `HOME` | `<work>/home` | FR-003-030 |
| `TMPDIR` | `<work>/tmp` | Android 无 /tmp |
| `UV_CACHE_DIR` | `<work>/cache` | FR-003-012（P5） |
| `XDG_CACHE_HOME` | `<work>/xdg-cache` | FR-003-031（仅在专项用例注入） |
| `LD_LIBRARY_PATH` | `<work>/lib`（若 DT_NEEDED 含 libc++_shared.so，则把 python-cli/node-runtime 的 libc++_shared.so 投到此目录） | FR-003-033（P6 双向） |
| `UV_PYTHON` | 仅 TC-003-14 注入（python-cli 物化解释器路径） | FR-003-034（P4） |
| `SSL_CERT_FILE` | **永不注入**（D4）；反证用例临时注入 `/nonexistent` 后**清除** | FR-003-041 |
| `UV_HTTP_TIMEOUT` | 30（网络用例防挂） | 防御性 |

## 1.5 probe-app 设计（App 域探针载体，FR-003-050~055；2026-11-03 新增）

镜像 aosp-python-cli/probe-app 形态（已验证可构建/可装/可跑）：

| 项 | 取值 | 说明 |
|---|---|---|
| 工程形态 | `probe-app/` 独立 Gradle 工程（AGP 9.2.1；不进主仓 settings.gradle——000 单模块红线不动） | 依赖 `app/libs/uv-cli-release.aar`（本仓 `provision --out` 投放后 `assembleRelease` 产出） |
| 打包 | `useLegacyPackaging=true` + manifest `extractNativeLibs=true`（D1）：`libuv_cli.so` 物理落盘 `nativeLibraryDir` | abiFilters 仅 arm64-v8a；x86_64 模拟器经 ndk_translation 可装可跑（python probe 先例） |
| 探针执行 | `onCreate` 起后台线程自动全量运行（FR-003-055）；UI monospace 日志同步 | 无交互依赖，`am start` 即可 |
| env 注入 | `UV_CACHE_DIR=<filesDir>/uv/cache` / `HOME=<filesDir>/home` / `TMPDIR=<filesDir>/tmp` / `PATH=<nativeDir>:/system/bin`（规划 §7 App 域实例化） | ProcessBuilder environment() |
| 报告 | 逐条 {id,title,verdict,exit,ms,stdout,detail} → `filesDir/probe-report-app.json`（FR-003-054） | `adb shell cat` 回读 |
| 用例 | TC-003-20~27（见 test-cases.md §E2） | App 域可证伪子集；PTY/网络族不在 App 域重复 |

## 2. 用例执行框架（FR-003-004/005）

- `run_case <ID> <title> <timeout_s> -- <cmd…>`：设备侧 `cd ws/<ID> && env… $cmd`，采集
  exit/stdout/stderr/耗时 → 汇总 JSON（host 落盘）；
- SKIP 语义：网络不可达 / python-cli 产物不可得 / 设备无 16KB 页 ⇒ SKIP + 原因（不算 FAIL）；
- 破坏性用例（TC-003-12 LD_LIBRARY_PATH 反证）在子 env 内执行，不污染全局注入；
- 安全纪律：全部路径限 `/data/local/tmp/uv-probe/`；不 touch 系统分区（FR-003-005）；
- 网络用例源：PyPI 官方（`packaging` 纯 wheel；sdist 用例选仅有 sdist 的老包如 `samples`/`an example` ⬜ 实测钉选）。

## 3. P1–P6 探针映射（规划 §7.1 ↔ 本模块用例）

| 探针 | 用例 | 说明 |
|---|---|---|
| P1 版本回程 | TC-003-01 | `--version` |
| P2 venv | TC-003-05 | `venv` + pyvenv.cfg + venv 内 python 形态记录 |
| P3 HTTPS 安装 | TC-003-07 | rustls 内嵌根证书生效（D4/R6） |
| P4 组合（python-cli） | TC-003-14 | `UV_PYTHON` + `uv venv` + `uv run python` |
| P5 cache 注入 | TC-003-03 | `cache dir` = 注入值 |
| P6 DT_NEEDED/LD_LIBRARY_PATH | TC-003-12 | 双向反证（或静态链记录性） |

## 4. FR 交叉引用

| FR | 实现落点（计划） | 现状 |
|---|---|---|
| FR-003-001/002 | run-probes.sh 部署段 + bin/uv 农场 | ⬜ |
| FR-003-003 | env-contract.sh（§1.3 表） | ⬜ |
| FR-003-004/005 | probe-lib.sh run_case + 路径纪律 | ⬜ |
| FR-003-010~018 | 用例 B/C/D 组（test-cases.md） | ⬜ |
| FR-003-030~034 | 用例 E 组（env 契约逐项） | ⬜ |
| FR-003-040~044 | 用例 F 组（TLS/限制事实化/快照） | ⬜ |

## 5. 测试考虑（呼应 [test-cases.md](./test-cases.md)）

- 主用例全集 TC-003-00~17（用户口径：**该 CLI 的主要测试用例**）；
- 每条独立工作区 `ws/<ID>/`（互不污染）；网络用例超时保护；
- 执行后回填 test-cases.md 状态列 + JSON 报告归档 logs 目录。

## 6. 待定项

| # | 事项 | 出口 |
|---|---|---|
| 1 | sdist-only 样本包钉选（老包名实测） | 用例 TC-003-09 实测后钉 |
| 2 | venv 内 `bin/python` 形态（symlink 可用性） | TC-003-05 记录 ⬜ → 事实 |
| 3 | UV_PYTHON 指向形（路径 vs 目录） | TC-003-14 记录 ⬜ → 事实（回写规划 §7 表） |
| 4 | ndk_translation 域 vs 真机域结论差异 | 报告标注；有真机则双域对照 |
