# 001-building — 模块计划（plan.md，planned → 开发后回写 as-built）

> **模块**：001-building 构建 · **性质**：技术实现计划（先写「怎么做」，实现落地后逐条回写 as-built 与行号）。
> **依据**：[`../constitution.md`](../constitution.md)（P1–P8 / S1–S10）· [`../../docs/000-工程规划.md`](../../docs/000-工程规划.md)（唯一规划基线，下称「规划 §」）· 本模块 [`spec.md`](./spec.md)（FR-001-xxx）。
> **标记**：✅实测 / ⬜未实测（规划）/ ⚠️风险。**本文构建参数在首轮试编前均为规划值（⬜），试编后回写。**
> **版本**：v1.0 · 2026-11-03 · 状态：⬜ 未实现（fetch/build 骨架接口已固化于 000-scaffold，exit 2 SCAFFOLD）。

---

## 1. 技术上下文

### 1.1 运行环境（本机 as-built ✅ 2026-11-03）

| 项 | 值 | 说明 |
|---|---|---|
| 宿主 | Windows x86_64 + Git Bash（CI 为 ubuntu-24.04，脚本双环境兼容） | bash + node 驱动（沿用 000 骨架口径） |
| NDK | **28.2.13676358**（r28 线），`$ANDROID_HOME/ndk/`；实际值回写 lock `builtFrom.ndk` | 与 aosp-node-runtime 对齐线（规划 §4.1） |
| 工具链 bin | `$NDK/toolchains/llvm/prebuilt/<host>/bin`：`aarch64-linux-android24-clang` / `llvm-ar` / `llvm-strip` | Windows host 目录名 `windows-x86_64` |
| rust | rustup stable + `rustup target add aarch64-linux-android`（官方 tier2，rustup 直装 std） | 本机当前**未装** ⚠️ 开工先装配；版本钉 `builtFrom.toolchain.rustVersion` |
| cargo-ndk | `cargo install cargo-ndk --locked`（或 CI 缓存二进制） | 主路线；备选 `.cargo/config.toml`（规划 §4.1） |
| host 工具 | node ≥18（fetch 下载/校验）、tar、sha256 | 无 perl/autoconf 依赖（Rust 线与 git 线的差异） |
| API / ABI | android-24 / arm64-v8a（lock `androidApi` ✅） | — |
| 版本钉选 | draft 0.9.0（规划 §2）；**开工时以官方最新稳定 uv 版本钉选并回写** `CLI_VERSION` 与 lock | PINS 见 §2.1 |

### 1.2 关键决策（沿规划 D1–D7，本模块相关）

| 决策 | 本模块落点 |
|---|---|
| D3 一律源码自建 | fetch 只取官方 tarball，无任何平台二进制（§2） |
| D4 rustls 内嵌根证书 | 不注入 `SSL_CERT_FILE`；TLS 行为随依赖树编译期定（§3.4） |
| D5 libc++_shared 不随包 | DT_NEEDED 实测记录；若实测不含则回写规划 §4.4（§3.5） |
| D6 命名 `libuv_cli.so` | strip 后改名（§3.3）；禁区 `libuv.so` |

---

## 2. fetch 脚本设计（`scripts/fetch-uv-cli-source.mjs`，M1-T2）

### 2.1 PINNED 钉选表（内置常量；定稿值以脚本为准，lock 同步）

```
PINS = {
  uv: { version: '<开工钉选>', url: 'https://github.com/astral-sh/uv/releases/download/<ver>/uv-<ver>.tar.gz',
        sha256: '<官方包一手实测>' },
}
```

- sha256 取值纪律：**官方发布包一手实测**（下载后计算并与官方 checksum/签名产物核对），绝不凭记忆填；
- `--uv <ver>` 覆盖 PINS.uv.version；版本不在表内 ⇒ exit 2（FR-001-006）；
- ⚠️ 若官方 release 资产名与模板不符（如仅有 GitHub 自动生成 `archive/refs/tags` 包），
  以**实测资产名**回写本表与规划 §4.1（P8），并保持「官方出处 + sha256 钉选」两纪律不变。

### 2.2 流程

```
① 缓存在（.dist/dl/uv-<ver>.tar.gz）且 sha256 匹配 → 跳过下载（FR-001-003）
② 下载（node 内置 fetch，官方 URL 直连）→ sha256 校验失败 ⇒ 删缓存 exit 2（FR-001-001）
③ 解压到 .dist/src/uv/（解压前清旧目录，幂等 FR-001-004）
④ 校验源码树存在性（Cargo.toml + Cargo.lock + crates/uv/Cargo.toml）
⑤ 计算 Cargo.lock 整文件 sha256 → FETCH-METADATA.json（版本/URL/tarball sha256/Cargo.lock sha256/取源时间）
```

---

## 3. build 脚本设计（`scripts/build-uv-cli-android.sh`，M1-T3/T4）

### 3.1 参数与环境（沿 000 骨架接口：`--uv/--api/--src/--ndk/--out`）

```
① env：NDK toolchain bin 入 PATH（clang/llvm-ar/llvm-strip 可寻，FR-001-012）
② rust 装配：rustup stable + target add aarch64-linux-android；
   cargo-ndk 存在检查 ⇒ 缺则提示安装（--locked）；回退路线：写 <src>/.cargo/config.toml
   [target.aarch64-linux-android] linker = "aarch64-linux-android24-clang"（FR-001-011，路线记录日志）
③ cc 环境：CC/AR/CXX_aarch64_linux_android（+ 大写 env 导出，cc crate 口径）
④ RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"（FR-001-013）
```

### 3.2 编译（主路线）

