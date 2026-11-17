import { cookies } from 'next/headers';
import { authRequest, sameOrigin, sessionCookie, SESSION_COOKIE, usesAccountLogin } from '@/lib/account-auth';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  if (!usesAccountLogin() || !sameOrigin(request)) return new Response('Forbidden', { status: 403 });
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (token) await authRequest('logout?scope=local', { method: 'POST', headers: { Authorization: 'Bearer ' + token } }).catch(() => {});
  return new Response(null, { status: 303, headers: { Location: '/signin', 'Set-Cookie': sessionCookie('', 0), 'Cache-Control': 'private, no-store' } });
}
