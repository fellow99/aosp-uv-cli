#!/usr/bin/env node
/*
 * tools/lock-writeback.mjs —— uv-cli.lock.json 回写闭环工具（002-building-workflow，FR-002-001~006）
 *
 * 输入：build 脚本产出的 lock-writeback-inputs.json（FR-001-035 素材）+ 目标 libuv_cli.so。
 * 守卫（可证伪）：
 *   ① 门禁自检：provision --inspect <so> 必须 exit 0（FR-002-006）；
 *   ② 制品复算：素材 sha256/size 与目标 .so 复算一致，否则拒绝（FR-002-003）；
 *   ③ 版本匹配：素材 version 必须命中 lock 中一条 release（FR-002-002）；
 *   ④ status 单向：目标条目已 released ⇒ 拒绝再回写（FR-002-002）；
 *   ⑤ 幂等：draft 态同素材重复回写结果一致（FR-002-005）。
 *
 * 用法：
 *   node tools/lock-writeback.mjs --inputs build/out/lock-writeback-inputs.json \
 *     --so build/out/libuv_cli.so [--lock uv-cli.lock.json] [--check]
 *
 * --check：干跑（校验 + 打印将写入的 diff，不落笔）。
 * 退出码：0 成功/干跑通过 · 2 校验/守卫失败 · 1 用法/IO
 */

import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const argOf = (name, fallback = null) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const die = (code, msg) => { process.stderr.write(`[lock-writeback] 失败：${msg}\n`); process.exit(code); };

const inputsPath = argOf('--inputs');
const soPath = argOf('--so');
const lockPath = argOf('--lock', path.join(ROOT, 'uv-cli.lock.json'));
const dryRun = args.includes('--check');

if (!inputsPath || !soPath) {
  process.stderr.write(
    '用法: node tools/lock-writeback.mjs --inputs <lock-writeback-inputs.json> --so <libuv_cli.so> [--lock <uv-cli.lock.json>] [--check]\n',
  );
  process.exit(1);
}
for (const f of [inputsPath, soPath, lockPath]) {
  if (!fs.existsSync(f)) die(1, `文件不存在：${f}`);
}

const inputs = JSON.parse(fs.readFileSync(inputsPath, 'utf8'));
const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8'));

// ── ① 门禁自检（provision --inspect 必须 0）──────────────────────────────────
const insp = spawnSync(process.execPath, [path.join(ROOT, 'tools', 'provision.mjs'), '--inspect', soPath], {
  encoding: 'utf8',
});
if (insp.status !== 0) {
  die(2, `provision --inspect 未过（exit ${insp.status}）——制品不得回写 lock：\n${insp.stdout}`);
}

// ── ② 制品复算（素材 vs 实物 sha256/size）───────────────────────────────────
const soBuf = fs.readFileSync(soPath);
const soSha = createHash('sha256').update(soBuf).digest('hex');
if (soSha !== inputs.sha256) die(2, `sha256 漂移：素材 ${inputs.sha256} ≠ 实物 ${soSha}`);
if (soBuf.length !== inputs.size) die(2, `size 漂移：素材 ${inputs.size} ≠ 实物 ${soBuf.length}`);

// ── ③ 版本匹配 + ④ status 单向 ──────────────────────────────────────────────
const rel = (lock.releases || []).find((r) => r.version === inputs.version);
if (!rel) {
  die(2, `素材版本 ${inputs.version} 未命中 lock releases（现有：${lock.releases.map((r) => r.version).join(', ')}）`);
}
if (rel.status === 'released') {
  die(2, `版本 ${inputs.version} 已 released——status 单向（draft → released），禁止再回写`);
}

// ── 回写（内存态，diff 后可选落笔）──────────────────────────────────────────
const before = JSON.stringify(rel, null, 2);
rel.size = inputs.size;
rel.sha256 = inputs.sha256;
rel.builtFrom = rel.builtFrom || {};
rel.builtFrom.source = `uv ${inputs.version} source tarball (github.com/astral-sh/uv releases), unmodified`;
if (inputs.toolchain) rel.builtFrom.toolchain = inputs.toolchain; // 结构化扩展（规划 §8）
if (inputs.cargoLockSha256) rel.builtFrom.cargoLockSha256 = inputs.cargoLockSha256;
if (inputs.tls) rel.builtFrom.tls = inputs.tls;
if (inputs.ndk) rel.builtFrom.ndk = inputs.ndk;
if (inputs.flags) rel.builtFrom.flags = inputs.flags;
if (Array.isArray(inputs.needed)) rel.builtFrom.needed = inputs.needed; // DT_NEEDED 实测清单
rel.gates = {
  eTypeEtDyn: true,
  ptInterpSystemLinker: true,
  eMachineAArch64: true,
  neededWhitelist: true,
  sha256Match: true,
  sizeMatch: true,
  pageAlign16k: true,
}; // 门禁自检已过 ⇒ 七布尔位全真（⑤⑥ 自此变硬比对）
rel.status = 'released';
rel.mavenCentral = rel.mavenCentral || {};
rel.mavenCentral.coordinates = `io.github.fellow99:uv-cli:${inputs.version}`;
rel.mavenCentral.published = false;
lock.active = lock.active || {};
lock.active.version = inputs.version;
const after = JSON.stringify(rel, null, 2);

if (before === after) {
  console.log('[lock-writeback] 幂等：目标条目已是素材内容，无 diff');
  process.exit(0);
}
if (dryRun) {
  console.log('[lock-writeback] --check 干跑：将写入以下变更（未落笔）');
  console.log(after);
  process.exit(0);
}
fs.writeFileSync(lockPath, JSON.stringify(lock, null, 2) + '\n');
console.log(`[lock-writeback] 已回写 ${path.relative(ROOT, lockPath)}：version=${inputs.version} status=released`);
console.log(`[lock-writeback] sha256=${inputs.sha256} size=${inputs.size}`);
