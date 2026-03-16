#!/usr/bin/env node
// Bundle MoonBit JS output into a standalone Node.js CLI script
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '_build', 'js', 'release', 'build', 'cmd', 'actrun', 'actrun.js');
const srcDebug = path.join(__dirname, '..', '_build', 'js', 'debug', 'build', 'cmd', 'actrun', 'actrun.js');
const dist = path.join(__dirname, '..', 'dist', 'actrun.js');

const input = fs.existsSync(src) ? src : srcDebug;
if (!fs.existsSync(input)) {
  console.error('Build output not found. Run: moon build src/cmd/actrun --target js');
  process.exit(1);
}

fs.mkdirSync(path.dirname(dist), { recursive: true });

const content = fs.readFileSync(input, 'utf8');
const output = '#!/usr/bin/env node\n' + content;
fs.writeFileSync(dist, output);
fs.chmodSync(dist, 0o755);

console.log(`Bundled: ${dist}`);
