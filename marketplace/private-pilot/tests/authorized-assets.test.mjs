// Exercise the built production Worker with a local, test-only Access issuer.
// Outbound calls are mocked; no real identity, secrets, email or data is used.
import { Miniflare, Response as MiniflareResponse } from 'miniflare';
import { generateKeyPair, SignJWT, exportJWK } from 'jose';
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { readdir } from 'node:fs/promises';

const { publicKey, privateKey } = await generateKeyPair('RS256');
const jwk = await exportJWK(publicKey);
const team = 'https://qa-primespaces.cloudflareaccess.com';
const audience = 'qa-primespaces-assets';
const token = await new SignJWT({ type: 'app', email: 'carla@primespaces.org' })
  .setProtectedHeader({ alg: 'RS256', kid: 'qa-only' }).setIssuedAt()
  .setIssuer(team).setAudience(audience).setExpirationTime('5m').sign(privateKey);
const serverRoot = resolve('dist/server');
const modulePaths = (await readdir(serverRoot, { recursive: true })).filter(p => p.endsWith('.js') && p !== 'index.js');
const mf = new Miniflare({
  modules: ['index.js', ...modulePaths].map(p => ({ type: 'ESModule', path: resolve(serverRoot, p) })),
  modulesRoot: serverRoot,
  compatibilityDate: '2026-05-15', compatibilityFlags: ['nodejs_compat'], cf: false,
  bindings: { PRIMESPACES_AUTH_PROVIDER: 'supabase', PILOT_ALLOWED_EMAILS: 'carla@primespaces.org', TEAM_DOMAIN: team, POLICY_AUD: audience },
  assets: { directory: resolve('dist/client'), binding: 'ASSETS', routerConfig: { invoke_user_worker_ahead_of_assets: true, has_user_worker: true } },
  outboundService: async request => {
    if (request.url === team + '/cdn-cgi/access/certs') return new MiniflareResponse(JSON.stringify({ keys: [{ ...jwk, kid: 'qa-only', alg: 'RS256' }] }), { headers: { 'Content-Type': 'application/json' } });
    return new MiniflareResponse('No external services in this test', { status: 503 });
  },
});
try {
  const headers = { 'Cf-Access-Jwt-Assertion': token };
  let html = '';
  for (const page of ['/', '/signin']) {
    const response = await mf.dispatchFetch('https://private.example' + page, { headers });
    assert.equal(response.status, 200, 'Authorized page must render: ' + page);
    html += await response.text();
  }
  const css = [...html.matchAll(/href="([^"\s]+\.css(?:\?[^"\s]*)?)"/g)].map(m => m[1]);
  const scripts = [...html.matchAll(/(?:src|href)="([^"\s]+\.js(?:\?[^"\s]*)?)"/g)].map(m => m[1]);
  console.log(JSON.stringify({ stylesheets: css, scripts }));
  assert.ok(css.length, 'The page must include its stylesheet');
  assert.ok(scripts.length, 'The page must include JavaScript');
  for (const path of [...new Set([...css, ...scripts, '/primespaces-logo.png', '/hall.jpg'])]) {
    const asset = await mf.dispatchFetch(new URL(path, 'https://private.example/'), { headers });
    const type = asset.headers.get('content-type') || '';
    console.log(JSON.stringify({ path, status: asset.status, type }));
    assert.equal(asset.status, 200, 'Authorized asset unavailable: ' + path);
    const body = await asset.arrayBuffer();
    assert.ok(body.byteLength > 0, 'Asset body must not be empty');
    if (path.includes('.css')) { assert.match(type, /text\/css/); assert.match(new TextDecoder().decode(body), /\.app-shell|\.brand-logo/); }
    if (path.includes('.js')) assert.match(type, /javascript/);
    const denied = await mf.dispatchFetch(new URL(path, 'https://private.example/'));
    assert.equal(denied.status, 403, 'Assets must remain private: ' + path);
    await denied.text();
  }
  console.log('PASS: authorized HTML, CSS, JavaScript and images; unauthorized requests remain blocked');
} finally { await mf.dispose(); }
