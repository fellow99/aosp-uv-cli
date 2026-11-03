# 003 · CLI 运行期验证（cli）功能规格

> 模块：003-cli · 状态：⬜ 规划已立项（规划 §10.2）· 所属工程：aosp-uv-cli
> 规划基线：[`docs/000-工程规划.md`](../../docs/000-工程规划.md) §7（运行期契约：env 注入表 / 已知限制）/§7.1（回程探针 P1–P6）
> 覆盖任务：M2-T1（env 注入，shell 域等价）+ M2-T2（真机回程探针 P1–P6）

## 1. 目的

回答一个问题：**`libuv_cli.so` 在真实 Android（arm64）上，作为 uv 命令行到底能不能用、好用成什么样**。
以 adb shell 域（`/data/local/tmp` 可 exec）为本仓可执行的验证载体：部署制品、建 symlink 农场
（`$HOME/bin/uv → libuv_cli.so`）、注入 env 契约（规划 §7 表），逐用例验证 uv 行为并把结果
回写为**事实**（⬜ → ✅/❌）。

**边界声明（防过度承诺）**：adb 探针验证的是 **shell 域**的二进制本体行为；App 域结论
（nativeLibraryDir 落盘、targetSdk≥29 app 域 SELinux、PTY 交互、filesDir 注入）仍归消费方
（node-bridge 载荷 / python-cli 组合层）⬜。

## 2. 功能需求（FR-003-xxx，RFC 2119；判据可证伪）

### 2.1 探针环境（test harness，本仓交付）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-003-001 | MUST | 提供设备部署工具：推送 `libuv_cli.so` 到设备工作目录并设可执行位（幂等：重复部署结果一致） | 部署后设备目录清单与制品一致；`ls -l` 可执行位在 |
| FR-003-002 | MUST | 提供**农场创建器**：工作目录 `bin/uv → ../libuv_cli.so` 原名 symlink（幂等：先清后建） | `bin/uv` 经 PATH 直呼版本串回程（证明 symlink 通路） |
| FR-003-003 | MUST | 提供 **env 契约注入器**：按规划 §7 表生成 env（`PATH`/`LD_LIBRARY_PATH`/`UV_CACHE_DIR`/`XDG_CACHE_HOME`/`HOME`/`TMPDIR`；`UV_PYTHON` 仅组合探针注入；`SSL_CERT_FILE` **不注入**，D4） | `env` 级抽查：`uv cache dir` 输出 = `UV_CACHE_DIR` 注入值（P5）；HOME/TMPDIR 落工作目录非 /system |
| FR-003-004 | MUST | 用例可单跑（`--only TC-003-xx`）可全跑；每条输出结构化结果（编号/结论/exit/耗时/stdout 摘录） | 运行器产出逐用例 PASS/FAIL/SKIP 汇总 + JSON 报告落盘 |
| FR-003-005 | MUST NOT | 探针不得修改设备系统分区/全局配置；全部活动限制在 `/data/local/tmp` 工作目录 | 探针运行后无系统目录写入痕迹（只读系统） |

### 2.2 CLI 主行为（核心用例族；探针映射规划 §7.1）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-003-010 | MUST | `uv --version` 回程（P1 的 shell 域等价） | 输出 `uv <PIN 版本>`（与 CLI_VERSION 一致）；exit 0 |
| FR-003-011 | MUST | `uv help`/子命令帮助直出完成不挂起（无 tty 交互依赖） | 命令立即完成；exit 0 |
| FR-003-012 | MUST | `uv cache dir` 生效：输出 = `UV_CACHE_DIR` 注入值且目录自动创建（P5） | 输出逐字符等于注入值；目录落工作目录 |
| FR-003-013 | MUST | `uv venv <work>/venvs/t1`：venv 落注入 HOME 域、`pyvenv.cfg` 生成（P2） | venv 目录 + `pyvenv.cfg` 存在；exit 0；venv 内 `bin/python` 形态（symlink/缺失）如实记录 ⬜ |
| FR-003-014 | MUST | `uv pip install <纯 py wheel 包>`（如 `packaging`）进指定 venv（P3：HTTPS 生效 = rustls 内嵌根证书生效） | 安装 exit 0；site-packages 出现该包 + dist-info；缓存目录有增量 |
| FR-003-015 | MUST | `uv pip list` / `uv pip uninstall` 采样：装/列/卸闭环 | list 含已装包；uninstall 后 list 不含；exit 0 |
| FR-003-016 | MUST | `uv pip install` **sdist 拒收事实化**（设备无编译器）：安装仅含 sdist 源的旧版包 ⇒ 失败形态记录 | 失败 exit ≠ 0；错误语义记录（规划 §7 已知限制 2） |
| FR-003-017 | MUST | `uv python install` **禁用事实化**（C2/D7 红线）：执行 ⇒ 失败或不可得形态记录（设备无下载可执行能力） | 失败形态记录；`UV_PYTHON` 未注入时 uv 找不到解释器的错误形态记录 |
| FR-003-018 | SHOULD | 退出码契约采样：成功=0；用法错=2 级（uv 口径）；命令不存在=2 级（记录性，不设新契约） | 采样结果记录 |

