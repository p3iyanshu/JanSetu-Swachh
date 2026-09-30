// Builds ../dashboard into ./app so it can be bundled into the Electron app.
// Set JANSETU_API_BASE_URL to change the backend address baked in as the
// default (admins can still change it from the login screen).
import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const dashboard = path.resolve(here, '..', '..', 'dashboard');
const outDir = path.resolve(here, '..', 'app');

if (!existsSync(path.join(dashboard, 'node_modules'))) {
  execSync('npm install', { cwd: dashboard, stdio: 'inherit' });
}

execSync(`npx vite build --outDir "${outDir}" --emptyOutDir`, {
  cwd: dashboard,
  stdio: 'inherit',
  env: {
    ...process.env,
    VITE_API_BASE_URL: process.env.JANSETU_API_BASE_URL || 'http://localhost:8000/api/v1',
    // The exe serves its own copy of the site, so point it at the server.json
    // published on the live website to learn the current backend address.
    VITE_CONFIG_URL: process.env.JANSETU_CONFIG_URL || 'https://jansetu-swachh.netlify.app/server.json',
  },
});
