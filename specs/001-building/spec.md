# 001 · 构建（building）功能规格

> 模块：001-building · 状态：⬜ 规划已立项（规划 §10.2）· 所属工程：aosp-uv-cli
> 规划基线：[`docs/000-工程规划.md`](../../docs/000-工程规划.md) §4（构建设计）/§5（制品形态）/§8（lock）
> 覆盖任务：M1-T1（C 依赖可编性探针）/ M1-T2（fetch 完整实现）/ M1-T3（rust 工具链装配 + 编译）/ M1-T4（strip + 门禁）

## 1. 目的

把官方 uv 源码 tarball 变成**过 exec 门禁的 Android arm64 单文件制品**：`libuv_cli.so`
（exec 型 PIE，rustls 内嵌根证书，16KB 对齐，`--locked` 可复现）。全流程**不改源、出处钉选、
依赖树锁定**（Cargo.lock sha256 记录），并完成 C 依赖（ring/zstd-sys/…）在 NDK 下的
可编性探针与降级拍板（规划 §4.3）。

## 2. 功能需求（FR-001-xxx，RFC 2119；判据可证伪）

### 2.1 源钉选与获取（fetch，M1-T2）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-001-001 | MUST | uv 源单输入钉版：官方 release tarball 的 URL 模板 + 版本 + SHA-256 内置于 fetch 脚本钉选表（PINS） | PINS 字段齐全；改任一字节 ⇒ 校验失败（exit 2） |
| FR-001-002 | MUST | 下载只走官方出处，不改源（P1）：解压后源码树与官方包逐字节一致（无补丁/无 fork；交叉参数经 cargo 配置/RUSTFLAGS 注入） | fetch 后对源码树抽查文件 sha256 与官方包一致；仓库与 `.dist/` 无补丁文件 |
| FR-001-003 | MUST | fetch 幂等：已就位且哈希正确的输入跳过下载；损坏/缺文件自动重下 | 二次执行不重新下载（有跳过日志）；构造损坏文件 ⇒ 自动修复 |
| FR-001-004 | MUST | 输出布局固定：`.dist/src/uv/`（源码树，含 `Cargo.lock`），可整目录删除重建 | 删除 `.dist/src` 后重跑，布局一致 |
| FR-001-005 | MUST | 取侧元数据落盘：tarball sha256、`Cargo.lock` 整文件 sha256、版本、URL 记入 FETCH-METADATA.json（规划 §4.2 ⑦） | 文件存在且字段齐备；`Cargo.lock` sha256 复算一致 |
| FR-001-006 | MUST NOT | 不得引入钉选表之外的任何源码/镜像/预编译二进制（P7：上游无 Android 产物，一律源码自建） | 钉选表外的下载请求 ⇒ 拒绝（exit 2） |

### 2.2 工具链装配（M1-T3；rustup + cargo-ndk 主路线，规划 §4.1）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-001-010 | MUST | rustup stable 工具链可自动装配/检测：缺 rustup/cargo/target 时给出明确指引或自动安装（版本钉进 lock `builtFrom.toolchain.rustVersion`） | `rustc -vV` host 正常；target `aarch64-linux-android` std 就位；版本号进 BUILD-METADATA |
| FR-001-011 | MUST | cargo-ndk 装配（首选）；失败自动回退 `.cargo/config.toml` linker 直写路线（`aarch64-linux-android24-clang`），路线选择记录于构建日志（规划 §4.1「两路径等价」） | 日志含路线选择与回退原因（如有）；两路线产物等价过门禁 ⬜ 回写 |
| FR-001-012 | MUST | NDK 接线：`$NDK/toolchains/llvm/prebuilt/<host>/bin` 入 PATH；`CC/AR/CXX_aarch64_linux_android` 指向 `aarch64-linux-android24-clang`/`llvm-ar`/`clang++`（cc crate 编译入口） | 构建日志可见注入路径；ring/zstd-sys 等以 NDK clang 编译（无 host gcc 混入） |
| FR-001-013 | MUST | 16KB 页对齐：`RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"` 全链注入 | `provision --inspect` 门禁⑦过（min LOAD align ≥ 0x4000） |
| FR-001-014 | MUST | 可复现输入钉选：构建一律 `--locked`（禁依赖树漂移）；rust 版本/target/api/NDK/flags 记入 BUILD-METADATA（规划 §4.2 要点） | 构建命令含 `--locked`；METADATA 字段齐备 |
| FR-001-015 | SHOULD | 工具链装配可缓存复跑（CI：cargo registry + target 缓存） | 未变更输入时二次执行命中缓存（CI 日志） |

