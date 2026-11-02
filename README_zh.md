# aosp-uv-cli

[English](README.md) · [**中文**](README_zh.md)

**以 AAR 形式发布的、Android 版 `uv` 命令行可执行**——Rust 交叉编译（官方 tier2 target
`aarch64-linux-android`）的 `libuv_cli.so`（arm64-v8a，exec 型 PIE），TLS 走 rustls 自带根
证书。终端里由 node-pty 经 `forkpty` + `execve` 启动，提供真正的 `uv` 命令（python 环境/
包管理）。

本仓库不含任何嵌入 API——只有原生二进制的可复现构建、ELF 门禁与发布流水线。
规划基线见 [`docs/000-工程规划.md`](docs/000-工程规划.md)；工作区级方案背景见
node-bridge-workspace 的 `docs/aosp+node+python+git运行方案.md`。

## 版本：跟随 uv 上游（独立 semver）

制品版本 = uv 上游版本。与其它仓无配对关系。**只发布 AArch64（arm64-v8a）**。
上游无官方 Android 产物 ⇒ 本仓 CI 自建（纪律：不下载上游二进制）。

### 发布版本 —— Maven Central（`io.github.fellow99:uv-cli`）

| 版本 | 状态 | 链接 |
|---|---|---|
| 0.9.0 | ⬜ draft（M1 首产后发布；以 CI 实际钉住的 uv 版本为准） | — |

## 构建口径（要点）

- `rustup target add aarch64-linux-android` + cargo-ndk（NDK linker）；
- `-C link-arg=-Wl,-z,max-page-size=16384`（16KB 页设备硬要求）；
- ring/zstd 等 C 依赖的可编性试编是 M1 前置探针；
- 产物 exec 型 ELF：PIE + PT_INTERP=`/system/bin/linker64`；
- 命名 `libuv_cli.so`（**严禁与 libuv 库同名混淆**）。

## 用法（消费方）

```kotlin
dependencies {
    runtimeOnly("io.github.fellow99:uv-cli:0.9.0") // 独立版本，不与 node 系配对
}
```

终端侧：`PATH` 指向 `nativeLibraryDir` 后 `uv venv` / `uv pip install` 即可用；
与 `python-cli`（aosp-python-cli）组合构成完整 python 工具链。

## exec 型打包要点

- **`useLegacyPackaging=true`**（必须物理落盘 `nativeLibraryDir`，否则 `execve` ENOENT）；
- PT_INTERP 必须为 `/system/bin/linker64`（门禁强制）；
- DT_NEEDED 白名单（系统库 + `libc++_shared.so`，后者由消费方包内 node-runtime 供给）；
- 16KB 页对齐。

## 如何构建（000-scaffold 骨架；M1 接入真实交叉编译）

```bash
node scripts/fetch-uv-cli-source.mjs --uv 0.9.0 --out .dist/src   # M1
bash scripts/build-uv-cli-android.sh --uv 0.9.0 --api 24 \
  --src .dist/src/uv-src --ndk "$ANDROID_NDK_HOME" --out build/out  # M1
node tools/provision.mjs --out uv-cli/src/main/jniLibs --from build/out/libuv_cli.so
node tools/provision.mjs --check
```

## 锁定与校验

[`uv-cli.lock.json`](uv-cli.lock.json)（唯一事实源，当前 draft）。退出码：`0` 全过 ·
`2` 门禁不合格/未投放 · `1` 用法/IO 错误。

## 许可

[MIT](LICENSE)。uv 为 MIT OR Apache-2.0 双许可——见
[`uv-cli/THIRD-PARTY-NOTICES.md`](uv-cli/THIRD-PARTY-NOTICES.md)。
