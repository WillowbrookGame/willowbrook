// SPDX-License-Identifier: MIT
import {spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {join} from 'node:path';

const state = '/var/lib/willowbrook-family-desk-container';
const marker = join(state, '.willowbrook-family-desk-opt-in');
const username = process.argv[2];
if (process.argv.length !== 3 || !/^[a-zA-Z0-9_-]{3,20}$/.test(username ?? '') || process.stdin.isTTY) {
  console.error('Pass the owner name and a private password line via stdin.');
  process.exit(1);
}
try {
  writeFileSync(marker, 'willowbrook-local-family-desk-v1\n', {flag:'wx',mode:0o600});
} catch (error) {
  if (error.code !== 'EEXIST') {
    console.error('Could not initialize the private Family Desk marker.');
    process.exit(1);
  }
}
const child = spawnSync(process.execPath, [
  '/app/game/network/browser/parent_desk_setup.mjs',
  '--accounts-dir', state, '--parent-desk-file', marker, '--owner', username,
], {stdio:'inherit'});
process.exit(child.status ?? 1);
