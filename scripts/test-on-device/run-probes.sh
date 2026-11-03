#!/usr/bin/env bash
# scripts/test-on-device/run-probes.sh —— 003-cli 主用例全集执行器（TC-003-00~17，FR-003-001~044）
#
# 用法：
#   bash scripts/test-on-device/run-probes.sh [--device <serial>] [--so <libuv_cli.so>] \
#     [--report <dir>] [--only <TC-003-xx>] [--libcxx <device-dir>] \
#     [--python-cli-interp <device-path>] [-v|-vv] [--keep]
#
#   --device   adb 序列号（默认唯一在线设备；多设备必填）
#   --so       host 侧制品路径（默认 build/out/libuv_cli.so）
#   --report   报告目录（默认 logs/<今日>-1）
#   --libcxx   设备上含 libc++_shared.so 的目录（P6 反证 ② 用；DT_NEEDED 实测含该库时提供）
#   --python-cli-interp  设备上 python-cli 物化解释器路径（P4 组合探针用；缺省 ⇒ TC-003-14 SKIP）
#   --only     只跑指定用例（逗号分隔）；--keep 保留设备工作区不复位
#
# 载体形态必须入报告（真机 / ndk_translation / arm64 AVD，P6 纪律）。全部活动限制在
# /data/local/tmp/uv-probe（FR-003-005）。网络用例超时保护；网络不可达 ⇒ SKIP 不算 FAIL。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

SERIAL=""; SO="$ROOT/build/out/libuv_cli.so"; REPORT=""; ONLY=""; LIBCXX=""; PYPY=""; VERBOSITY=1; KEEP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) SERIAL="$2"; shift 2;;
    --so) SO="$2"; shift 2;;
    --report) REPORT="$2"; shift 2;;
    --only) ONLY="$2"; shift 2;;
    --libcxx) LIBCXX="$2"; shift 2;;
    --python-cli-interp) PYPY="$2"; shift 2;;
    -v) VERBOSITY=2; shift;;
    -vv) VERBOSITY=3; shift;;
    --keep) KEEP=1; shift;;
    -h|--help) sed -n '2,16p' "$0"; exit 0;;
    *) echo "未知参数：$1" >&2; exit 1;;
  esac
done
ADB_BIN="${ADB_BIN:-adb}"
command -v "$ADB_BIN" >/dev/null 2>&1 || { echo "adb 不可寻（设 ADB_BIN）" >&2; exit 1; }
[[ -f "$SO" ]] || { echo "制品不存在：$SO（先跑 001 构建）" >&2; exit 1; }

# 设备就绪检测
DEVS="$("$ADB_BIN" devices | awk 'NR>1 && $2=="device"{print $1}')"
if [[ -z "$SERIAL" ]]; then
  SERIAL="$(echo "$DEVS" | head -1)"
  [[ -n "$SERIAL" ]] || { echo "无在线设备" >&2; exit 1; }
  [[ $(echo "$DEVS" | wc -l) -gt 1 ]] && { echo "多设备在线，须 --device" >&2; exit 1; }
fi
echo "$DEVS" | grep -qx "$SERIAL" || { echo "设备 $SERIAL 不在线" >&2; exit 1; }

TODAY="$(date +%Y%m%d)"
REPORT="${REPORT:-$ROOT/logs/${TODAY}-1}"
mkdir -p "$REPORT"
TMP_RESULTS="$REPORT/probe-tmp"; rm -rf "$TMP_RESULTS"; mkdir -p "$TMP_RESULTS"
REPORT_JSON="$REPORT/probe-report-device.json"

source "$HERE/env-contract.sh"
[ -n "$LIBCXX" ] && ENV_LIBCPP_DIR="$LIBCXX"
[ -n "$PYPY" ] && ENV_UV_PYTHON="$PYPY"
source "$HERE/probe-lib.sh"

