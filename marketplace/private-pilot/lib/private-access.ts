import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';

export type AccessConfig = Record<string, string | undefined>;
const keySets = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

// Always required on the independent host, including static assets and previews.
// Never trust an email header or a decoded, unverified JWT.
export async function privateAccessAllowed(request: Request, config: AccessConfig, testKeys?: JWTVerifyGetKey): Promise<boolean> {
  const team = config.TEAM_DOMAIN?.replace(/\/$/, '');
  const audience = config.POLICY_AUD;
  const allowed = (config.PILOT_ALLOWED_EMAILS || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
  if (!team || !/^https:\/\/[a-z0-9-]+\.cloudflareaccess\.com$/.test(team) || !audience || !allowed.length) return false;
  const token = request.headers.get('Cf-Access-Jwt-Assertion');
  if (!token || token.length > 16384) return false;
  try {
    let keys = testKeys || keySets.get(team);
    if (!keys) {
      const remoteKeys = createRemoteJWKSet(new URL(team + '/cdn-cgi/access/certs'), { timeoutDuration: 5000 });
      if (keySets.size >= 4) keySets.clear();
      keySets.set(team, remoteKeys);
      keys = remoteKeys;
    }
    const { payload } = await jwtVerify(token, keys, { issuer: team, audience, algorithms: ['RS256'], requiredClaims: ['exp', 'iat', 'email'] });
    return payload.type === 'app' && typeof payload.email === 'string' && allowed.includes(payload.email.toLowerCase());
  } catch { return false; }
}
