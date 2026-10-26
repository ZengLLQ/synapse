import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const rootDir = path.resolve(__dirname, '..');
const backendSrcDir = path.join(rootDir, 'backend');
const targetResourceDir = path.join(rootDir, 'desktop', 'src-tauri', 'resources', 'backend');

function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return;
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const file of fs.readdirSync(src)) {
      copyRecursive(path.join(src, file), path.join(dest, file));
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

console.log(`[sync-backend-resources] Synchronizing backend to ${targetResourceDir}...`);

// Ensure clean target
if (fs.existsSync(targetResourceDir)) {
  fs.rmSync(targetResourceDir, { recursive: true, force: true });
}
fs.mkdirSync(targetResourceDir, { recursive: true });

// Copy Project.toml, Manifest.toml, and src directory
copyRecursive(path.join(backendSrcDir, 'Project.toml'), path.join(targetResourceDir, 'Project.toml'));
copyRecursive(path.join(backendSrcDir, 'Manifest.toml'), path.join(targetResourceDir, 'Manifest.toml'));
copyRecursive(path.join(backendSrcDir, 'src'), path.join(targetResourceDir, 'src'));

console.log('[sync-backend-resources] Backend resources synchronized successfully.');
