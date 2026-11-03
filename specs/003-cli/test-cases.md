SKIP（4K 页） |✅ |SKIP（网络） |SKIP（缺 python-cli） |SKIP（网络） |✅（12a INFO；12b 记录性） |SKIP（网络） |✅ |SKIP（网络） |SKIP（网络） |SKIP（网络） |✅（INFO 失败形态） |SKIP（缺解释器） |✅（INFO） |✅ |✅ |✅（直呼域） |✅ |✅ |# 003-cli 测试用例（CLI 主用例全集）

> 对应：[spec.md](./spec.md)（FR-003-xxx）· [plan.md](./plan.md)（harness 与执行框架）。
> 层：**L3**（设备端，adb shell 域）。设备：arm64 真机 / 含 ARM 翻译的 x86_64 模拟器 / arm64 AVD（载体形态必须入报告）。
> 前置（全局）：001 已构建（`build/out/libuv_cli.so`）且 `provision --inspect` 七门禁 ①②③④⑦ 过；harness 已部署（bin/农场/env 就绪）。
> 约定：`$UV` = 设备工作目录 `bin/uv`（农场 symlink）；每用例在 `ws/<ID>/` 独立工作区执行；env 前缀 = plan §1.3 注入表。
> 判据纪律：可证伪（PASS/FAIL 二元出口）；网络不可达 / 前置产物不可得 ⇒ SKIP（记录原因，不算 FAIL）；状态 ⬜ 执行后回填。

## A. 探针环境自检（部署正确性）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 探针映射 | 状态 |
|---|---|---|---|---|---|---|
| TC-003-00 | 部署自检 | 003-001/002/003 | `ls -l` 工作目录（libuv_cli.so 可执行位）；`ls bin/`（uv symlink）；`echo $UV_CACHE_DIR/$HOME/$TMPDIR` env 抽查 | 物理件 + symlink 就位；env 逐项有值且落工作目录 | — | ✅ |
| TC-003-00b | 环境快照 | 003-044 | `uname -m`；`getprop ro.product.cpu.abi ro.build.version.sdk`；`getconf PAGESIZE`；`getenforce`；`ls -Z libuv_cli.so`；sha256sum 制品 | 记录 ABI/API/页大小/SELinux/文件标签/制品哈希 + 载体形态（真机/ndk_translation/arm64 AVD） | P 前置 | ✅ |

## B. 版本与基础命令（P1 等价）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 探针映射 | 状态 |
|---|---|---|---|---|---|---|
| TC-003-01 | 版本回程 | 003-010 | `$UV --version`；直呼二进制 `<work>/libuv_cli.so --version` | 两法均输出 `uv <PIN 版本>`（= CLI_VERSION）；exit 0 | **P1** | ✅（直呼域） |
| TC-003-02 | 帮助直出 | 003-011 | `$UV help`；`$UV pip --help` | 直出完成不挂起（无 tty 依赖）；exit 0 | P1 旁证 | ✅ |
| TC-003-03 | cache dir 注入 | 003-012 | `$UV cache dir`；`ls -d $UV_CACHE_DIR` | 输出**逐字符等于**注入值；目录自动创建 | **P5** | ✅ |
| TC-003-04 | 退出码采样 | 003-018 | `$UV --bogus-flag`（用法错）；`$UV no-such-command` | 记录实际 exit 值（uv 口径预期 2 级）；不挂起 | 记录性 | ✅（INFO） |

