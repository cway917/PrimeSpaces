import { usesAccountLogin } from '@/lib/account-auth';
export const dynamic = 'force-dynamic';
export async function GET() {
  return Response.json({ mode: usesAccountLogin() ? 'supabase' : 'chatgpt' }, { headers: { 'Cache-Control': 'private, no-store' } });
}
