# 001-building 测试用例

> 对应：[spec.md](./spec.md)（FR-001-xxx）· [plan.md](./plan.md)。
> 层：**L1/L1.5**（host 侧；设备侧 → 003-cli）。环境：Windows host（Git Bash + Node ≥18）或 CI ubuntu-24.04。
> 前置：`uv-cli.lock.json` draft 在位；NDK 28.2 可寻。判据：可证伪（PASS/FAIL）；状态 ⬜ 执行后回填。

## A. fetch（源钉选与获取）

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 状态 |
|---|---|---|---|---|---|
| TC-001-01 | 语法门 | — | `node --check scripts/fetch-uv-cli-source.mjs` + `bash -n scripts/build-uv-cli-android.sh` | 全过 exit 0 | ⬜ |
| TC-001-02 | 首次取源 | 001-001/002/004 | `node scripts/fetch-uv-cli-source.mjs --uv <PIN> --out .dist` | `.dist/src/uv/` 存在 `Cargo.toml`/`Cargo.lock`；exit 0；FETCH-METADATA.json 字段齐备 | ⬜ |
| TC-001-03 | 幂等跳过 | 001-003 | 二次执行同命令 | 日志含跳过；不重新下载；exit 0 | ⬜ |
| TC-001-04 | 损坏自动修复 | 001-003 | 篡改缓存 tarball 1 字节后重跑 | 检测失配 ⇒ 重下 ⇒ exit 0 | ⬜ |
| TC-001-05 | 篡改拒绝 | 001-001/006 | 构造 sha256 不符场景（假 URL/假哈希注入） | exit 2；绝不解压进构建 | ⬜ |
| TC-001-06 | 未登记版本拒绝 | 001-006 | `--uv 0.0.0-notexist` | exit 2（或明确「未登记」错误），无下载发生 | ⬜ |
| TC-001-07 | Cargo.lock sha256 | 001-005 | 复算 `.dist/src/uv/Cargo.lock` sha256 对照 FETCH-METADATA | 一致 | ⬜ |

## B. 工具链与编译

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 状态 |
|---|---|---|---|---|---|
| TC-001-08 | rust 装配 | 001-010 | 按 plan §3.1 ② 装配后 `rustc -vV` / `rustup target list --installed` | host 与 `aarch64-linux-android` 就位；版本进日志 | ⬜ |
| TC-001-09 | cargo-ndk/回退路线 | 001-011 | 正常路径执行 build；临时禁用 cargo-ndk 再执行 | 两路线日志均记录选择；产物等价（sha256 可不同，门禁等价） | ⬜ |
| TC-001-10 | cc 环境注入 | 001-012 | 构建日志抽查 `CC_aarch64_linux_android` 等值 | 指向 NDK clang；无 host gcc 混入 | ⬜ |
| TC-001-11 | C 依赖探针 | 001-020/021 | 首轮 `cargo build --release --target --locked` | 通过 ⇒ 结论记录；失败 ⇒ 降级决策已回写规划后才允许裁剪 | ⬜ |
| TC-001-12 | `--locked` 纪律 | 001-014 | 构建命令行审查 | 含 `--locked`；无 `--update` 类漂移入口 | ⬜ |

## C. 产物整理与门禁

| # | 用例 | 覆盖 FR | 步骤 | 期望 | 状态 |
|---|---|---|---|---|---|
| TC-001-13 | strip + 命名 | 001-030/031 | 检查 `$OUT/libuv_cli.so` | 存在且恰为该名；BUILD-METADATA 含 strip 前后 size | ⬜ |
| TC-001-14 | 七门禁自检 | 001-022/023/024/013 | `node tools/provision.mjs --inspect $OUT/libuv_cli.so` | ①②③④⑦ 全 ✔（⑤⑥ draft 仅记录）；DT_NEEDED ⊆ 白名单 | ⬜ |
| TC-001-15 | 投放 | 001-034 | `node tools/provision.mjs --out uv-cli/src/main/jniLibs --from $OUT/libuv_cli.so` | exit 0；jniLibs 仅 `libuv_cli.so`；properties 生成 | ⬜ |
| TC-001-16 | 回写素材 | 001-035 | `lock-writeback-inputs.json` 存在性与复算 | size/sha256/DT_NEEDED/toolchain 与产物复算一致 | ⬜ |
| TC-001-17 | 体积记录 | 001-026 | 对照 BUILD-METADATA 与 `stat` | 体积值一致；若 >40MB ⇒ R3 处置记录（先改规划） | ⬜ |

## D. 执行记录（回填区）

- 环境快照：⬜（host/NDK/rust 版本/uv 版本/时间）。
- 首轮试编结论（TC-001-11 证据摘录与降级决策）：⬜。
- 结果汇总：⬜（PASS x / FAIL x；FAIL 明细在 devflow logs 目录 TEST_REPORT 展开）。
