import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, SignJWT, exportJWK, createLocalJWKSet } from 'jose';
import { privateAccessAllowed } from '../lib/private-access.ts';

const { publicKey, privateKey } = await generateKeyPair('RS256');
const jwk = await exportJWK(publicKey);
const keys = createLocalJWKSet({ keys: [{ ...jwk, kid: 'qa-only', alg: 'RS256' }] });
const config = { TEAM_DOMAIN: 'https://test-team.cloudflareaccess.com', POLICY_AUD: 'private-primespaces', PILOT_ALLOWED_EMAILS: 'carla@primespaces.org' };
async function token(overrides = {}) {
  return new SignJWT({ type: 'app', email: 'carla@primespaces.org', ...overrides })
    .setProtectedHeader({ alg: 'RS256', kid: 'qa-only' }).setIssuedAt()
    .setIssuer(config.TEAM_DOMAIN).setAudience(config.POLICY_AUD).setExpirationTime('5m')
    .sign(privateKey);
}
const request = value => new Request('https://private.example/', { headers: value ? { 'Cf-Access-Jwt-Assertion': value } : {} });

test('allows only a valid signed, configured pilot identity', async () => {
  assert.equal(await privateAccessAllowed(request(await token()), config, keys), true);
  assert.equal(await privateAccessAllowed(request(await token({ email: 'CARLA@PRIMESPACES.ORG' })), config, keys), true);
});
test('denies missing configuration and spoofed identity headers', async () => {
  const jwt = await token();
  for (const removed of ['TEAM_DOMAIN', 'POLICY_AUD', 'PILOT_ALLOWED_EMAILS']) {
    assert.equal(await privateAccessAllowed(request(jwt), { ...config, [removed]: '' }, keys), false);
  }
  assert.equal(await privateAccessAllowed(new Request('https://private.example/', { headers: { 'Cf-Access-Authenticated-User-Email': 'carla@primespaces.org', 'oai-authenticated-user-email': 'cway781@gmail.com' } }), config, keys), false);
  assert.equal(await privateAccessAllowed(request(jwt), { ...config, TEAM_DOMAIN: 'https://attacker.example' }, keys), false);
});
test('denies outsiders, non-app assertions, malformed and tampered tokens', async () => {
  const valid = await token();
  for (const value of [await token({ email: 'outsider@example.test' }), await token({ type: 'service' }), '', 'not-a-jwt', valid.slice(0, -10) + 'corrupted', 'x'.repeat(16385)]) {
    assert.equal(await privateAccessAllowed(request(value), config, keys), false);
  }
});
test('denies incorrect audience, issuer, expired tokens and missing expiry', async () => {
  for (const options of [{ aud: 'other-app' }, { iss: 'https://other.cloudflareaccess.com' }, { exp: 1 }]) {
    const jwt = await new SignJWT({ email: 'carla@primespaces.org', type: 'app', aud: config.POLICY_AUD, iss: config.TEAM_DOMAIN, exp: Math.floor(Date.now()/1000)+300, iat: Math.floor(Date.now()/1000), ...options }).setProtectedHeader({ alg: 'RS256', kid: 'qa-only' }).sign(privateKey);
    assert.equal(await privateAccessAllowed(request(jwt), config, keys), false);
  }
  const noExpiry = await new SignJWT({ type: 'app', email: 'carla@primespaces.org' }).setIssuer(config.TEAM_DOMAIN).setAudience(config.POLICY_AUD).setIssuedAt().setProtectedHeader({ alg: 'RS256', kid: 'qa-only' }).sign(privateKey);
  assert.equal(await privateAccessAllowed(request(noExpiry), config, keys), false);
});
