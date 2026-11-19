#!/usr/bin/env node
// self-check.mjs - local mirror of .github/workflows/ci.yml, runnable as `npm test`.
// Every release script calls `npm test` first, so a red check here blocks publishing.
//
// Checks:
//   1. package.json carries the fields the registries / marketplace listings need
//   2. SKILL.md stays within the house format (<= 100 lines, valid frontmatter, "Use when" trigger)
//   3. version is identical across package.json and the host plugin manifests
//   4. every internal markdown link under the skill directory resolves
//   5. CHANGELOG.md has an entry for the current version (release notes are extracted from it)
//   6. no skill document is missing from package.json#files (the tarball is whitelist-driven)

import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const exists = (p) => fs.existsSync(path.join(root, p));

let failures = 0;
const ok = (msg) => console.log(`  ok   ${msg}`);
const bad = (msg) => { failures += 1; console.error(`  FAIL ${msg}`); };

const pkg = JSON.parse(read('package.json'));

// 1. required package fields
for (const key of ['name', 'version', 'description', 'license', 'repository', 'publishConfig']) {
  if (!pkg[key]) bad(`package.json missing "${key}"`);
}
if (!pkg.dsh || !pkg.dsh.marketplace) bad('package.json missing dsh.marketplace metadata');
if (!failures) ok(`package.json fields present (${pkg.name}@${pkg.version})`);

// 2. SKILL.md house format
const skillRel = '.agents/skills/publish-kit/SKILL.md';
if (!exists(skillRel)) {
  bad(`${skillRel} missing`);
} else {
  const skill = read(skillRel);
  const lines = skill.split('\n').length;
  if (lines > 100) bad(`${skillRel} is ${lines} lines (house limit 100)`);
  const fm = skill.split(/^---$/m)[1] || '';
  if (!/^name:/m.test(fm)) bad('SKILL.md frontmatter missing name:');
  if (!/^description:/m.test(fm)) bad('SKILL.md frontmatter missing description:');
  else {
    const desc = (fm.match(/^description:\s*([\s\S]*?)$/m) || [, ''])[1].trim();
    if (desc.length > 1024) bad(`SKILL.md description is ${desc.length} chars (limit 1024)`);
    if (!/Use when/.test(desc)) bad('SKILL.md description missing "Use when" trigger clause');
  }
  if (!failures) ok(`SKILL.md format ok (${lines} lines)`);
}

// 3. version sync across manifests
const manifests = [
  ['.claude-plugin/plugin.json', (j) => j.version],
  ['.claude-plugin/marketplace.json', (j) => j.plugins?.[0]?.version]
];
for (const [file, pick] of manifests) {
  if (!exists(file)) continue;
  const v = pick(JSON.parse(read(file)));
  if (v !== pkg.version) bad(`version drift: ${file} is ${v}, package.json is ${pkg.version}`);
}
if (!manifests.some(([f]) => exists(f))) ok('no host manifests to check');
else if (!failures) ok(`manifest versions match ${pkg.version}`);

// 4. internal markdown links under the skill directory
const skillDir = path.join(root, '.agents/skills/publish-kit');
const linkTargets = ['.agents/skills/publish-kit/SKILL.md', 'README.md', 'README.zh.md'];
for (const f of fs.readdirSync(skillDir)) {
  if (f.endsWith('.md') && f !== 'SKILL.md') linkTargets.push(path.join('.agents/skills/publish-kit', f));
}
let brokenLinks = 0;
for (const rel of linkTargets) {
  if (!exists(rel)) continue;
  // README-DESIGN.md intentionally embeds a README template whose links point at a TARGET repo
  if (rel.endsWith('README-DESIGN.md')) continue;
  const base = path.dirname(path.join(root, rel));
  for (const m of read(rel).matchAll(/\]\((?!https?:\/\/|mailto:|#)([^)]+)\)/g)) {
    const target = m[1].split('#')[0];
    if (!target) continue;
    if (!fs.existsSync(path.resolve(base, target))) {
      bad(`broken link in ${rel}: ${m[1]}`);
      brokenLinks += 1;
    }
  }
}
if (!brokenLinks) ok('internal markdown links resolve');

// 5. CHANGELOG entry for the current version
if (!exists('CHANGELOG.md')) bad('CHANGELOG.md missing');
else if (!read('CHANGELOG.md').includes(`## [${pkg.version}]`)) {
  bad(`CHANGELOG.md has no "## [${pkg.version}]" section (release notes come from it)`);
} else ok(`CHANGELOG.md has an entry for ${pkg.version}`);

// 6. every skill document shipped in the tarball
const files = pkg.files || [];
for (const f of fs.readdirSync(skillDir)) {
  if (!f.endsWith('.md')) continue;
  const rel = `.agents/skills/publish-kit/${f}`;
  if (!files.includes(rel)) bad(`${rel} missing from package.json#files (npm tarball would skip it)`);
}
if (!failures) ok('skill documents all listed in package.json#files');

console.log('');
if (failures) {
  console.error(`self-check: ${failures} failure(s) — do not publish until fixed`);
  process.exit(1);
}
console.log(`self-check: all green (${pkg.name}@${pkg.version})`);