### 2.3 环境契约逐项（规划 §7 表的可证伪化）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-003-030 | MUST | `HOME`/`TMPDIR` 生效：venv/缓存/临时文件不落 /system 或未注入路径 | 注入目录出现 uv 产物痕迹；`/system` 无写入 |
| FR-003-031 | MUST | `XDG_CACHE_HOME` 兜底生效：设 XDG 而不设 `UV_CACHE_DIR` 时缓存落 XDG 值 | `uv cache dir` 输出 = XDG 注入值 |
| FR-003-032 | MUST | `PATH` 农场直呼：`PATH=<work>/bin:$PATH uv --version` 裸命令名回程（symlink 农场通路） | 版本串回程 |
| FR-003-033 | MUST | `LD_LIBRARY_PATH` 反证（P6，仅当 DT_NEEDED 含 `libc++_shared.so` 时适用）：① 不注入 ⇒ 启动失败为预期（记录失败形态）；② 注入含 `libc++_shared.so` 的目录 ⇒ 回程成功 | 两向结论齐备 ⇒ §4.4 决策的事实核验；若 DT_NEEDED 实测不含该库 ⇒ 本条改记录性（“静态链命中”） |
| FR-003-034 | MUST | `UV_PYTHON` 组合探针（P4，对齐 python-cli P5）：注入 aosp-python-cli 物化解释器路径后 `uv venv` + `uv run python -c "print(…)"` | 组合链路回程成功；解释器指向形（路径 vs 目录）实测记录 ⬜；python-cli 产物不可得 ⇒ SKIP（如实记录） |

### 2.4 TLS 与已知限制事实化（规划 §7 已知限制 → 探针记录）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-003-040 | MUST | HTTPS 经 rustls 内嵌根证书（P3/D4/R6 核验）：默认 env（**无** `SSL_CERT_FILE`/`SSL_CERT_DIR`）下 `uv pip install`（HTTPS 源）成功 | 安装成功即证明内嵌根集生效；失败则 R6 成立，如实回写规划 |
| FR-003-041 | SHOULD | TLS 反证（记录性）：`SSL_CERT_FILE=/nonexistent` 注入后重跑安装——若仍成功 ⇒ uv/rustls 不读该 env（D4 佐证）；若失败 ⇒ 环境变量优先，回写规划 §7 表 | 两向 whichever 事实记录 |
| FR-003-042 | MUST | git 依赖源限制事实化：`uv pip install git+https://…` 在无 git 二进制下失败形态记录（属 aosp-git-cli 组合项 ⬜） | 失败 exit ≠ 0；错误语义记录（不挂起，timeout 保护） |
| FR-003-043 | SHOULD | 16KB 页设备采样（若测试设备 16KB）：核心用例复跑 | 设备 `getconf PAGESIZE` 记录；核心用例结论记录 |
| FR-003-044 | SHOULD | 环境快照固化：ABI/API/页大小/SELinux/设备型号/制品 sha256 入报告 | 报告字段齐备 |

### 2.5 App 域探针（probe-app，消费方形态；FR-003-050 族）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-003-050 | MUST | 提供探针 App（`probe-app/`，独立 Gradle 工程，镜像 aosp-python-cli/probe-app 形态）：依赖 `uv-cli` AAR，`useLegacyPackaging=true`（D1）使 `libuv_cli.so` 物理落盘 `nativeLibraryDir` | APK 安装后 `nativeLibraryDir` 内存在 `libuv_cli.so` 且可执行位在 |
| FR-003-051 | MUST | App 域 exec 探针：在 untrusted_app SELinux 域内 `ProcessBuilder` 启动 `nativeLibraryDir/libuv_cli.so`，采集 exit/stdout/stderr/耗时 | 版本串回程（P1 App 域等价）；app 域 exec 不被 SELinux 拒绝（D1 有效性核验） |
| FR-003-052 | MUST | filesDir 环境注入（规划 §7 表的 App 域实例化）：`UV_CACHE_DIR`/`HOME`/`TMPDIR` 指向 filesDir 子目录后执行 | `uv cache dir` 输出 = 注入值且目录落 filesDir（P5 App 域） |
| FR-003-053 | MUST | C2/D7 红线 App 域事实化：`uv python install` 在 App 域执行 | 失败形态记录（上游无 android managed python 下载），绝不静默成功 |
| FR-003-054 | MUST | 探针结果结构化：逐条 PASS/FAIL/SKIP + JSON 报告落盘 `filesDir/probe-report-app.json`，adb 可回读 | `adb shell cat` 回读 JSON 合法；含设备快照（SELinux 域/文件标签/nativeDir） |
| FR-003-055 | SHOULD | 探针自动执行：启动即后台线程全量运行（无交互依赖），UI 同步显示日志 | `am start` 后无需点击，报告自动落盘 |

## 3. 边界（不在本模块）

- 构建/门禁/CI → 001/002；
- App 域探针（APK 落盘、PTY 交互、filesDir 注入、node-bridge 组合）→ 消费方（M2 消费侧）⬜；
- Maven Central 发布 → M3；
- 性能基准 → 记录性采样（耗时入报告），不设门禁。

## 4. 验收场景

- 一台 arm64 Android（真机；或含 ARM 翻译的 x86_64 模拟器 / arm64 AVD）+ adb：部署 → 建农场 →
  注 env → 全量用例跑完出 JSON + Markdown 报告；
- 任一 MUST 用例 FAIL ⇒ 003 模块不达标，缺陷登记并回写规划（P8）；
- 全部结论（含 SKIP 及原因）在 test-cases.md 回填（含设备/页大小/时间等环境快照）。
