#!/usr/bin/env node
// postinstall.js - Symlink the bundled skill directory into the user's agent skill roots.
// Runs once when @eternalnight/publish-kit is installed via `npm install` or `dsh plugin add`.

const fs = require('fs');
const path = require('path');
const os = require('os');

const PACKAGE_SKILL_SRC = path.join(__dirname, '..', '.agents', 'skills', 'publish-kit');
const SKILL_NAME = 'publish-kit';

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
for (const dir of homes) {
    const dest = path.join(dir, SKILL_NAME);
    try {
        if (fs.existsSync(dest)) {
            const stat = fs.lstatSync(dest);
            if (stat.isSymbolicLink()) {
                fs.unlinkSync(dest);
            } else {
                // A real directory with the same name exists; skip (don't clobber).
                console.log('[publish-kit] ' + dest + ' already exists (not a symlink); skipping');
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
} else {
    console.log('[publish-kit] no skill-root directories found; install manually via npx skills add');
}