### 2.3 uv 交叉编译与 C 依赖探针（M1-T1/T3；规划 §4.2/§4.3）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-001-020 | MUST | C 依赖可编性探针（M1 首项）：uv 依赖树上 `cargo build --release --target aarch64-linux-android --locked` 直接试编；失败输出（汇编/链接错误）如实记录并回写规划 | 试编日志落盘；ring/zstd-sys 等逐个结论（通过/降级）回写规划 §4.3 |
| FR-001-021 | MUST | 降级路径显式（不静默）：crypto provider 切换（ring ↔ aws-lc-rs）或 uv feature 裁剪，任一降级**先回写规划再动实现**（P8），功能受限在 README/Release notes 如实上报 | 降级决策记录（规划 §4.3 回写 + 构建日志）；无未记录的降级 |
| FR-001-022 | MUST | 主产物为 exec 型 PIE 且 interp=`/system/bin/linker64`（不靠默认假设，以 ELF 事实为准） | `provision --inspect` 门禁①②③过 |
| FR-001-023 | MUST | 依赖白名单：DT_NEEDED ⊆ lock `matrix.allowedNeeded`（系统库 + `libc++_shared.so` 不随包，D5） | 门禁④过；DT_NEEDED 实测清单记录并回填 lock（规划 §6） |
| FR-001-024 | MUST | TLS = rustls 编译期内嵌根证书（D4），不依赖系统证书目录/`SSL_CERT_FILE` | 产物无证书目录探测（DT_NEEDED 无 libssl；行为核验 ⬜ 003-cli P3） |
| FR-001-025 | MUST | 构建可中断续跑（cargo target 目录复用；分阶段产物落盘） | 中断后重跑从既有进度继续（cargo 增量日志） |
| FR-001-026 | SHOULD | 体积实测回填（⬜ 预估 25–40MB 量级，R3；strip 后） | BUILD-METADATA 含 strip 前后 size；超标处置先改规划 |

### 2.4 产物整理（M1-T4）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-001-030 | MUST | strip：`llvm-strip --strip-unneeded`（NDK 自带） | strip 前后体积对比记录于 BUILD-METADATA |
| FR-001-031 | MUST | 命名映射：`target/aarch64-linux-android/release/uv` → `libuv_cli.so`（D6：Android 只认 `lib*.so`；禁区 `libuv.so`/无 `_cli` 后缀） | 产物文件名恰为 `libuv_cli.so`；provision DEFAULT_BINARY 对上 |
| FR-001-032 | MUST | BUILD-METADATA.txt / FETCH-METADATA.json 落盘（rust 版本/target/api/NDK/flags/uv 版本/Cargo.lock sha256；镜像 pty/python-cli 归档形态） | 两文件存在且字段齐备 |
| FR-001-033 | MUST | 全门禁自检：strip 后产物 `provision --inspect` 七门禁逐项 ✔（draft 态 ⑤⑥ 仅记录） | 七门禁报告落盘；①②③④⑦ 全 ✔ |
| FR-001-034 | MUST | 产出投放就绪：`provision --out` 投放 jniLibs + `META-INF/uv-cli.properties`（复用 000 能力，无扩展） | `--out` exit 0；jniLibs 仅 `libuv_cli.so`；properties 字段齐备 |
| FR-001-035 | MUST | lock 回写素材生成（真实 size/sha256/DT_NEEDED/toolchain 结构化字段值），供 002 回写闭环使用（P2：本模块只产数据，不直接改 lock 语义） | 素材 JSON 落盘且与产物复算一致 |

## 3. 边界（不在本模块）

- CI 流水线/Release/lock released 回写 → **002-building-workflow**；
- 产物在设备上的行为验证（探针/用例）→ **003-cli**；
- managed python 下载（`uv python install`）— C2/D7 红线，永不在范围（规划 §1.3）。

## 4. 验收场景

- 干净环境（空 `.dist/`）一条 fetch + 一条 build 命令产出：`libuv_cli.so` + 双 METADATA，
  `provision --inspect` 七门禁 ①②③④⑦ 全过（⑤⑥ draft 仅记录）；
- tarball 被篡改 1 字节 ⇒ fetch exit 2，绝不进入构建；
- 重复执行 fetch/build 幂等（缓存命中、产物一致）；
- C 依赖试编失败 ⇒ 降级路径先回写规划（P8）再实现，无静默降级。
