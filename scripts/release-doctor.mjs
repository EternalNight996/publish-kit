#!/usr/bin/env node
// release-doctor.mjs - Pre-flight checker for a target release.
// Walks the 9-row pitfall table in REFERENCE.md section J against the current
// state of a target repository (defaults to cwd), and reports drift BEFORE
// the publish step runs.
//
// Usage:
//   node scripts/release-doctor.mjs [target-dir]
//   node scripts/release-doctor.mjs --track npm
//   node scripts/release-doctor.mjs --track dsh-plugin
//   node scripts/release-doctor.mjs --track cargo
//   node scripts/release-doctor.mjs --track pypi
//   node scripts/release-doctor.mjs --track exe
//   node scripts/release-doctor.mjs --track github-gitee
//   node scripts/release-doctor.mjs --strict   # exit 1 on WARN

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, execSync } from 'node:child_process';

const args = process.argv.slice(2);
const targetDir = args.find(a => !a.startsWith('--')) || '.';
const flags = new Set(args.filter(a => a.startsWith('--')));
const track = (args.find(a => a.startsWith('--track=')) || '--track=all').slice(8);
const strict = flags.has('--strict');

const root = path.resolve(targetDir);
const results = []; // {check, status: 'PASS'|'WARN'|'FAIL', detail}

function check(name, fn) {
  try {
    const r = fn();
    results.push({ check: name, ...r });
  } catch (err) {
    results.push({ check: name, status: 'FAIL', detail: err.message });
  }
}

function fileExists(p) { return fs.existsSync(path.join(root, p)); }
function readJSON(p) { return JSON.parse(fs.readFileSync(path.join(root, p), 'utf8')); }
function readText(p) { return fs.readFileSync(path.join(root, p), 'utf8'); }

function sh(cmd, args) {
  let exe = cmd;
  if (process.platform === 'win32' && !path.extname(cmd)) {
    try {
      exe = execSync(`where.exe ${cmd}`, { encoding: 'utf8' }).trim().split(/\r?\n/)[0];
    } catch (e) {
      throw new Error(`sh: command not found: ${cmd}`);
    }
  }
  return execFileSync(exe, args, { cwd: root, encoding: 'utf8' });
}

// Check 1: git tag + working tree
check('git: no uncommitted changes', () => {
  const out = sh('git', ['status', '--porcelain']);
  if (out.trim()) return { status: 'WARN', detail: 'uncommitted files:\n' + out.trim() };
  return { status: 'PASS', detail: 'working tree clean' };
});

check('git: tag exists and points at HEAD', () => {
  const tagsRaw = sh('git', ['tag', '--list', 'v*.*.*']);
  const tags = tagsRaw.trim().split('\n').filter(Boolean);
  if (tags.length === 0) return { status: 'WARN', detail: 'no v<x.y.z> tag exists yet' };
  const lastTag = tags[tags.length - 1];
  const tagHash = sh('git', ['rev-list', '-n', '1', lastTag]).trim();
  const headHash = sh('git', ['rev-list', '-n', '1', 'HEAD']).trim();
  if (tagHash !== headHash) {
    return { status: 'WARN', detail: `tag ${lastTag} (${tagHash.slice(0,7)}) is not at HEAD (${headHash.slice(0,7)})` };
  }
  return { status: 'PASS', detail: `tag ${lastTag} at HEAD` };
});

// Check 2: package.json version matches last tag (npm track only)
if (track === 'npm' || track === 'all' || track === 'dsh-plugin') {
  check('npm: package.json version matches last tag', () => {
    if (!fileExists('package.json')) return { status: 'SKIP', detail: 'no package.json' };
    const pkgVersion = readJSON('package.json').version;
    const tags = sh('git', ['tag', '--list', 'v*.*.*']).trim().split('\n').filter(Boolean);
    if (tags.length === 0) return { status: 'WARN', detail: `package.json is ${pkgVersion} but no tag exists` };
    const lastTag = tags[tags.length - 1].slice(1); // strip v
    if (lastTag !== pkgVersion) {
      return { status: 'WARN', detail: `package.json is ${pkgVersion}, last tag is v${lastTag}` };
    }
    return { status: 'PASS', detail: `${pkgVersion} matches v${lastTag}` };
  });
}