# ── 部署（FR-003-001/002：推送 + 可执行位 + symlink 农场；幂等）───────────────
echo "== deploy → $SERIAL ($WORK) =="
"$ADB_BIN" -s "$SERIAL" shell "rm -rf '$WORK' && mkdir -p '$WORK'/bin '$WORK'/home '$WORK'/tmp '$WORK'/cache '$WORK'/xdg '$WORK'/ws"
"$ADB_BIN" -s "$SERIAL" push "$SO" "$WORK/libuv_cli.so" >/dev/null || { echo "push 失败" >&2; exit 1; }
"$ADB_BIN" -s "$SERIAL" shell "chmod +x '$WORK/libuv_cli.so' && ln -sf ../libuv_cli.so '$WORK/bin/uv' && ls -l '$WORK'"
SO_SHA_HOST="$(sha256sum "$SO" | cut -d' ' -f1)"

want() { [[ -z "$ONLY" ]] || echo ",$ONLY," | grep -q ",$1,"; }

# ── A. 探针环境自检 ─────────────────────────────────────────────────────────
echo "== cases =="
if want TC-003-00; then
  run_case TC-003-00 "部署自检" ok 10 "ls -l '$WORK/libuv_cli.so' | grep -q 'x' && readlink '$WORK/bin/uv' | grep -q libuv_cli.so && echo env-ok"
fi
ABI="$(adb_sh 5 'getprop ro.product.cpu.abi' | tr -d '\r')"
HOST_ABI="$(adb_sh 5 'uname -m' | tr -d '\r')"
CARRIER="$([[ "$ABI" == arm64-v8a* || "$ABI" == aarch64* ]] && echo 'arm64-native' || echo "ndk_translation(host=$HOST_ABI,abi=$ABI)")"
if want TC-003-00b; then
  snapshot TC-003-00b "环境快照" "echo carrier=$CARRIER; uname -m; getprop ro.product.cpu.abi; getprop ro.build.version.sdk; getconf PAGESIZE; getenforce; ls -Z '$WORK/libuv_cli.so'; sha256sum '$WORK/libuv_cli.so'"
fi
PAGESIZE="$(adb_sh 5 'getconf PAGESIZE' | tr -d '\r')"

# ── B. 版本与基础命令（P1/P5）───────────────────────────────────────────────
if want TC-003-01; then
  run_case TC-003-01 "版本回程（P1）" ok 20 "$WORK/libuv_cli.so --version && PATH='$WORK/bin:$PATH' uv --version"
fi
if want TC-003-02; then
  run_case TC-003-02 "帮助直出" ok 20 "uv help >/dev/null && uv pip --help >/dev/null && echo help-ok"
fi
if want TC-003-03; then
  run_case TC-003-03 "cache dir 注入（P5）" ok 20 "[ \"\$(uv cache dir)\" = '$WORK/cache' ] && echo cache-ok"
fi
if want TC-003-04; then
  run_case TC-003-04 "退出码采样" info 20 "uv --bogus-flag; echo exit=\$?; uv no-such-command; echo exit=\$?"
fi

# ── C. venv 与 pip 闭环（P2/P3）─────────────────────────────────────────────
if want TC-003-05; then
  run_case TC-003-05 "venv 创建（P2）" ok 60 "uv venv venv && test -f venv/pyvenv.cfg && ls -l venv/bin/ && echo venv-ok"
fi
if want TC-003-06; then
  run_case TC-003-06 "venv 指定解释器失败形态" info 60 "env -u UV_PYTHON uv venv --python 3.12 venv2; echo exit=\$?"
fi
NET_OK=0
if want TC-003-07; then
  # 网络预检（不可达 ⇒ SKIP 整组网络用例）
  adb_sh 15 "ping -c1 -W5 8.8.8.8 >/dev/null 2>&1 || echo 'HTTP HEAD pypi' | nc -w 5 pypi.org 443" >/dev/null 2>&1
  adb_sh 20 "curl -sI --max-time 10 https://pypi.org >/dev/null 2>&1" && NET_OK=1
  if [[ $NET_OK -eq 1 ]]; then
    run_case TC-003-07 "pip install 纯 wheel HTTPS（P3/rustls）" ok 300 "uv venv v3 >/dev/null && uv pip install --python v3/bin/python packaging && ls v3/lib/python*/site-packages/ | grep -i packaging"
  else
    skip_case TC-003-07 "pip install 纯 wheel HTTPS（P3/rustls）" "设备网络不可达"
  fi
