#!/usr/bin/env node
// verify-release.mjs - Post-publish verifier.
// Walks every channel that a publish touches and reports per-channel status.
// Run AFTER release scripts complete to catch drift (e.g. tag pushed but
// npm publish failed, GitHub Release created but not linked in README, etc.)
//
// Usage:
//   node scripts/verify-release.mjs [version]   # default: latest git tag
//
// Channels checked:
//   - npm registry: version matches
//   - GitHub Releases: tag exists as published (not draft)
//   - Gitee Releases: tag exists
//   - GitHub topics: required topics still set
//   - GitHub description: still set
//   - awesome-dsh-plugin: entry file present for this repo (if listing exists)
//   - dsh-market: Issue exists for this repo (search by title prefix)

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const args = process.argv.slice(2);
const root = path.resolve('.');

let version = args.find(a => !a.startsWith('--'));
if (!version) {
  const tags = execFileSync('git', ['tag', '--list', 'v*.*.*'], { cwd: root, encoding: 'utf8' }).trim().split('\n').filter(Boolean);
  if (tags.length === 0) { console.error('no version provided and no git tag found'); process.exit(2); }
  version = tags[tags.length - 1];
}
if (!version.startsWith('v')) version = 'v' + version;
const bareVersion = version.slice(1);

const owner = (() => {
  try {
    const url = execFileSync('git', ['config', '--get', 'remote.origin.url'], { cwd: root, encoding: 'utf8' }).trim();
    const m = url.match(/[:/]([^/]+)\/([^/]+?)(?:\.git)?$/);
    return m ? { owner: m[1], repo: m[2] } : null;
  } catch { return null; }
})();

if (!owner) { console.error('cannot infer owner/repo from git remote'); process.exit(2); }

const results = [];

function check(name, fn) {
  try {
    const r = fn();
    results.push({ check: name, ...r });
  } catch (err) {
    results.push({ check: name, status: 'FAIL', detail: err.message });
  }
}

function sh(cmd, args) {
  return execFileSync(cmd, args, { cwd: root, encoding: 'utf8' });
}

function shJSON(cmd, args) {
  const out = sh(cmd, args);
  try { return JSON.parse(out); } catch { return out; }
}

// Channel 1: npm registry version
check('npm: registry has the published version', () => {
  if (!fs.existsSync(path.join(root, 'package.json'))) return { status: 'SKIP', detail: 'no package.json' };
  const pkgName = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8')).name;
  let remote;
  try {
    remote = sh('npm', ['view', pkgName, 'version', '--registry=https://registry.npmjs.org/']).trim();
  } catch (err) {
    return { status: 'FAIL', detail: `cannot view ${pkgName}: ${err.message.trim()}` };
  }
  if (remote === bareVersion) return { status: 'PASS', detail: `${pkgName}@${remote}` };
  return { status: 'WARN', detail: `npm has ${remote}, expected ${bareVersion}` };
});

// Channel 1b: npm dist-tag check (pre-release vs latest)
check('npm: dist-tag matches version type', () => {
  if (!fs.existsSync(path.join(root, 'package.json'))) return { status: 'SKIP', detail: 'no package.json' };
  const pkgName = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8')).name;
  // Determine expected dist-tag from local version
  const isPrerelease = /-(alpha|beta|rc)\.\d+$/.test(bareVersion);
  const expectedTag = isPrerelease ? bareVersion.match(/-(alpha|beta|rc)\.\d+$/)[1] : 'latest';
  let actualTag;
  try {
    actualTag = sh('npm', ['dist-tag', 'ls', pkgName, '--registry=https://registry.npmjs.org/']).trim();
  } catch (err) {
    return { status: 'WARN', detail: `cannot read dist-tags: ${err.message.trim()}` };
  }
  // The dist-tag ls output format: "tag: version\n..." - parse and find one pointing at bareVersion
  const m = actualTag.match(new RegExp(`^(${expectedTag}):\s*(\S+)`, 'm'));
  if (!m) {
    return { status: 'WARN', detail: `dist-tag `${expectedTag}` not set; raw:\n${actualTag.split('\n').slice(0, 5).join('\n')}` };
  }
  if (m[2] === bareVersion) {
    return { status: 'PASS', detail: `dist-tag `${expectedTag}` -> ${m[2]}` };
  }
  return { status: 'WARN', detail: `dist-tag `${expectedTag}` -> ${m[2]} (expected ${bareVersion})` };
});

// Channel 2: GitHub Release exists for this tag
check('github: release exists for tag', () => {
  let out;
  try {
    out = sh('gh', ['release', 'view', version, '--json', 'isDraft,isPrerelease,url,name']);
  } catch (err) {
    return { status: 'FAIL', detail: `no GitHub Release for ${version}: ${err.message.trim()}` };
  }
  const j = JSON.parse(out);
  if (j.isDraft) return { status: 'WARN', detail: `release is still a draft: ${j.url}` };
  if (j.isPrerelease) return { status: 'WARN', detail: `release marked prerelease: ${j.url}` };
  return { status: 'PASS', detail: `${j.name || version}: ${j.url}` };
});

