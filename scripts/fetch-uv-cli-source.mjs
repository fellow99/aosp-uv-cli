#!/usr/bin/env node
/*
 * scripts/fetch-uv-cli-source.mjs —— 取构建输入（uv 官方源码包，不改源）
 *
 * 输出布局（默认 .dist/src）：
 *   <out>/uv-src/               uv <ver> 源码树（含 Cargo.toml / Cargo.lock）
 *   <out>/FETCH-METADATA.json   取侧元数据（版本/URL/tarball sha256/Cargo.lock sha256/时间）
 * 缓存：<root>/.dist/dl/uv-<ver>.tar.gz（sha256 匹配即跳过下载；损坏自动重下）
 *
 * 纪律（宪法 P1/P7；规划 §4.1/§4.2 ⑦）：
 *   - 只走官方出处（github.com/astral-sh/uv releases），钉选表之外一律拒绝；
 *   - sha256 一手实测（下载计算 + 与官方 .sha256 边车核对后固化进 PINS）；
 *   - 解压不改源（--strip-components 仅去顶层目录名）。
 *
 * 用法：
 *   node scripts/fetch-uv-cli-source.mjs --uv 0.13.6 --out .dist/src
 *
 * 退出码：0 成功 · 2 校验失败/未登记版本 · 1 用法/IO 错误
 */

import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// ── 钉选表（PINS；新增版本 = 官方 release + sha256 一手实测后加行，P8 同步 lock/规划）──
const PINS = {
  '0.13.6': {
    // 官方 release 资产名是 source.tar.gz（规划 §4.1 模板写 uv-<ver>.tar.gz，以实测资产名回写规划）
    url: 'https://github.com/astral-sh/uv/releases/download/0.13.6/source.tar.gz',
    sha256: '37af57c31f780488bce798b73fcd382949faef72e7a98a7e73fe0f24874ed924',
  },
};

const args = process.argv.slice(2);
function argOf(name, fallback = null) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}
function usage() {
  process.stderr.write(
    [
      '用法: node scripts/fetch-uv-cli-source.mjs --uv <uv 版本> [--out <dir>]',
      '  --uv   uv 上游版本（= CLI_VERSION；须在 PINS 表内）',
      '  --out  输出目录（默认 .dist/src）',
      `  已登记版本: ${Object.keys(PINS).join(', ')}`,
    ].join('\n') + '\n',
  );
}
const die = (code, msg) => { process.stderr.write(`[fetch] 失败：${msg}\n`); process.exit(code); };

const uvver = argOf('--uv');
const out = argOf('--out') ?? path.join(ROOT, '.dist', 'src');

if (args.includes('--help') || args.includes('-h')) { usage(); process.exit(0); }
if (!uvver) { usage(); die(1, '缺少 --uv'); }

const pin = PINS[uvver];
if (!pin) die(2, `uv ${uvver} 未登记于钉选表（已登记：${Object.keys(PINS).join(', ')}）；拒绝下载表外版本（FR-001-006）`);

const dlDir = path.join(ROOT, '.dist', 'dl');
const cache = path.join(dlDir, `uv-${uvver}.tar.gz`);
fs.mkdirSync(dlDir, { recursive: true });
fs.mkdirSync(out, { recursive: true });

const sha256File = (file) => {
  const h = createHash('sha256');
  h.update(fs.readFileSync(file));
  return h.digest('hex');
};

// ── ① 缓存命中（sha256 匹配）即跳过下载 ─────────────────────────────────────
let needDownload = true;
if (fs.existsSync(cache)) {
  const got = sha256File(cache);
  if (got === pin.sha256) {
    console.log(`[fetch] 缓存命中且 sha256 匹配，跳过下载：${path.relative(ROOT, cache)}`);
    needDownload = false;
  } else {
    console.log(`[fetch] 缓存损坏（sha256 失配），重新下载 …`);
    fs.rmSync(cache);
  }
}

// ── ② 下载 + 校验（失配即删缓存拒绝，绝不进入构建）─────────────────────────
if (needDownload) {
  console.log(`[fetch] 下载 ${pin.url}`);
  // 3 次重试（网络抖动防护；每次失败干净报错，不抛丑栈）
  let buf = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(pin.url, { redirect: 'follow', signal: AbortSignal.timeout(60_000) });
      if (!res.ok) throw new Error(`HTTP ${res.status}`); // 5xx/429 也进重试
      buf = Buffer.from(await res.arrayBuffer());
      break;
    } catch (err) {
      if (attempt === 3) die(1, `下载失败（3 次重试后放弃）：${err.cause?.code ?? err.message}`);
      console.log(`[fetch] 第 ${attempt} 次尝试失败（${err.cause?.code ?? err.message}），重试 …`);
    }
  }
  fs.writeFileSync(cache, buf);
  const got = sha256File(cache);
  if (got !== pin.sha256) {
    fs.rmSync(cache);
    die(2, `sha256 失配：期望 ${pin.sha256}，实得 ${got}（已删缓存）`);
  }
  console.log(`[fetch] sha256 ✔ ${got}（${buf.length} bytes）`);
}

// ── ③ 解压到 <out>/uv-src（幂等：先清后建；--strip-components 去顶层目录名，不改源）──
const srcDir = path.join(out, 'uv-src');
fs.rmSync(srcDir, { recursive: true, force: true });
fs.mkdirSync(srcDir, { recursive: true });
// tarball 顶层目录形如 uv-<ver>/（--force-local：Windows 盘符路径防被当作远程主机名）
const list = spawnSync('tar', ['--force-local', '-tzf', cache], { encoding: 'utf8' });
if (list.status !== 0) die(1, `tar -tzf 失败：${list.stderr}`);
const first = list.stdout.split('\n')[0] || '';
const topDir = first.split('/')[0];
if (!topDir || !first.endsWith('/')) die(1, `tarball 顶层不是单一目录（首行：${first}），拒绝猜测布局`);
const ext = spawnSync('tar', ['--force-local', '-xzf', cache, '-C', srcDir, '--strip-components=1'], { stdio: 'inherit' });
if (ext.status !== 0) die(1, 'tar 解压失败');

// ── ④ 源码树存在性校验 ─────────────────────────────────────────────────────
for (const rel of ['Cargo.toml', 'Cargo.lock', 'crates/uv/Cargo.toml']) {
  if (!fs.existsSync(path.join(srcDir, rel))) die(1, `源码树缺失 ${rel}（布局异常）`);
}

// ── ⑤ 取侧元数据（Cargo.lock 整文件 sha256，规划 §8 方案 A）────────────────
const cargoLockSha256 = sha256File(path.join(srcDir, 'Cargo.lock'));
const meta = {
  tool: 'uv-cli',
  version: uvver,
  url: pin.url,
  tarballSha256: pin.sha256,
  cargoLockSha256,
  fetchedAt: new Date().toISOString(),
};
const metaPath = path.join(out, 'FETCH-METADATA.json');
fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');

console.log(`[fetch] 源码树：${path.relative(ROOT, srcDir)}`);
console.log(`[fetch] Cargo.lock sha256 = ${cargoLockSha256}`);
console.log(`[fetch] 元数据：${path.relative(ROOT, metaPath)}`);