fi
if want TC-003-08; then
  [[ $NET_OK -eq 1 ]] && run_case TC-003-08 "pip list/uninstall 闭环" ok 120 "uv pip list --python v3/bin/python | grep -i packaging && uv pip uninstall --python v3/bin/python packaging && ! uv pip list --python v3/bin/python | grep -i packaging && echo cycle-ok" || skip_case TC-003-08 "pip list/uninstall 闭环" "依赖 TC-003-07（网络）"
fi
if want TC-003-09; then
  # sdist-only 样本：任意目录树无 wheel 老包（pin 记录于 003 plan §6-1）
  [[ $NET_OK -eq 1 ]] && run_case TC-003-09 "sdist 拒收事实化" fail 300 "uv venv vs >/dev/null && uv pip install --python vs/bin/python 'flake8==2.0' ; echo exit=\$?" || skip_case TC-003-09 "sdist 拒收事实化" "依赖网络"
fi
if want TC-003-10; then
  run_case TC-003-10 "uv python install 禁用（C2/D7）" fail 90 "uv python install 3.12"
fi
if want TC-003-11; then
  [[ $NET_OK -eq 1 ]] && run_case TC-003-11 "cache 增量核验" ok 300 "du -s '$WORK/cache' && uv venv vc >/dev/null && uv pip install --python vc/bin/python packaging && echo cache-hit-ok" || skip_case TC-003-11 "cache 增量核验" "依赖网络"
fi

# ── D. TLS 与动态链接反证（P6/R6）───────────────────────────────────────────
if want TC-003-12; then
  # ① 不注入 LD_LIBRARY_PATH（ENV_PREFIX 本就不含）
  run_case TC-003-12a "LD_LIBRARY_PATH 反证①去注入" info 20 "$WORK/libuv_cli.so --version; echo exit=\$?"
  if [[ -n "$LIBCXX" ]]; then
    run_case TC-003-12b "LD_LIBRARY_PATH 反证②注入libc++" ok 20 "LD_LIBRARY_PATH='$LIBCXX' $WORK/libuv_cli.so --version" "$ENV_PREFIX"
  else
    skip_case TC-003-12b "LD_LIBRARY_PATH 反证②注入libc++" "未提供 --libcxx（DT_NEEDED 实测不含该库则本条改记录性）"
  fi
fi
if want TC-003-13; then
  [[ $NET_OK -eq 1 ]] && run_case TC-003-13 "SSL_CERT_FILE 反证" info 300 "SSL_CERT_FILE=/nonexistent.pem uv pip install --python v3/bin/python six ; echo exit=\$?" || skip_case TC-003-13 "SSL_CERT_FILE 反证" "依赖网络"
fi

# ── E. 组合与限制事实化 ─────────────────────────────────────────────────────
if want TC-003-14; then
  if [[ -n "$PYPY" ]]; then
    run_case TC-003-14 "UV_PYTHON 组合（P4）" ok 300 "UV_PYTHON='$PYPY' uv venv v4 && UV_PYTHON='$PYPY' uv pip install --python v4/bin/python six && cd v4 && UV_PYTHON='$PYPY' uv run python -c 'import six;print(six.__version__)'" "$ENV_PREFIX"
  else
    skip_case TC-003-14 "UV_PYTHON 组合（P4）" "未提供 --python-cli-interp（python-cli 物化产物）"
  fi
fi
if want TC-003-15; then
  run_case TC-003-15 "git 依赖源限制" fail 90 "uv pip install --python v3/bin/python 'six @ git+https://github.com/benjaminp/six.git'"
