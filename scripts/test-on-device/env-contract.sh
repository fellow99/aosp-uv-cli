#!/usr/bin/env bash
# scripts/test-on-device/env-contract.sh —— env 契约注入表（shell 域实例化，单一事实源）
# 规划 §7 表的等价载体；SSL_CERT_FILE 永不注入（D4：rustls 内嵌根证书）。
# 被 run-probes.sh source；不直接执行。
# shellcheck shell=bash

WORK="${UV_PROBE_WORK:-/data/local/tmp/uv-probe}"   # 设备工作目录（FR-003-005：全部活动限制在此）

# 基础注入（规划 §7 表 → shell 域实例化）
ENV_VARS=(
  "PATH=${WORK}/bin:/system/bin"
  "HOME=${WORK}/home"
  "TMPDIR=${WORK}/tmp"
  "UV_CACHE_DIR=${WORK}/cache"
  "UV_HTTP_TIMEOUT=30"
)

# LD_LIBRARY_PATH（P6 反证用；默认不注入——由 TC-003-12 双向对照控制）
ENV_LIBCPP_DIR=""   # run-probes.sh --libcxx <device-dir> 时设置（目录内须有 libc++_shared.so）

# UV_PYTHON（P4 组合探针用；默认不注入——TC-003-14 专项控制）
ENV_UV_PYTHON=""    # run-probes.sh --python-cli-interp <device-path> 时设置

# 组装前缀：ENV_PREFIX 命令前缀（不含 UV_PYTHON/LD_LIBRARY_PATH 专项项）
ENV_PREFIX="${ENV_VARS[*]}"

# 专项前缀（含 LD_LIBRARY_PATH / UV_PYTHON 的完整版，用于 TC-003-12② / TC-003-14）
ENV_PREFIX_FULL="$ENV_PREFIX"
[ -n "$ENV_LIBCPP_DIR" ] && ENV_PREFIX_FULL="LD_LIBRARY_PATH=${ENV_LIBCPP_DIR} $ENV_PREFIX_FULL"
[ -n "$ENV_UV_PYTHON" ] && ENV_PREFIX_FULL="UV_PYTHON=${ENV_UV_PYTHON} $ENV_PREFIX_FULL"
