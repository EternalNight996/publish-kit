#!/usr/bin/env node
// postinstall.js - Symlink the bundled skill directory into the user's agent skill roots.
// Runs once when @eternalnight/publish-kit is installed via `npm install` or `dsh plugin add`.

const fs = require('fs');
const path = require('path');
const os = require('os');

const PACKAGE_SKILL_SRC = path.join(__dirname, '..', '.agents', 'skills', 'publish-kit');
const SKILL_NAME = 'publish-kit';
// npm_config_force / PUBLISH_KIT_FORCE=1 to re-link even if a link/junction already points here
const FORCE = process.env.PUBLISH_KIT_FORCE === '1'
    || (Array.isArray(process.env.npm_config_force) ? process.env.npm_config_force.includes('true') : process.env.npm_config_force === 'true');

function isJunction(p) {
    try {
        return (fs.lstatSync(p).attributes & 0x800) !== 0; // FILE_ATTRIBUTE_REPARSE_POINT
    } catch { return false; }
}
function readJunctionTarget(p) {
    try { return fs.realpathSync(p); } catch { return null; }
}

if (!fs.existsSync(PACKAGE_SKILL_SRC)) {
    console.warn('[publish-kit] bundled skill directory missing; skipping postinstall symlink');
    process.exit(0);
}

const homes = [
    path.join(os.homedir(), '.agents', 'skills'),
    path.join(os.homedir(), '.claude', 'skills'),
    path.join(os.homedir(), '.codex', 'skills'),
    path.join(os.homedir(), '.gemini', 'skills'),
    path.join(os.homedir(), '.dsh', 'skills'),
];

const linked = [];
const skipped = [];
for (const dir of homes) {
    const dest = path.join(dir, SKILL_NAME);
    try {
        if (fs.existsSync(dest)) {
            const stat = fs.lstatSync(dest);
            if (stat.isSymbolicLink()) {
                // existing symlink (rare on Windows; usually junctions) -> replace if FORCE
                if (FORCE) { fs.unlinkSync(dest); } else { skipped.push(dest); continue; }
            } else if (isJunction(dest)) {
                // Windows directory junction. If it already resolves to our source (or anywhere
                // that already serves this skill bundle), keep it -- Windows refuses EEXIST
                // when multiple junctions share the same source inode.
                const target = readJunctionTarget(dest);
                if (!FORCE && target && path.relative(PACKAGE_SKILL_SRC, target) === '') {
                    skipped.push(dest);
                    continue;
                }
                if (FORCE) {
                    try { fs.unlinkSync(dest); } catch { /* may still fail; re-link will try */ }
                } else {
                    skipped.push(dest);
                    continue;
                }
            } else {
                // A real directory with the same name exists; skip (don't clobber).
                console.log('[publish-kit] ' + dest + ' already exists (not a link); skipping');
                continue;
            }
        }
        fs.mkdirSync(dir, { recursive: true });
        fs.symlinkSync(PACKAGE_SKILL_SRC, dest, 'junction');
        linked.push(dest);
        console.log('[publish-kit] linked ' + dest + ' -> ' + PACKAGE_SKILL_SRC);
    } catch (err) {
        console.warn('[publish-kit] failed to link ' + dest + ': ' + err.message);
    }
}

if (linked.length > 0) {
    console.log('[publish-kit] installed skill bundle in ' + linked.length + ' location(s)');
}
if (skipped.length > 0) {
    console.log('[publish-kit] kept ' + skipped.length + ' existing link(s); set PUBLISH_KIT_FORCE=1 to overwrite');
}
if (linked.length === 0 && skipped.length === 0) {
    console.log('[publish-kit] no skill-root directories found; install manually via npx skills add');
}