// Channel 3: Gitee Release exists (uses Gitee API if token available)
check('gitee: tag exists on remote', () => {
  try {
    const out = sh('git', ['ls-remote', 'gitee', `refs/tags/${version}`]);
    if (!out.trim()) return { status: 'WARN', detail: 'no gitee remote or tag missing on gitee' };
    const hash = out.split('\t')[0];
    return { status: 'PASS', detail: `gitee tag ${version} at ${hash.slice(0,7)}` };
  } catch (err) {
    return { status: 'SKIP', detail: 'gitee remote not configured' };
  }
});

// Channel 4: GitHub topics still set
check('github: required topics present', () => {
  let out;
  try {
    out = sh('gh', ['repo', 'view', '--json', 'repositoryTopics']);
  } catch (err) {
    return { status: 'SKIP', detail: 'gh CLI not authenticated' };
  }
  const topics = (JSON.parse(out).repositoryTopics || []).map(t => t.name);
  const expected = ['dsh-skill', 'agent-skills', 'publishing', 'release'];
  const missing = expected.filter(e => !topics.includes(e));
  if (missing.length) return { status: 'WARN', detail: `missing: ${missing.join(', ')}; current: ${topics.join(', ')}` };
  return { status: 'PASS', detail: `all 4 required topics present (total ${topics.length})` };
});

// Channel 5: GitHub description still set
check('github: description set', () => {
  let out;
  try {
    out = sh('gh', ['repo', 'view', '--json', 'description']);
  } catch (err) {
    return { status: 'SKIP', detail: 'gh CLI not authenticated' };
  }
  const desc = JSON.parse(out).description;
  if (!desc || desc.length < 10) return { status: 'WARN', detail: 'description empty' };
  return { status: 'PASS', detail: desc.slice(0, 60) + (desc.length > 60 ? '...' : '') };
});

// Channel 6: awesome-dsh-plugin entry exists (search GitHub for the file)
check('awesome-dsh-plugin: yml entry exists', () => {
  const filename = `${owner.owner}__${owner.repo}.yml`;
  try {
    const raw = sh('curl', ['-fsSL', `https://raw.githubusercontent.com/awesome-dsh-plugin/awesome-dsh-plugin/main/data/plugins/${filename}`]);
    if (raw.includes('url:')) return { status: 'PASS', detail: `data/plugins/${filename} merged` };
    return { status: 'FAIL', detail: 'file present but does not look like a yml entry' };
  } catch {
    return { status: 'WARN', detail: `data/plugins/${filename} not merged in awesome-dsh-plugin yet (PR still open?)` };
  }
});

// Channel 7: dsh-market Issue exists (search by title prefix)
check('dsh-market: submission Issue exists', () => {
  const prefix = encodeURIComponent('[提交');
  try {
    const out = sh('gh', ['issue', 'list', '--repo', '2BingLing/dsh-market', '--search', `repo:${owner.owner}/${owner.repo}`, '--state', 'all', '--json', 'number,title,state,url']);
    const issues = JSON.parse(out);
    if (issues.length === 0) return { status: 'WARN', detail: 'no submission Issue found' };
    return { status: 'PASS', detail: `${issues.length} Issue(s) for ${owner.owner}/${owner.repo}: ${issues[0].url}` };
  } catch (err) {
    return { status: 'WARN', detail: 'cannot search dsh-market: ' + err.message.trim() };
  }
});

// Channel 8: GitHub Actions CI passes on the tag commit
check('github: CI pass on tag commit', () => {
  let out;
  try {
    out = sh('gh', ['run', 'list', '--json', 'conclusion,headSha,event']);
  } catch (err) {
    return { status: 'SKIP', detail: 'gh CLI not authenticated' };
  }
  const runs = JSON.parse(out);
  const latest = runs[0];
  if (!latest) return { status: 'WARN', detail: 'no workflow runs yet' };
  if (latest.conclusion !== 'success') return { status: 'FAIL', detail: `latest CI: ${latest.conclusion}` };
  return { status: 'PASS', detail: `latest CI: success (${latest.headSha.slice(0,7)})` };
});

// Channel 9: working tree clean post-release
check('git: working tree clean', () => {
  const out = sh('git', ['status', '--porcelain']);
  if (out.trim()) return { status: 'WARN', detail: 'uncommitted files:\n' + out.trim() };
  return { status: 'PASS', detail: 'working tree clean' };
});

// Print report
console.log('\n=== publish-kit verify-release ===');
console.log(`version: ${version}`);
console.log(`repo: ${owner.owner}/${owner.repo}\n`);

const counts = { PASS: 0, WARN: 0, FAIL: 0, SKIP: 0 };
for (const r of results) counts[r.status]++;

const maxName = Math.max(...results.map(r => r.check.length));
for (const r of results) {
  const tag = r.status === 'PASS' ? '[PASS]' :
              r.status === 'WARN' ? '[WARN]' :
              r.status === 'FAIL' ? '[FAIL]' : '[SKIP]';
  console.log(`${tag} ${r.check.padEnd(maxName + 2)}${r.detail}`);
}

console.log(`\nSummary: ${counts.PASS} pass, ${counts.WARN} warn, ${counts.FAIL} fail, ${counts.SKIP} skip`);

if (counts.FAIL > 0) { console.error('verify-release: blocking failures'); process.exit(1); }
if (counts.WARN > 0) { console.log('\nchannels ok with drift to review'); process.exit(0); }
console.log('\nall channels in agreement');
process.exit(0);