```
cargo ndk -t arm64-v8a --platform <api> build --release --locked --manifest-path <src>/Cargo.toml
（等价备选：cargo build --release --target aarch64-linux-android --locked + config.toml linker）
```

- `--locked` 纪律硬编码（FR-001-014）；可中断续跑 = cargo target 目录天然增量（FR-001-025）；
- 首轮试编即 C 依赖探针（FR-001-020）：失败时按规划 §4.3 降级路径处置（provider 切换 /
  feature 裁剪），**先回写规划再改脚本参数**（FR-001-021）。

### 3.3 整理与产出

```
⑤ strip：llvm-strip --strip-unneeded target/aarch64-linux-android/release/uv
⑥ 改名：→ $OUT/libuv_cli.so（D6）
⑦ 门禁自检：node tools/provision.mjs --inspect $OUT/libuv_cli.so（①②③④⑦ 必须全过）
⑧ BUILD-METADATA.txt（rust 版本/target/api/NDK/flags/uv 版本/Cargo.lock sha256/
   strip 前后 size/DT_NEEDED 实测清单）
⑨ lock 回写素材：build/out/lock-writeback-inputs.json（FR-001-035，供 002 消费）
```

### 3.4 TLS 栈口径（D4）

- 依赖树内 rustls + 编译期内嵌根证书；构建侧**不注入**任何 `SSL_CERT*` 环境变量；
- crypto provider（ring / aws-lc-rs）以 **Cargo.lock 实际清单为准** ⬜（规划 §4.1/R2）——
  探针阶段如实记录，若 aws-lc-rs 在树且试编失败 ⇒ 钉 provider=ring（feature 注入）并回写规划。

### 3.5 DT_NEEDED 实测（D5 事实核验）

- 首产以 provision `--inspect` 输出为准记录 NEEDED 清单（FR-001-023）；
- 若实测**不含** `libc++_shared.so`（静态链命中）⇒ 回写规划 §4.4 与 lock `matrix.allowedNeeded`
  说明（P8）；若含 ⇒ 运行期供给契约照旧（003-cli P6 验证）。

---

## 4. lock 扩展落地（规划 §8，M1 回写时按此口径）

```jsonc
"builtFrom": {
  "source": "uv <ver> source tarball (github.com/astral-sh/uv releases), unmodified",
  "toolchain": { "rustVersion": "<实测>", "cargoNdk": "<实测>", "target": "aarch64-linux-android", "api": 24 },
  "cargoLockSha256": "<tarball 内 Cargo.lock 整文件 sha256>",
  "cargoDeps": [ … cc 类 C 依赖逐条：name/version/sha256 … ],   // 粒度：方案 A + cc 依赖逐条（规划 §8 倾向）
  "tls": "rustls + bundled roots（provider 以 Cargo.lock 实测为准）",
  "ndk": "28.2.13676358", "flags": "-C link-arg=-Wl,-z,max-page-size=16384; llvm-strip --strip-unneeded"
}
```

- 依赖 sha 粒度拍板：**方案 A（Cargo.lock 整文件 sha256）+ cc 类 C 依赖（ring/zstd-sys 等）逐条记录**；
  若首轮 cargo license 清单生成成本可接受，随 Release 归档（002）；
- 本模块只产素材（§3.3 ⑨），lock 落笔归 002 回写工具（职责分离，防构建脚本直改事实源）。

---

## 5. FR 交叉引用（spec ↔ plan ↔ 现状）

| FR | 实现落点（计划） | 现状 |
|---|---|---|
| FR-001-001~004、006 | fetch 脚本 §2（PINS/幂等/布局/官方出处） | ⬜ 骨架 exit 2 |
| FR-001-005 | FETCH-METADATA.json §2.2 ⑤ | ⬜ |
| FR-001-010/011 | build 脚本 §3.1 ②（rustup/cargo-ndk/回退） | ⬜ 本机未装 rust ⚠️ |
| FR-001-012/013 | §3.1 ①③④（PATH/cc env/RUSTFLAGS） | ⬜ |
| FR-001-014/015 | §3.2（--locked）+ CI 缓存（002） | ⬜ |
| FR-001-020/021 | §3.2 试编探针 + §3.4 provider 口径 + 降级回写 | ⬜ |
| FR-001-022/023/024 | §3.3 ⑦ 门禁①②③④ + §3.5 DT_NEEDED + D4 | ⬜ |
| FR-001-025/026 | §3.2 增量 + §3.3 ⑧ 体积 | ⬜ |
| FR-001-030~035 | §3.3 ⑤~⑨ | ⬜ |

## 6. 测试考虑（呼应 [test-cases.md](./test-cases.md)）

- 用例层 L1/L1.5（host 侧）：fetch 幂等/篡改拒绝、工具链装配、构建门禁、strip 体积、METADATA；
- 设备侧行为验证不在本模块（→ 003-cli）；
- 首轮试编结论（含失败输出）作为 TC-001-07 的证据归档。

## 7. 待定项（开发中拍板，先回写规划）

| # | 事项 | 出口 |
|---|---|---|
| 1 | uv 钉选版本（draft 0.9.0 → 实际最新稳定） | PINS 定稿 + `CLI_VERSION`/lock 同步（P8） |
| 2 | crypto provider 实测（ring vs aws-lc-rs） | Cargo.lock 清单记录 + 规划 §4.1 回写 |
| 3 | DT_NEEDED 是否含 `libc++_shared.so` | §3.5 记录 + 规划 §4.4/lock 回写 |
| 4 | 体积实测 vs 25–40MB 预估 | BUILD-METADATA 回填（R3） |
