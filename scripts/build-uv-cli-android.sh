#!/usr/bin/env bash
# scripts/build-uv-cli-android.sh —— Rust 交叉编译 uv 为 Android arm64 的 exec 型
# uv 命令行（libuv_cli.so，PIE 可执行）。
#
# 关键纪律（docs/000-工程规划.md §4；宪法 P1/P4/P6）：
#   1) Rust 官方 tier2 target aarch64-linux-android（rustup target add）；
#   2) cargo-ndk 主路线 / CARGO_TARGET_*_LINKER 环境变量回退路线（不写源码树内
#      .cargo/config.toml——tarball 自带 uv 的 config，改文件即改源，P1 禁止）；
#   3) RUSTFLAGS=-C\ link-arg=-Wl,-z,max-page-size=16384（16KB 页设备硬要求）；
#   4) 产物 exec 型 ELF：PIE + PT_INTERP=/system/bin/linker64（provision 门禁核验）；
#   5) TLS 走 rustls 自带根证书（不注入 SSL_CERT_FILE）；
#   6) 输出命名 libuv_cli.so（Android 打包只认 lib*.so；严禁 libuv.so）；
#   7) ring/zstd 等 C 依赖经 cc/NDK clang 编译（CC/AR/CXX_aarch64_linux_android）；
#   8) cargo 一律 --locked（可复现；依赖树漂移即失败）。
#
# 产物：<out>/libuv_cli.so（strip）+ BUILD-METADATA.txt + lock-writeback-inputs.json
#       + gates-report.txt（provision --inspect 输出）
#
# 用法：
#   scripts/build-uv-cli-android.sh \
#     --uv 0.13.6 --api 24 \
#     --src .dist/src/uv-src \
#     --ndk "$ANDROID_NDK_HOME" \
#     --out build/out
#
# 环境开关：SKIP_GATES=1 跳过 provision 门禁自检（仅 bring-up 调试，产物不得投放）。
# 退出码：0 成功 · 2 门禁/校验失败 · 1 用法/IO/工具缺失
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

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "[build] 失败：$1" >&2; exit "${2:-1}"; }

# ── ① NDK 工具链接线 ────────────────────────────────────────────────────────
[[ -d "$NDK" ]] || die "NDK 目录不存在：$NDK"
TOOLBIN="$(ls -d "$NDK"/toolchains/llvm/prebuilt/*/bin 2>/dev/null | head -1)"
[[ -n "$TOOLBIN" && -d "$TOOLBIN" ]] || die "NDK 内未找到 toolchains/llvm/prebuilt/*/bin"
CLANG="$TOOLBIN/aarch64-linux-android${API}-clang"
[[ -e "$CLANG" || -e "${CLANG}.exe" ]] || die "未找到 $CLANG（NDK/API 组合异常）"
export PATH="$TOOLBIN:$PATH"
NDK_VER="$(grep -m1 'Pkg.Revision' "$NDK/source.properties" | sed 's/.*= *//')"
echo "[build] NDK ${NDK_VER} @ ${NDK}"
echo "[build] toolchain: ${TOOLBIN}"

# ── ② rust 工具链检测/装配 + cc 交叉环境（FR-001-010/011/012）───────────────
if ! command -v cargo >/dev/null 2>&1; then
  export PATH="$HOME/.cargo/bin:$PATH"
  command -v cargo >/dev/null 2>&1 || die "cargo 不可寻（先装 rustup：https://rustup.rs；或把 ~/.cargo/bin 入 PATH）"
fi
if command -v rustup >/dev/null 2>&1; then
  if ! rustup target list --installed 2>/dev/null | grep -q '^aarch64-linux-android'; then
    echo "[build] rustup target add aarch64-linux-android"
    rustup target add aarch64-linux-android || die "rustup target add 失败"
  fi
fi

# ── ③ 编译（cargo-ndk 主路线 / 环境变量回退路线；路线记录，FR-001-011）──────
# Windows（MSYS/Git Bash）下 cargo/cc 是 Windows 进程，/c/... 形态路径无效 ⇒ cygpath -w 转换（Linux 无 cygpath 则原样）
to_win() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }
export CC_aarch64_linux_android="$(to_win "$CLANG")"
export CXX_aarch64_linux_android="$(to_win "$TOOLBIN/aarch64-linux-android${API}-clang++")"
export AR_aarch64_linux_android="$(to_win "$TOOLBIN/llvm-ar")"
echo "[build] CC=$CC_aarch64_linux_android AR=$AR_aarch64_linux_android"

# 16KB 页对齐（门禁 ⑦ 硬要求）+ libgcc 空壳：NDK r23+ 已移除 libgcc，而 rustc android
# -lgcc 失败）⇒ 注入空壳库路径（确定性方案，不依赖 cargo-ndk shim 行为）
GCC_SHIM_DIR="$OUT/shim-libgcc"; mkdir -p "$GCC_SHIM_DIR"
GCC_SHIM_DIR="$(cd "$GCC_SHIM_DIR" && pwd)"   # 绝对路径：linker CWD=cargo 包根，相对 -L 解析不到（CI 实证）
"$TOOLBIN/llvm-ar" crs "$GCC_SHIM_DIR/libgcc.a"
export RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384 -L native=$(to_win "$GCC_SHIM_DIR")"
echo "[build] RUSTFLAGS=$RUSTFLAGS（libgcc shim: $GCC_SHIM_DIR/libgcc.a）"
SRC="$(cd "$SRC" && pwd)"   # 绝对路径：后续 cd "$SRC" 编译，产物路径不能是相对形式（CI 实证：Finished 后找不到相对 BIN）
OUT="$(mkdir -p "$OUT" && cd "$OUT" && pwd)"   # 同上：cp/readelf 发生在 cd "$SRC" 之后，相对 OUT 会落错树（CI 实证：provision ENOENT）
[[ -f "$SRC/Cargo.toml" ]] || die "源码树缺 Cargo.toml：$SRC"
cd "$SRC"
ROUTE="env-linker"
if command -v cargo-ndk >/dev/null 2>&1; then
  ROUTE="cargo-ndk"
  echo "[build] 路线=cargo-ndk（$(cargo-ndk --version 2>/dev/null || echo 版本未知)）"
  cargo ndk -t arm64-v8a --platform "$API" build --release --locked
