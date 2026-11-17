import { accountMarketplace, authRequest, sameOrigin, sessionCookie, SESSION_SECONDS, usesAccountLogin } from '@/lib/account-auth';
export const dynamic = 'force-dynamic';
const headers = { 'Cache-Control': 'private, no-store' };
export async function POST(request: Request) {
  if (!usesAccountLogin()) return Response.json({ error: 'Account sign-in is not enabled on this host.' }, { status: 404, headers });
  if (!sameOrigin(request) || !request.headers.get('content-type')?.startsWith('application/json')) return Response.json({ error: 'A same-origin JSON request is required.' }, { status: 403, headers });
  try {
    const raw = await request.text();
    if (raw.length > 6000) return Response.json({ error: 'Request too large.' }, { status: 413, headers });
    const { email, password } = JSON.parse(raw);
    if (typeof email !== 'string' || email.length > 254 || typeof password !== 'string' || !password || password.length > 1024) throw new Error('credentials');
    const r = await authRequest('token?grant_type=password', { method: 'POST', body: JSON.stringify({ email: email.trim(), password }) });
    const session: any = await r.json();
    if (!r.ok || typeof session.access_token !== 'string' || !session.user?.email_confirmed_at) throw new Error('credentials');
    // Membership is enforced before any session cookie is issued. Roles never come from metadata.
    try { await accountMarketplace(session.access_token, 'state'); }
    catch {
      await authRequest('logout?scope=local', { method: 'POST', headers: { Authorization: 'Bearer ' + session.access_token } }).catch(() => {});
      return Response.json({ error: 'This account has not been invited to the private marketplace. Contact info@primespaces.org.' }, { status: 403, headers });
    }
    return Response.json({ ok: true }, { headers: { ...headers, 'Set-Cookie': sessionCookie(session.access_token, Math.min(SESSION_SECONDS, Math.max(1, Number(session.expires_in) || SESSION_SECONDS))) } });
  } catch { return Response.json({ error: 'Unable to sign in. Check your email and password, or contact info@primespaces.org.' }, { status: 401, headers }); }
}
