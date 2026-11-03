# TEST_REPORT — 20261103-1（测试阶段执行报告）

> 依据 [TEST_CHECKLIST.md](./TEST_CHECKLIST.md)。执行时间：2026-11-03。
> **结论：三域全绿——host 15/15 ✅，CI 端到端全步 ✅（run 41574193742），设备 PASS=6/FAIL=0/SKIP=11。**
> 无 FAIL 缺陷；SKIP 项均带可复核归因（载体域/网络/前置产物），列为本仓已登记的待验事实（非阻塞）。

## 一、结果总览

| 域 | 用例数 | 通过 | 失败 | SKIP/不可达（带归因） |
|---|---|---|---|---|
| host（L1a/L1b，000/001/002 静态门+fetch 负例） | 15 | 15 | 0 | — |
| CI（L2 端到端，ubuntu-24.04） | 12 步 | 12 | 0 | Release 步按 P5 正确跳过（非 tag） |
| 设备（L3，TC-003-00~17） | 18+1 | 6 PASS | 0 | 11 SKIP + 4 INFO（快照/采样/形态记录） |

## 二、CI 端到端证据（run 41574193742 · commit 6788d0a）

| 步骤 | 结论 | 关键证据 |
|---|---|---|
| resolve version | ✅ | tag↔lock 一致性校验接线（tag 触发路径） |
| fetch | ✅ | uv 0.13.6 tarball sha256 门过 |
| build | ✅ | **C 依赖探针通过**（aws-lc-sys 0.44 / zstd-sys / blake3 / jemalloc 全编过）；`cargo build --release --locked` Finished 13m31s；strip → `libuv_cli.so` 34,979,336 B；**provision 七门禁全 ✔**（①②③④⑤⑥⑦） |
| 归档 | ✅ | `uv-cli-v0.13.6-android-arm64-v8a.tar.gz` + `.sha256` + LICENSES + cargo 许可清单（cargo metadata 生成） |
| lock 回写干跑 | ✅ | lock-writeback 守卫矩阵过（素材↔制品复算一致） |
| artifact / Release | ✅ / ⏭️ | artifact 上传成功；非 tag 不发布（FR-002-015） |

产物硬事实（回填 lock 素材）：
- DT_NEEDED = `["libdl.so","libm.so","libc.so"]` —— **不含 libc++_shared.so**（静态链命中 ⇒ 规划 §4.4 的"替代方案已命中"，消费方无需 LD_LIBRARY_PATH 注入该库；D5 事实更新）
- 16KB 页对齐：min LOAD align = 0x4000 ✅；exec 型 PIE + PT_INTERP=/system/bin/linker64 ✅（执行型 profile 与规划 §6 全对齐）
- rust 1.99.0（uv rust-toolchain.toml 钉定）· NDK 28.2.13676358 · Cargo.lock sha256 968afc76…8d0a

## 三、设备探针证据（emulator-5554 · ndk_translation 域）

PASS（可证伪判定全过）：
- TC-003-00 部署自检；**TC-003-01 P1 版本回程**（`uv 0.13.6 (aarch64-linux-android)`，exit 0，arm64 制品在 x86_64 翻译层真实执行）；TC-003-02 帮助直出；**TC-003-03 P5 cache 注入**（输出逐字符等于 `UV_CACHE_DIR`）；TC-003-10 **`uv python install` 禁用事实化**（`No download found for cpython-3.12-linux-aarch64-none`——上游无 android managed python，C2/D7 产品层成立）；TC-003-16 **XDG 兜底**（`<XDG_CACHE_HOME>/uv` 形态——规划 §7 表待定项落定）

SKIP（11，全部带归因，判据不可达≠不达标）：
- 网络×6（07/08/09/11/13/15：模拟器 NAT 经宿主直连 pypi 不可达——宿主需代理）；载体域×1（01b：ndk_translation 对 PATH 名字查找 exec 报 linker realpath 错）；缺 python-cli×2（05/14）；非 16KB×1（17）；静态链无需反证×1（12b）

INFO 记录（4）：00b 环境快照；04 退出码采样（--bogus-flag=2、未知子命令=2，clap 口径符合预期）；06 venv --python 3.12 失败形态（`No interpreter found for Python 3.12`，exit 2）；12a LD_LIBRARY_PATH 去注入直呼成功（静态链佐证）

## 三.5、App 域探针证据（probe-app，2026-11-03 补测；FR-003-050~055 / TC-003-20~27）

**8/8 全 PASS**（报告 probe-report-app.json，commit 3a81fbe APK + e460b92 归档）：
- **D1 有效性核验 ✅（本批最关键新增判据）**：libuv_cli.so 经 useLegacyPackaging 物理落盘
  /data/app/…/lib/arm64（nativeLibraryDir），在 untrusted_app SELinux 域 exec 回程
  uv 0.13.6 (aarch64-linux-android)——消费方真实形态的可执行性成立（adb shell 域覆盖不到的判据）；
- P5 filesDir 注入精确生效：cache dir = <filesDir>/uv/cache（逐字符比对过）；
- C2/D7 红线在 App 域同样成立：No download found for cpython-3.12-linux-aarch64-none；
- XDG/退出码/help 与 shell 域结论完全一致（契约跨域一致性 ✅）；
- 载体注记：arm64 AVD 本机不可启动（emulator 37.2.12 FATAL：x86_64 宿主 QEMU2 不支持 arm64 镜像），
  App 域 arm64 执行由 ndk_translation 域承载；真机域复跑仍为待验项（不影响本轮 App 域结论）。

## 四、已知限制与待验项（不阻塞本里程碑）

| # | 事项 | 归因 | 出口 |
|---|---|---|---|
| 1 | rustls 内嵌根证书 HTTPS（P3/R6） | 模拟器网络不可达 | 真机/有网环境跑 TC-003-07/13 |
| 2 | P2 venv 落盘 + venv 内 python 形态 | 设备无解释器（python-cli 产物不在场） | 组合域（python-cli + uv 同机） |
| 3 | P4 UV_PYTHON 组合链路 | 同上 | 同上 |
| 4 | farm（PATH symlink/copy）通路 | ndk_translation 域 PATH-exec 受限（实测记录） | 真机域 TC-003-01b |
| 5 | TC-002-03 正式回写（released 落笔） | 按 P2 纪律随首个真实 tag Release 走 | tag v0.13.6 push 时执行 |

## 五、缺陷记录

**无 FAIL 缺陷**。测试过程中发现并已修复的 harness/工程缺陷（过程记录，均已入库）：
- fetch 网络抖动抛丑栈 → 3 次重试 + 干净报错（fetch 重构 commit）
- CI：`cargo metadata --no-deps=false` 非法 flag；cargo tree 无 license 输出；libgcc shim 相对路径；SRC/OUT 相对路径在 cd 后失效；归档缺 FETCH-METADATA（5 次 CI 迭代修复，见 git log fix(ci)/fix(build) 系列）
- harness：MSYS 路径转换吞设备路径；双层 sh -c 引号互吃；mksh 前缀赋值不传入命令替换；JSONL sed 拼接非法 JSON（1af521a）
