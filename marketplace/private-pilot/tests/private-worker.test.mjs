// Run after npm run build:cloudflare. No credentials or real user records are used.
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from 'node:net';

const portProbe = createServer();
portProbe.listen(0, '127.0.0.1');
await once(portProbe, 'listening');
const port = portProbe.address().port;
await new Promise(resolve => portProbe.close(resolve));
const worker = spawn(process.execPath, ['node_modules/wrangler/bin/wrangler.js', 'dev', '--config', 'dist/server/wrangler.json', '--local', '--ip', '127.0.0.1', '--port', String(port), '--inspector-port', '0'], {
  stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, WRANGLER_SEND_METRICS: 'false' },
});
let recent = '';
try {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Local Worker did not become ready: ' + recent.slice(-1200))), 45000);
    const output = chunk => {
      recent = (recent + chunk).slice(-6000);
      if (recent.includes('Ready on http://127.0.0.1:')) { clearTimeout(timer); resolve(); }
    };
    worker.stdout.on('data', output); worker.stderr.on('data', output);
    worker.once('error', error => { clearTimeout(timer); reject(error); });
    worker.once('exit', code => { clearTimeout(timer); reject(new Error('Worker exited before readiness: ' + code + ' ' + recent.slice(-1200))); });
  });
  for (const path of ['/', '/signin', '/api/marketplace', '/primespaces-logo.png', '/hall.jpg']) {
    const response = await fetch(`http://127.0.0.1:${port}${path}`, {
      headers: { 'Cf-Access-Authenticated-User-Email': 'carla@primespaces.org', 'oai-authenticated-user-email': 'cway781@gmail.com', 'oai-authenticated-user-id': 'forged-admin' }, signal: AbortSignal.timeout(5000),
    });
    assert.equal(response.status, 403, path + ' was reachable without verified Access');
    assert.match(response.headers.get('cache-control'), /no-store/);
    assert.match(response.headers.get('x-robots-tag'), /noindex/);
    console.log('PASS private runtime: ' + path);
  }
} finally {
  worker.kill('SIGTERM');
  worker.stdin.end();
}
