#!/usr/bin/env bash
# scripts/build-uv-cli-android.sh —— Rust 交叉编译 uv 为 Android arm64 的 exec 型
# uv 命令行（libuv_cli.so，PIE 可执行）。
#
# 关键纪律（docs/000-工程规划.md §技术方案；000-scaffold 阶段固化接口，M1 实现）：
#   1) Rust 官方 tier2 target aarch64-linux-android（rustup target add）；
#   2) cargo-ndk / cargo --target 交叉编译；linker 用 NDK 的 aarch64-linux-android<api>-clang；
#   3) -C link-arg=-Wl,-z,max-page-size=16384（16KB 页设备硬要求）；
#   4) 产物 exec 型 ELF：PIE + PT_INTERP=/system/bin/linker64；
#   5) TLS 走 rustls 自带根证书（无系统证书目录依赖）；
#   6) 输出命名 libuv_cli.so（Android 打包只认 lib*.so；严禁与 libuv 库同名混淆）；
#   7) ring/zstd 等 C 依赖经 cc/NDK clang 编译（依赖可编性试编是 M1 前置探针）。
#
# 产物：<out>/libuv_cli.so（strip）+ <out>/BUILD-METADATA.txt
#
# 用法（规划接口，M1 实现）：
#   scripts/build-uv-cli-android.sh \
#     --uv 0.9.0 --api 24 \
#     --src .dist/src/uv-src \
#     --ndk "$ANDROID_NDK_HOME" \
#     --out build/out
#
# 状态：000-scaffold 只固化接口与差异纪律；cargo 构建/strip 门禁链在 M1 落地。
set -euo pipefail

usage() {
  cat <<'EOF'
用法: scripts/build-uv-cli-android.sh --uv <ver> --api <api> --src <uv 源码树> --ndk <ndk 路径> --out <dir>
  --uv   uv 上游版本（= CLI_VERSION）
  --api  Android API level（默认 24）
  --src  uv 源码树（fetch 脚本产出，含 Cargo.toml）
  --ndk  Android NDK 路径
  --out  产物目录
EOF
}

UVVER=""; API="24"; SRC=""; NDK=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uv)  UVVER="$2"; shift 2;;
    --api) API="$2";   shift 2;;
    --src) SRC="$2";   shift 2;;
    --ndk) NDK="$2";   shift 2;;
    --out) OUT="$2";   shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "未知参数: $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$UVVER" || -z "$SRC" || -z "$NDK" || -z "$OUT" ]]; then
  usage
  exit 1
fi

echo "[build] SCAFFOLD: cargo 构建/strip 门禁链在 M1 实现（000-scaffold 只固化接口与差异纪律）。"
echo "[build] 计划: uv=$UVVER api=$API src=$SRC ndk=$NDK out=$OUT"
echo "[build] 产物计划: $OUT/libuv_cli.so（exec 型 PIE, rustls TLS, 16KB 对齐）"
exit 2