fi
if want TC-003-16; then
  run_case TC-003-16 "XDG 兜底" ok 20 "env -u UV_CACHE_DIR XDG_CACHE_HOME='$WORK/xdg' sh -c '[ \"\$(uv cache dir)\" = \"'$WORK'/xdg\" ] || [ \"\$(uv cache dir)\" = \"'$WORK'/xdg/uv\" ]' && echo xdg-ok"
fi
if want TC-003-17; then
  if [[ "$PAGESIZE" == 16384 ]]; then
    run_case TC-003-17 "16KB 页采样" ok 60 "$WORK/libuv_cli.so --version && uv venv v16 && echo 16k-ok"
  else
    skip_case TC-003-17 "16KB 页采样" "页大小=${PAGESIZE}（非 16KB 设备）"
  fi
fi

# ── 报告（JSON + Markdown；FR-003-044 设备快照入报告）────────────────────────
MODEL="$(adb_sh 5 'getprop ro.product.model' | tr -d '\r')"
APILEVEL="$(adb_sh 5 'getprop ro.build.version.sdk' | tr -d '\r')"
SO_SHA_DEV="$(adb_sh 10 "sha256sum '$WORK/libuv_cli.so'" | cut -d' ' -f1 | tr -d '\r')"
PASS_N=$(grep -c '"verdict":"PASS"' "$TMP_RESULTS/lines.jsonl" || true)
FAIL_N=$(grep -c '"verdict":"FAIL"' "$TMP_RESULTS/lines.jsonl" || true)
SKIP_N=$(grep -c '"verdict":"SKIP"' "$TMP_RESULTS/lines.jsonl" || true)
{
  printf '{\n  "runAt": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "device": "%s %s abi=%s api=%s pagesize=%s carrier=%s",\n' "$MODEL" "$SERIAL" "$ABI" "$APILEVEL" "$PAGESIZE" "$CARRIER"
  printf '  "artifact": {"path": "%s", "sha256Host": "%s", "sha256Device": "%s"},\n' "$(basename "$SO")" "$SO_SHA_HOST" "$SO_SHA_DEV"
  printf '  "summary": {"pass": %s, "fail": %s, "skip": %s, "totalMs": %s},\n' "${PASS_N:-0}" "${FAIL_N:-0}" "${SKIP_N:-0}" "$MS_ACC"
  printf '  "probes": [\n'
  sed 's/^/    /; s/,$/,/' "$TMP_RESULTS/lines.jsonl" | sed '$ s/,$//'
  printf '\n  ]\n}\n'
} > "$REPORT_JSON"
{
  echo "# probe-report-device — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "- 设备：$MODEL（$SERIAL）· ABI=$ABI · API=$APILEVEL · PAGESIZE=$PAGESIZE · 载体=$CARRIER"
  echo "- 制品：$(basename "$SO") host_sha=$SO_SHA_HOST device_sha=$SO_SHA_DEV"
  echo "- 汇总：PASS=${PASS_N:-0} FAIL=${FAIL_N:-0} SKIP=${SKIP_N:-0}（明细见 probe-report-device.json）"
  echo
  sed 's/^\(.*\)$/- \1/' "$TMP_RESULTS/lines.jsonl" | sed 's/"id":"/**/; s/","title":"/** /; s/","verdict":"/ → /; s/","detail":"/（/; s/","exit":.*"stdout":"/） `/; s/"}$/'"'"'/"'
} > "$REPORT/probe-report-device.md"

[[ $KEEP -eq 0 ]] && "$ADB_BIN" -s "$SERIAL" shell "rm -rf '$WORK/ws'" >/dev/null 2>&1
echo
echo "== 汇总：PASS=${PASS_N:-0} FAIL=${FAIL_N:-0} SKIP=${SKIP_N:-0} → $REPORT_JSON =="
[[ ${FAIL_N:-0} -eq 0 ]]
