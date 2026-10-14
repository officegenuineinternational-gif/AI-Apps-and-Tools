import fs from 'node:fs';
import path from 'node:path';

const runtime = process.argv[2];
if (!runtime) throw new Error('Usage: node Prepare-Paperclip-Windows.mjs <runtime-directory>');

async function normalizeSourceLineEndings(root) {
  const pending = [root];
  while (pending.length > 0) {
    const directory = pending.pop();
    for (const entry of await fs.promises.readdir(directory, { withFileTypes: true })) {
      if (entry.isSymbolicLink()) continue;
      const filePath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        if (entry.name !== 'node_modules' && entry.name !== '.git') pending.push(filePath);
        continue;
      }
      if (!entry.isFile()) continue;
      const bytes = await fs.promises.readFile(filePath);
      if (bytes.includes(0)) continue;
      const text = bytes.toString('utf8');
      if (!Buffer.from(text, 'utf8').equals(bytes) || !text.includes('\\r\\n')) continue;
      await fs.promises.writeFile(filePath, text.replace(/\\r\\n/g, '\\n'), 'utf8');
    }
  }
}

await normalizeSourceLineEndings(runtime);

const packageDir = path.join(runtime, 'packages', 'shared');
const manifestPath = path.join(packageDir, 'package.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const upstreamBuild = 'tsc && mkdir -p dist/cliplab && cp src/cliplab/LICENSE src/cliplab/PROVENANCE.md dist/cliplab/';
const windowsBuild = 'tsc && node scripts/genuine-copy-cliplab-assets.mjs';

if (manifest.scripts?.build !== upstreamBuild && manifest.scripts?.build !== windowsBuild) {
  throw new Error('Paperclip shared package build script differs from the pinned upstream version; refusing to patch it.');
}
manifest.scripts.build = windowsBuild;
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n', 'utf8');

const helperPath = path.join(packageDir, 'scripts', 'genuine-copy-cliplab-assets.mjs');
fs.mkdirSync(path.dirname(helperPath), { recursive: true });
fs.writeFileSync(helperPath, `import { copyFile, mkdir } from 'node:fs/promises';
import path from 'node:path';

const source = path.resolve('src', 'cliplab');
const destination = path.resolve('dist', 'cliplab');
await mkdir(destination, { recursive: true });
for (const name of ['LICENSE', 'PROVENANCE.md']) {
  await copyFile(path.join(source, name), path.join(destination, name));
}
`, 'utf8');
