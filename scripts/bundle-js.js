#!/usr/bin/env node
// Bundle MoonBit JS output into a standalone Node.js CLI script with minification
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

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
const originalSize = Buffer.byteLength(content);

// Minify with esbuild (available via npx)
const tmpInput = path.join(__dirname, '..', 'dist', '_tmp_input.js');
fs.writeFileSync(tmpInput, content);

try {
  execSync(
    `npx --yes esbuild ${tmpInput} --bundle --platform=node --target=node18 --minify --outfile=${dist}`,
    { stdio: 'inherit' }
  );
  // Prepend shebang (esbuild strips it)
  const minified = fs.readFileSync(dist, 'utf8');
  fs.writeFileSync(dist, '#!/usr/bin/env node\n' + minified);
} catch {
  // Fallback: no minification
  console.warn('esbuild not available, skipping minification');
  fs.writeFileSync(dist, '#!/usr/bin/env node\n' + content);
}

fs.unlinkSync(tmpInput);
fs.chmodSync(dist, 0o755);

const finalSize = Buffer.byteLength(fs.readFileSync(dist));
console.log(`Bundled: ${dist} (${(originalSize / 1024).toFixed(0)}KB -> ${(finalSize / 1024).toFixed(0)}KB)`);
