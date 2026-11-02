# THIRD-PARTY-NOTICES — aosp-uv-cli

本 AAR 随包分发的第三方组件与许可：

- **uv**（`libuv_cli.so` 本体）—— MIT OR Apache-2.0（双许可）：
  https://github.com/astral-sh/uv/blob/main/LICENSE-MIT ｜ LICENSE-APACHE
- **Rust 标准库 / 工具链产物**—— MIT OR Apache-2.0
- 主要 Rust 依赖（rustls、ring、tokio、zstd 等）——各自许可（MIT/Apache-2.0/ISC 等），
  完整清单（cargo license 报告）随 GitHub Release 归档分发

纪律：

- 二进制不入库，由 CI 从官方 uv 源码构建（sha256 校验，源码不改；交叉编译参数经 cargo
  配置注入）；
- 完整许可全文随 GitHub Release 归档分发；
- 本仓库自身代码适用仓库根 [LICENSE](../LICENSE)（MIT）。