## C. venv 与 pip 闭环（P2/P3 前置；env 契约内嵌验证）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 探针映射 | 状态 |
|---|---|---|---|---|---|---|
| TC-003-05 | venv 创建 | 003-013/030 | `$UV venv ws/TC-003-05/venv`；`cat venv/pyvenv.cfg`；`ls -l venv/bin/` | venv 落 ws；`pyvenv.cfg` 存在；exit 0；**venv 内 python 形态（symlink 指向/缺失）如实记录** | **P2** | SKIP（缺解释器） |
| TC-003-06 | venv 指定解释器失败形态 | 003-017 | 不注入 `UV_PYTHON`：`$UV venv --python 3.12 ws/…/venv2`（无 managed python） | 失败形态记录（找不到解释器语义）；不挂起不下载 | §7 限制 1 | ✅（INFO 形态） |
| TC-003-07 | pip install 纯 wheel（HTTPS） | 003-014/040 | `$UV venv ws/…/v3`（或用 05 的）→ `$UV pip install --python v3/bin/python packaging`（默认 env，**无** SSL_CERT_*） | exit 0；`v3/lib/python*/site-packages/packaging*` 在；dist-info 在 | **P3**（rustls 内嵌根证书） | SKIP（网络） |
| TC-003-08 | pip list / uninstall 闭环 | 003-015 | `$UV pip list --python v3/bin/python` → `uninstall packaging` → 再 list | list 含 packaging；卸后不含；各步 exit 0 | P3 扩展 | SKIP（网络） |
| TC-003-09 | sdist 拒收事实化 | 003-016 | `$UV pip install --python v3/bin/python <仅 sdist 的老包>`（钉选见 plan §6-1） | 失败 exit ≠ 0；错误含 sdist/构建语义（设备无编译器） | §7 限制 2 | SKIP（网络） |
| TC-003-10 | `uv python install` 禁用 | 003-017 | `timeout 60 $UV python install 3.12` | 失败形态记录（无下载能力/找不到 managed python）；**绝不静默成功**；网络侧无产物 | §7 限制 1（C2/D7 红线） | ✅ |
| TC-003-11 | cache 增量核验 | 003-012/014 | TC-003-07 后 `du -s $UV_CACHE_DIR`；再装一次同包（命中缓存） | 缓存目录有 uv 产物结构（wheels-v*/等）；二次安装显著加速 | P5 行为级 | SKIP（网络） |

## D. TLS 与动态链接反证

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 探针映射 | 状态 |
|---|---|---|---|---|---|---|
| TC-003-12 | LD_LIBRARY_PATH 双向反证 | 003-033 | ① 去掉 `LD_LIBRARY_PATH` 跑 `$UV --version`；② 注入含 `libc++_shared.so` 的目录再跑（若 DT_NEEDED 实测含该库） | ①失败（linker 报缺库）②成功 ⇒ P6 核验；若 DT_NEEDED 实测**不含** ⇒ ①②均成功，本条记「静态链命中」并回写规划 §4.4 | **P6** | ✅（12a INFO；12b 记录性） |
| TC-003-13 | SSL_CERT_FILE 反证 | 003-041 | `SSL_CERT_FILE=/nonexistent.pem $UV pip install …`（重跑 TC-003-07 口径） | 仍成功 ⇒ uv/rustls 不读该 env（D4 佐证）；失败 ⇒ env 优先，回写规划 §7 | R6/D4 | SKIP（网络） |

## E. 组合与限制事实化（规划 §7 已知限制）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 探针映射 | 状态 |
|---|---|---|---|---|---|---|
| TC-003-14 | UV_PYTHON 组合（python-cli） | 003-034 | 注入 `UV_PYTHON=<python-cli 物化解释器>` → `uv venv v4` → `uv pip install --python v4/bin/python six` → `uv run --python v4 python -c "import six;print(six.__version__)"`（在 venv 目录） | 组合链路回程成功；解释器指向形记录；python-cli 产物不可得 ⇒ SKIP | **P4**（对齐 python-cli P5） | SKIP（缺 python-cli） |
| TC-003-15 | git 依赖源限制 | 003-042 | `timeout 60 $UV pip install git+https://github.com/…`（无 git 二进制） | 失败 exit ≠ 0；错误语义记录；不挂起 | §7 限制 3 | SKIP（网络） |
| TC-003-16 | XDG 兜底 | 003-031 | 子 env：去 `UV_CACHE_DIR`、设 `XDG_CACHE_HOME=<work>/xdg` → `$UV cache dir` | 输出 = XDG 注入值（或其 uv 子目录，形态如实记录） | §7 表 | ✅ |
| TC-003-17 | 16KB 页采样 | 003-043 | 若 TC-003-00b 页大小=16384：复跑 01/05/07/12 核心链 | 16KB 设备核心用例结论记录；否则 SKIP（页大小已记录） | 规划 §4.1 16KB 行 | SKIP（4K 页） |

