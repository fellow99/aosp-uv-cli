#!/usr/bin/env bash
# scripts/test-on-device/probe-lib.sh —— 用例运行器函数库（host 侧驱动 adb，FR-003-004）
# 被 run-probes.sh source；不直接执行。
# 纪律：每条用例独立 ws/<ID>/；超时保护；PASS/FAIL/SKIP 三值；结果写 TSV（node 合并时统一转 JSON，
# 避免手拼 JSON 的转义陷阱）。
# shellcheck shell=bash

ADB_BIN="${ADB_BIN:-adb}"
SERIAL="${SERIAL:-}"
REPORT_JSON="${REPORT_JSON:?REPORT_JSON not set}"
MS_ACC=0

adb_sh() { # adb_sh <timeout_s> <shell-cmd>  → stdout；超时返回 124
  local t="$1"; shift
  if [ -n "$SERIAL" ]; then
    timeout "$t" "$ADB_BIN" -s "$SERIAL" shell "$@"
  else
    timeout "$t" "$ADB_BIN" shell "$@"
  fi
}

# run_case <ID> <title> <expect:ok|fail|info> <timeout_s> <cmd> [fail_pat]
#   expect=ok   → exit 0 才 PASS
#   expect=fail → exit ≠ 0 才 PASS；rc=127 视为环境错（命令不存在）；给 fail_pat 时
#                 设备输出必须含该模式（-E）才算 PASS（防假阳性：链接失败等环境错被当预期失败）
#   expect=info → 只记录不判（记录性用例）
run_case() {
  local id="$1" title="$2" expect="$3" tmo="$4" cmd="$5"
  local fail_pat="${6:-}"
  mkdir -p "$TMP_RESULTS"
  adb_sh 5 "mkdir -p '$WORK/ws/$id'" >/dev/null 2>&1
  local t0 t1 out rc verdict detail=""
  t0=$(date +%s%3N)
  # 单层解析 + export 注入：前缀赋值(VAL=x cmd $(…))在 mksh 下不传递给命令替换，export 才全局生效
  out=$(adb_sh "$tmo" "cd '$WORK/ws/$id' && export $ENV_PREFIX && $cmd" 2>&1); rc=$?
  t1=$(date +%s%3N)
  if [ "$rc" -eq 124 ]; then verdict=FAIL; detail="timeout(${tmo}s)";
  elif [ "$expect" = ok ] && [ "$rc" -eq 0 ]; then verdict=PASS
  elif [ "$expect" = fail ] && [ "$rc" -eq 127 ]; then verdict=FAIL; detail="exit=127（命令不存在——环境错，不判预期失败）"
  elif [ "$expect" = fail ] && [ "$rc" -ne 0 ] && [ -n "$fail_pat" ] && printf '%s' "$out" | grep -Eq "$fail_pat"; then verdict=PASS
  elif [ "$expect" = fail ] && [ "$rc" -ne 0 ] && [ -n "$fail_pat" ]; then verdict=FAIL; detail="exit=$rc 但失败原因不含预期语义（假阳性防护：$fail_pat）"
  elif [ "$expect" = fail ] && [ "$rc" -ne 0 ]; then verdict=PASS
  elif [ "$expect" = info ]; then verdict=INFO
  else verdict=FAIL; detail="exit=$rc expect=$expect"; fi
  local ms=$((t1 - t0))
  MS_ACC=$((MS_ACC + ms))
  out="${out//$'\r'/}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$title" "$verdict" "$detail" "$rc" "$ms" "$(printf '%s' "$out" | head -c 400 | tr '\n' ' ' | tr -d '\t')" >> "$TMP_RESULTS/lines.tsv"
  printf '%-14s %-6s %5sms  %s\n' "$id" "$verdict" "$ms" "$title"
  [ $VERBOSITY -ge 2 ] && printf '%s\n' "$out" | sed 's/^/    | /'
  [ "$verdict" = FAIL ] && [ $VERBOSITY -ge 1 ] && printf '%s\n' "$out" | head -20 | sed 's/^/    ! /'
}

skip_case() {
  local id="$1" title="$2" reason="$3"
  printf '%s\t%s\tSKIP\t%s\tSKIP\t0\t\n' "$id" "$title" "$reason" >> "$TMP_RESULTS/lines.tsv"
  printf '%-14s %-6s        %s（%s）\n' "$id" SKIP "$title" "$reason"
}

# snapshot <ID> <title> <设备命令> —— 记录性采集（FR-003-044）
snapshot() {
  local id="$1" title="$2" cmd="$3"
  local out; out=$(adb_sh 10 "$cmd" 2>&1 | tr -d '\r')
  printf '%s\t%s\tINFO\t\t0\t0\t%s\n' "$id" "$title" "$(printf '%s' "$out" | head -c 600 | tr '\n' ' ' | tr -d '\t')" >> "$TMP_RESULTS/lines.tsv"
  printf '%-14s %-6s        %s\n' "$id" SNAP "$title"
}
