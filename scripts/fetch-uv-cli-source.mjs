#!/usr/bin/env node
/*
 * scripts/fetch-uv-cli-source.mjs —— 取构建输入（uv 官方源码包，不改源）
 *
 * 计划输出目录（默认 .dist/src）：
 *   <out>/uv-src/              uv <ver> 源码 tarball 解压内容（含 Cargo.toml / Cargo.lock）
 *
 * 源码不改；Cargo 依赖经 Cargo.lock 钉版 + crates.io 拉取（CI 缓存），sha 记录在 lock。
 *
 * 用法（规划接口，M1 实现）：
 *   node scripts/fetch-uv-cli-source.mjs --uv 0.9.0 --out .dist/src
 *
 * 状态：000-scaffold 只固化接口与纪律；下载/解压/校验逻辑在 M1 落地。
 *
 * 退出码：0 成功 · 2 SCAFFOLD 未实现 · 1 用法/IO/下载错误
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
function argOf(name, fallback = null) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}

function usage() {
  process.stderr.write(
    [
      '用法: node scripts/fetch-uv-cli-source.mjs --uv <uv 版本> [--out <dir>]',
      '  --uv   uv 上游版本（= CLI_VERSION）',
      '  --out  输出目录（默认 .dist/src）',
    ].join('\n') + '\n',
  );
}

const uvver = argOf('--uv');
const out = argOf('--out') ?? path.join(ROOT, '.dist', 'src');

if (args.includes('--help') || !uvver) {
  usage();
  process.exit(uvver ? 0 : 1);
}

process.stderr.write(
  [
    `[fetch] SCAFFOLD: 下载/解压/SHA-256 校验逻辑在 M1 实现（000-scaffold 只固化接口）。`,
    `[fetch] 计划输入: uv ${uvver} @ https://github.com/astral-sh/uv/releases`,
    `[fetch] 计划输出: ${out}/uv-src/`,
  ].join('\n') + '\n',
);
process.exit(2);