## E2. App 域探针（probe-app，消费方形态；FR-003-050~055；TC-003-20~27）

> 载体：probe-app APK（uv-cli AAR 依赖，useLegacyPackaging=true ⇒ libuv_cli.so 落 nativeLibraryDir）。
> 验证的是 adb shell 域无法覆盖的**消费方真实形态**：untrusted_app SELinux 域 exec（D1 有效性）、filesDir 注入。
> 启动即自动执行，报告落 `filesDir/probe-report-app.json`，`adb shell cat` 回读。

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 状态 |
|---|---|---|---|---|---|
| TC-003-20 | App 域环境快照 | 050/054 | 读取 nativeDir/SELinux 域（id -Z）/文件标签（ls -Z）/filesDir 路径/制品 sha256 | 字段齐备入报告 | ⬜ |
| TC-003-21 | App 域版本回程（P1 等价） | 051 | exec `nativeDir/libuv_cli.so --version` | `uv 0.13.6 …` 回程；exit 0；SELinux 不拒（D1 有效性 ✅/❌） | ⬜ |
| TC-003-22 | filesDir 注入（P5 等价） | 052 | 注入 `UV_CACHE_DIR=<filesDir>/uv/cache` `HOME=<filesDir>/home` `TMPDIR=<filesDir>/tmp` → `uv cache dir` | 输出逐字符等于注入值；目录落 filesDir | ⬜ |
| TC-003-23 | venv 失败形态（App 域） | 053 参考 | 注入后 `uv venv <filesDir>/venvs/t1` | 失败形态记录（无解释器语义）；目录请求落 filesDir 域 | ⬜ |
| TC-003-24 | `uv python install` 禁用（C2/D7） | 053 | App 域执行 | 失败形态含 No download found；绝不静默成功 | ⬜ |
| TC-003-25 | XDG 兜底（App 域） | 052 | 去 UV_CACHE_DIR、设 `XDG_CACHE_HOME=<filesDir>/xdg` | 输出 = `<XDG>/uv` 形态 | ⬜ |
| TC-003-26 | 退出码采样（App 域） | — | `--bogus-flag`；`no-such-command` | exit=2 / exit=2（clap 口径） | ⬜ |
| TC-003-27 | help 直出（App 域） | 051 | `uv help` / `uv pip --help` | 直出完成不挂起；exit 0 | ⬜ |

## F. 执行记录（回填区，2026-11-03 实测回填）

- 设备快照：`sdk_gphone64_x86_64 emulator-5554` · **载体=ndk_translation**（host=x86_64；arm64 产物经翻译层运行）· API=37 · PAGESIZE=4096 · 制品 sha256=c6d9edfd…b1（host=device 一致）· 农场=copy(ok=0)
- 结果汇总：**PASS=6 / FAIL=0 / SKIP=11**（SKIP 全部带归因）——明细 logs/20261103-1/probe-report-device.json
- 事实记录：
  - DT_NEEDED=[libdl,libm,libc]（**不含 libc++_shared.so** ⇒ 静态链命中，P6 反证无需执行，回写规划 §4.4）
  - uv python install：上游无 android managed python 下载（`No download found for cpython-3.12-linux-aarch64-none`）——C2/D7 在产品层成立
  - XDG 形态：`<XDG_CACHE_HOME>/uv`（uv 加 uv 子目录）
  - 退出码：--bogus-flag=2、未知子命令=2（clap 口径，符合预期）
  - venv 无 UV_PYTHON：`No interpreter found`（exit=2，预期语义；P2 判据需 python-cli ⇒ SKIP）
- 载体域限制：ndk_translation 对 PATH 名字查找 exec 报 linker realpath 错（symlink/copy 皆然）⇒ farm 用例 SKIP；直呼绝对路径完全正常。真机域待验：farm 直呼、P2/P3/P4/P6。
- 网络域：模拟器 NAT 经宿主直连 pypi 不可达 ⇒ HTTPS 族 SKIP；rustls 根证书（R6）仍 ⬜ 待真机/有网验证。
