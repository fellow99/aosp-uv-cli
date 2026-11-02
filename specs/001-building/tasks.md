# 001-building 任务拆解

> 对应：[spec.md](./spec.md)（FR-001-xxx）· [plan.md](./plan.md)。原则：先取源可复现，先探针后全量，实产后回写。

- [ ] T1 fetch 实现：PINS 单输入定稿（uv 版本 + 官方 tarball URL + sha256 一手实测）+ 下载/校验/解压/幂等 + FETCH-METADATA.json（FR-001-001~004、006；M1-T2）
- [ ] T2 Cargo.lock 整文件 sha256 记录 + 取侧版本表进 FETCH-METADATA（FR-001-005；M1-T2）
- [ ] T3 rust 工具链装配：rustup stable 钉版 + `rustup target add aarch64-linux-android` + cargo-ndk（回退 config.toml）（FR-001-010/011；M1-T3）
- [ ] T4 NDK 接线 + cc 环境（CC/AR/CXX_aarch64_linux_android）+ RUSTFLAGS 16KB（FR-001-012/013；M1-T3）
- [ ] T5 C 依赖可编性探针：uv 依赖树首轮 `cargo build --target --locked` 试编；ring/zstd-sys/aws-lc-rs 逐个结论；降级拍板回写规划 §4.3（FR-001-020/021，R1/R2；M1-T1）
- [ ] T6 全量 `cargo ndk -t arm64-v8a --platform 24 build --release --locked`（FR-001-022/024/025；M1-T3）
- [ ] T7 DT_NEEDED 实测清单（readelf/provision 输出）记录（FR-001-023；M1-T4）
- [ ] T8 strip + 改名 `libuv_cli.so` + 体积实测回填（FR-001-030/031/026→R3；M1-T4）
- [ ] T9 BUILD-METADATA.txt 落盘（rust/target/api/NDK/flags/uv 版本/Cargo.lock sha256）（FR-001-032/014；M1-T4）
- [ ] T10 `provision --inspect` 七门禁自检 + `--out` 投放 jniLibs（FR-001-033/034；M1-T4）
- [ ] T11 lock 回写素材 JSON 生成（size/sha256/DT_NEEDED/toolchain 结构化值）（FR-001-035）
- [ ] T12 本机全链跑通 + 用例执行（TC-001-*）+ 结论回写 plan.md（⬜→✅）与规划 §4（C8）
