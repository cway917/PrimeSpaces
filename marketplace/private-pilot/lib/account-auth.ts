import { env } from 'cloudflare:workers';
import { cookies } from 'next/headers';

export const SESSION_COOKIE = '__Host-primespaces-session';
export const SESSION_SECONDS = 3600;
export const authConfig = () => env as unknown as Record<string, string>;
export const usesAccountLogin = () => authConfig().PRIMESPACES_AUTH_PROVIDER === 'supabase';

export async function authRequest(path: string, init: RequestInit = {}) {
  const c = authConfig();
  if (!c.SUPABASE_URL || !c.SUPABASE_PUBLISHABLE_KEY) throw new Error('Account sign-in is not configured yet.');
  const headers = new Headers(init.headers);
  headers.set('apikey', c.SUPABASE_PUBLISHABLE_KEY);
  headers.set('Content-Type', 'application/json');
  return fetch(c.SUPABASE_URL + '/auth/v1/' + path, { ...init, headers, cache: 'no-store', signal: AbortSignal.timeout(15000) });
}

export async function verifiedAccount() {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) return null;
  const r = await authRequest('user', { headers: { Authorization: 'Bearer ' + token } });
  if (!r.ok) return null;
  const user = await r.json() as { id?: string; email?: string; email_confirmed_at?: string };
  if (!user.id || !user.email || !user.email_confirmed_at) return null;
  return { token, user };
}

export async function accountMarketplace(token: string, action: string, payload: unknown = {}) {
  const c = authConfig();
  const r = await fetch(c.SUPABASE_URL + '/rest/v1/rpc/primespaces_account', {
    method: 'POST', headers: { 'Content-Type': 'application/json', apikey: c.SUPABASE_PUBLISHABLE_KEY, Authorization: 'Bearer ' + token },
    body: JSON.stringify({ p_action: action, p: payload }),
    cache: 'no-store', signal: AbortSignal.timeout(15000),
  });
  const data: any = await r.json();
  if (!r.ok && (r.status === 401 || data.message === 'Sign in is required')) throw new Error('SIGN_IN_REQUIRED');
  if (!r.ok) throw new Error(data.message || 'Your account could not access the private marketplace.');
  return data;
}

export function sameOrigin(request: Request) { return request.headers.get('origin') === new URL(request.url).origin; }
export const sessionCookie = (token: string, seconds = SESSION_SECONDS) => `${SESSION_COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${seconds}`;