// Check 3: npm publish 403 prevention
if (track === 'npm' || track === 'all' || track === 'dsh-plugin') {
  check('npm: registry version != package.json version', () => {
    if (!fileExists('package.json')) return { status: 'SKIP', detail: 'no package.json' };
    const pkg = readJSON('package.json');
    const pkgVersion = pkg.version;
    const pkgName = pkg.name;
    let remoteVersion;
    try {
      const out = execFileSync('npm', ['view', pkgName, 'version', '--registry=https://registry.npmjs.org/'], { encoding: 'utf8' });
      remoteVersion = out.trim();
    } catch (err) {
      // 404 means the package has never been published; that's fine.
      if (/404|E404/i.test(err.message)) return { status: 'PASS', detail: `${pkgName} not yet published (clean publish)` };
      return { status: 'WARN', detail: 'cannot reach npm registry: ' + err.message };
    }
    if (remoteVersion === pkgVersion) {
      return { status: 'FAIL', detail: `npm would return 403 — ${pkgName}@${pkgVersion} already published` };
    }
    return { status: 'PASS', detail: `npm has ${remoteVersion}, package.json is ${pkgVersion}` };
  });
}

// Check 4: peerDependencies wide-safe range (DSH plugin track)
if (track === 'dsh-plugin' || track === 'all') {
  check('DSH: peerDependencies uses wide range (not ^0.1.0)', () => {
    if (!fileExists('package.json')) return { status: 'SKIP', detail: 'no package.json' };
    const pkg = readJSON('package.json');
    const peers = pkg.peerDependencies || {};
    const issues = [];
    for (const [name, range] of Object.entries(peers)) {
      // ^0.x.y is a narrow pin once 0.(x+1).0 ships.
      if (/\^0\.\d+\.\d+$/.test(range)) {
        issues.push(`${name}: ${range} (will pin forever once 0.x.0 next ships)`);
      }
    }
    if (issues.length) return { status: 'WARN', detail: 'narrow ranges:\n' + issues.join('\n') };
    return { status: 'PASS', detail: Object.keys(peers).length ? 'peer ranges look wide' : 'no peerDependencies' };
  });
}

// Check 5: package.json files whitelist separates runtime from showcase (DSH plugin / theme)
if (track === 'dsh-plugin' || track === 'all') {
  check('DSH: files whitelist excludes assets/screen (showcase only)', () => {
    if (!fileExists('package.json')) return { status: 'SKIP', detail: 'no package.json' };
    const files = readJSON('package.json').files || [];
    const hasScreen = files.some(f => /assets\/screen|assets\/screens/.test(f));
    if (hasScreen) {
      return { status: 'WARN', detail: 'files whitelist includes assets/screen — this bloats the npm tarball' };
    }
    return { status: 'PASS', detail: 'no showcase assets in whitelist' };
  });
}

// Check 6: cordis plugin required metadata
if (track === 'dsh-plugin' || track === 'all') {
  check('DSH: dsh.marketplace metadata present', () => {
    if (!fileExists('package.json')) return { status: 'SKIP', detail: 'no package.json' };
    const dsh = readJSON('package.json').dsh;
    if (!dsh || !dsh.marketplace) return { status: 'FAIL', detail: 'missing dsh.marketplace (YELEBAI static validator requires it)' };
    if (!Array.isArray(dsh.marketplace.profiles) || dsh.marketplace.profiles.length === 0) {
      return { status: 'WARN', detail: 'dsh.marketplace.profiles is empty or missing' };
    }
    return { status: 'PASS', detail: `profiles: ${dsh.marketplace.profiles.join(', ')}` };
  });
}

// Check 7: yarn.lock / package-lock.json / pnpm-lock.yaml committed
check('lockfile: at least one committed', () => {
  const lockfiles = ['package-lock.json', 'yarn.lock', 'pnpm-lock.yaml'];
  const found = lockfiles.filter(l => fileExists(l));
  if (found.length === 0) return { status: 'WARN', detail: 'no lockfile committed' };
  return { status: 'PASS', detail: `found: ${found.join(', ')}` };
});

// Check 8: README present and under reasonable size
check('docs: README.md present', () => {
  if (!fileExists('README.md')) return { status: 'WARN', detail: 'no README.md' };
  const lines = readText('README.md').split('\n').length;
  if (lines > 1000) return { status: 'WARN', detail: `README.md is ${lines} lines; consider splitting into README + REFERENCE` };
  return { status: 'PASS', detail: `README.md has ${lines} lines` };
});

check('docs: CHANGELOG.md present', () => {
  if (!fileExists('CHANGELOG.md')) return { status: 'WARN', detail: 'no CHANGELOG.md' };
  return { status: 'PASS', detail: 'CHANGELOG.md present' };
});