else
  echo "[build] 路线=env-linker（cargo-ndk 不可寻，CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER 注入；不写源码树内配置，P1）"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$(to_win "$CLANG")"
  cargo build --release --target aarch64-linux-android --locked
fi

BIN="$SRC/target/aarch64-linux-android/release/uv"
[[ -f "$BIN" ]] || die "构建产物未找到：$BIN（cargo 输出布局异常）"

# ── ④ strip + 改名 libuv_cli.so（D6；strip 前后体积回填，FR-001-030/031）────
mkdir -p "$OUT"
SIZE_BEFORE=$(stat -c %s "$BIN")
"$TOOLBIN/llvm-strip" --strip-unneeded "$BIN"
SIZE_AFTER=$(stat -c %s "$BIN")
cp "$BIN" "$OUT/libuv_cli.so"
SHA256=$(sha256sum "$OUT/libuv_cli.so" | cut -d' ' -f1)
echo "[build] strip: ${SIZE_BEFORE} -> ${SIZE_AFTER} bytes"
echo "[build] $OUT/libuv_cli.so sha256=${SHA256}"

# ── ⑤ DT_NEEDED 实测清单（D5 事实核验素材，FR-001-023）──────────────────────
NEEDED_JSON="["
first=1
while read -r line; do
  name="$(echo "$line" | sed 's/.*Shared library: \[\(.*\)\]/\1/')"
  [[ -n "$name" ]] || continue
  [[ $first -eq 1 ]] || NEEDED_JSON+=","
  NEEDED_JSON+="\"$name\""
  first=0
done < <("$TOOLBIN/llvm-readelf" -d "$OUT/libuv_cli.so" | grep 'NEEDED')
NEEDED_JSON+="]"
echo "[build] DT_NEEDED=${NEEDED_JSON}"

# ── ⑥ 元数据（BUILD-METADATA.txt；规划 §4.2 ⑦ 归档形态）─────────────────────
FETCH_META="$SRC/../FETCH-METADATA.json"
CARGOLOCK_SHA=""
[[ -f "$FETCH_META" ]] && CARGOLOCK_SHA="$(sed -n 's/.*"cargoLockSha256": "\([^"]*\)".*/\1/p' "$FETCH_META")"
RUSTVER="$(rustc -V 2>/dev/null || echo unknown)"
CARGONDK_VER="$(cargo-ndk --version 2>/dev/null || echo none)"
BUILD_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$OUT/BUILD-METADATA.txt" <<EOF
# uv-cli Android arm64 build metadata
builtAt=${BUILD_TS}
uvVersion=${UVVER}
target=aarch64-linux-android (arm64-v8a)
androidApi=${API}
rust=${RUSTVER}
cargoNdk=${CARGONDK_VER}
route=${ROUTE}
ndk=${NDK_VER}
rustflags=-C link-arg=-Wl,-z,max-page-size=16384
strip=llvm-strip --strip-unneeded
tls=rustls with bundled roots (provider per Cargo.lock)
sizeBeforeStrip=${SIZE_BEFORE}
sizeAfterStrip=${SIZE_AFTER}
sha256=${SHA256}
dtNeeded=${NEEDED_JSON}
cargoLockSha256=${CARGOLOCK_SHA}
sourceUrl=https://github.com/astral-sh/uv/releases/download/${UVVER}/source.tar.gz
EOF

# ── ⑦ lock 回写素材（FR-001-035；落笔归 002 的 lock-writeback 工具）──────────
cat > "$OUT/lock-writeback-inputs.json" <<EOF
{
  "version": "${UVVER}",
  "size": ${SIZE_AFTER},
  "sha256": "${SHA256}",
  "needed": ${NEEDED_JSON},
  "toolchain": { "rustVersion": "${RUSTVER}", "cargoNdk": "${CARGONDK_VER}", "target": "aarch64-linux-android", "api": ${API} },
  "cargoLockSha256": "${CARGOLOCK_SHA}",
  "tls": "rustls with bundled roots (provider per Cargo.lock)",
  "ndk": "${NDK_VER}",
  "flags": "-C link-arg=-Wl,-z,max-page-size=16384; llvm-strip --strip-unneeded",
  "builtAt": "${BUILD_TS}"
}
EOF

# ── ⑧ provision 七门禁自检（FR-001-033；失败即红，SKIP_GATES=1 仅 bring-up）──
if [[ "${SKIP_GATES:-0}" != "1" ]]; then
  if (cd "$ROOT" && node tools/provision.mjs --inspect "$OUT/libuv_cli.so" | tee "$OUT/gates-report.txt"); then
    echo "[build] 七门禁自检 ✔（报告：$OUT/gates-report.txt）"
  else
    die "provision 门禁未过（见上）；bring-up 调试可 SKIP_GATES=1，但产物不得投放" 2
  fi
fi

echo "[build] 完成：$OUT/libuv_cli.so（${SIZE_AFTER} bytes）"
