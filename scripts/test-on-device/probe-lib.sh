#!/usr/bin/env bash
# scripts/test-on-device/probe-lib.sh —— 用例运行器函数库（host 侧驱动 adb，FR-003-004）
# 被 run-probes.sh source；不直接执行。
# 纪律：每条用例独立 ws/<ID>/；超时保护；PASS/FAIL/SKIP 三值；JSON 逐条累积。
# shellcheck shell=bash

ADB_BIN="${ADB_BIN:-adb}"
SERIAL="${SERIAL:-}"
REPORT_JSON="${REPORT_JSON:?REPORT_JSON not set}"
MS_ACC=0

adb_sh() { # adb_sh <timeout_s> <shell-cmd>  → stdout；超时/断连返回 124
  local t="$1"; shift
  if [ -n "$SERIAL" ]; then
    timeout "$t" "$ADB_BIN" -s "$SERIAL" shell "$@"
  else
    timeout "$t" "$ADB_BIN" shell "$@"
  fi
}

# run_case <ID> <title> <expect:ok|fail|info> <timeout_s> <命令串（在设备 ws/<ID>/ 内、ENV_PREFIX 下执行）>
#   expect=ok   → exit 0 才 PASS
#   expect=fail → exit ≠ 0 才 PASS（限制事实化用例：失败是预期）
#   expect=info → 只记录不判（记录性用例）
run_case() {
  local id="$1" title="$2" expect="$3" tmo="$4" cmd="$5"
  local prefix="${6:-$ENV_PREFIX}"
  mkdir -p "$TMP_RESULTS"
  adb_sh 5 "mkdir -p '$WORK/ws/$id'" >/dev/null 2>&1
  local t0 t1 out rc verdict detail=""
  t0=$(date +%s%3N)
  # 单层解析 + export 注入：前缀赋值(VAL=x cmd $(…))在 mksh 下不传递给命令替换，export 形式才全局生效
  out=$(adb_sh "$tmo" "cd '$WORK/ws/$id' && export $prefix && $cmd" 2>&1); rc=$?
  t1=$(date +%s%3N)
  if [ "$rc" -eq 124 ]; then verdict=FAIL; detail="timeout(${tmo}s)";
  elif [ "$expect" = ok ] && [ "$rc" -eq 0 ]; then verdict=PASS
  elif [ "$expect" = fail ] && [ "$rc" -ne 0 ]; then verdict=PASS
  elif [ "$expect" = info ]; then verdict=INFO
  else verdict=FAIL; detail="exit=$rc expect=$expect"; fi
  local ms=$((t1 - t0))
  MS_ACC=$((MS_ACC + ms))
  out="${out//$'\r'/}"
  printf '%s\n' "{\"id\":\"$id\",\"title\":\"$title\",\"verdict\":\"$verdict\",\"detail\":\"$detail\",\"exit\":$rc,\"ms\":$ms,\"stdout\":\"$(printf '%s' "$out" | head -c 400 | sed 's/"/\\"/g' | tr '\n' ' ')\"}" >> "$TMP_RESULTS/lines.jsonl"
  printf '%-14s %-6s %5sms  %s\n' "$id" "$verdict" "$ms" "$title"
  [ $VERBOSITY -ge 2 ] && printf '%s\n' "$out" | sed 's/^/    | /'
  [ "$verdict" = FAIL ] && [ $VERBOSITY -ge 1 ] && printf '%s\n' "$out" | head -20 | sed 's/^/    ! /'
}

# skip_case <ID> <title> <reason>
skip_case() {
  local id="$1" title="$2" reason="$3"
  printf '%s\n' "{\"id\":\"$id\",\"title\":\"$title\",\"verdict\":\"SKIP\",\"detail\":\"$reason\",\"exit\":null,\"ms\":0,\"stdout\":\"\"}" >> "$TMP_RESULTS/lines.jsonl"
  printf '%-14s %-6s        %s（%s）\n' "$id" SKIP "$title" "$reason"
}

# snapshot_case <ID> <title> <设备命令> —— 记录性采集（FR-003-044）
snapshot() {
  local id="$1" title="$2" cmd="$3"
  local out; out=$(adb_sh 10 "$cmd" 2>&1 | tr -d '\r')
  printf '%s\n' "{\"id\":\"$id\",\"title\":\"$title\",\"verdict\":\"INFO\",\"detail\":\"\",\"exit\":0,\"ms\":0,\"stdout\":\"$(printf '%s' "$out" | head -c 600 | sed 's/"/\\"/g' | tr '\n' ' ')\"}" >> "$TMP_RESULTS/lines.jsonl"
  printf '%-14s %-6s        %s\n' "$id" SNAP "$title"
}