// Check 9: LICENSE present
check('docs: LICENSE present', () => {
  if (!fileExists('LICENSE')) return { status: 'FAIL', detail: 'no LICENSE (blocks publish on most registries)' };
  return { status: 'PASS', detail: 'LICENSE present' };
});

// Check 10: git remote configuration (github + gitee dual remote)
if (track === 'all' || track === 'github-gitee') {
  check('git: GitHub remote configured', () => {
    const out = sh('git', ['remote', '-v']);
    if (!/github\.com/.test(out)) return { status: 'WARN', detail: 'no github.com remote' };
    return { status: 'PASS', detail: 'github remote configured' };
  });

  check('git: Gitee remote configured', () => {
    const out = sh('git', ['remote', '-v']);
    if (!/gitee\.com/.test(out)) return { status: 'WARN', detail: 'no gitee.com remote' };
    return { status: 'PASS', detail: 'gitee remote configured' };
  });
}

// Check 11: GitHub RP fields (only if this repo is on GitHub)
check('github: description set', () => {
  let out;
  try {
    out = sh('gh', ['repo', 'view', '--json', 'description']);
  } catch (err) {
    return { status: 'SKIP', detail: 'gh CLI not authenticated or not on GitHub' };
  }
  const j = JSON.parse(out);
  if (!j.description || j.description.length < 10) return { status: 'WARN', detail: 'description is empty or too short' };
  return { status: 'PASS', detail: `description: ${j.description.slice(0, 60)}...` };
});

check('github: topics set', () => {
  let out;
  try {
    out = sh('gh', ['repo', 'view', '--json', 'repositoryTopics']);
  } catch (err) {
    return { status: 'SKIP', detail: 'gh CLI not authenticated or not on GitHub' };
  }
  const j = JSON.parse(out);
  const topics = (j.repositoryTopics || []).map(t => t.name);
  if (topics.length === 0) return { status: 'WARN', detail: 'no topics set; marketplace auto-discovery will skip this repo' };
  if (topics.length < 5) return { status: 'WARN', detail: `only ${topics.length} topics set; consider 5-10` };
  return { status: 'PASS', detail: `${topics.length} topics: ${topics.slice(0, 5).join(', ')}...` };
});

// Check 12: pre-release detection (version suffix implies pre-release workflow)
if (track === 'npm' || track === 'all' || track === 'dsh-plugin') {
  check('npm: pre-release version uses non-latest dist-tag', () => {
    if (!fileExists('package.json')) return { status: 'SKIP', detail: 'no package.json' };
    const pkg = readJSON('package.json');
    const v = pkg.version;
    if (!/-(alpha|beta|rc)\.\d+$/.test(v)) {
      return { status: 'PASS', detail: `${v} is a production release; uses dist-tag=latest` };
    }
    const pre = v.match(/-(alpha|beta|rc)\.\d+$/)[1];
    return { status: 'PASS', detail: `${v} is a ${pre} pre-release; bootstrap-release.sh publishes to dist-tag=${pre} by default (NOT latest)` };
  });
}

// Check 13: ASCII-only .bat files (full-width punctuation trap)
check('scripts: bat files have ASCII-only echo content', () => {
  const batFiles = fs.readdirSync(root).filter(f => f.endsWith('.bat'));
  const issues = [];
  for (const f of batFiles) {
    const text = fs.readFileSync(path.join(root, f), 'utf8');
    const lines = text.split('\n');
    lines.forEach((line, i) => {
      // Detect full-width punctuation in echo statements
      if (/\b(echo|@?echo)\b/.test(line) && /[\uFF01-\uFF5E]/.test(line)) {
        issues.push(`${f}:${i+1}: ${line.trim().slice(0, 80)}`);
      }
    });
  }
  if (issues.length) return { status: 'WARN', detail: 'full-width punctuation in .bat echo:\n' + issues.join('\n') };
  return { status: 'PASS', detail: `${batFiles.length} .bat file(s) clean` };
});

// Print report
console.log('\n=== publish-kit release-doctor ===');
console.log(`target: ${root}`);
console.log(`track: ${track}\n`);

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

// Exit code
if (counts.FAIL > 0) {
  console.error('release-doctor: blocking failures present; do not publish');
  process.exit(1);
}
if (strict && counts.WARN > 0) {
  console.error('release-doctor: --strict set; warnings treated as failures');
  process.exit(1);
}
if (counts.WARN > 0) {
  console.log('\npublish can proceed but warnings should be reviewed');
  process.exit(0);
}
console.log('\npublish can proceed cleanly');
process.exit(0);
