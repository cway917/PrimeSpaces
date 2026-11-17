import { env } from 'cloudflare:workers';
import { getChatGPTUser } from '@/app/chatgpt-auth';
export async function marketplace(action: string, payload: unknown = {}) {
  const user = await getChatGPTUser();
  if (!user) throw new Error('SIGN_IN_REQUIRED');
  const config = env as unknown as Record<string,string>;
  if (!config.SUPABASE_URL || !config.SUPABASE_PUBLISHABLE_KEY || !config.PRIMESPACES_SERVER_TOKEN) throw new Error('The private database connection is not configured.');
  const response = await fetch(config.SUPABASE_URL + '/rest/v1/rpc/primespaces_pilot', {
    method: 'POST', headers: {'Content-Type':'application/json', apikey: config.SUPABASE_PUBLISHABLE_KEY},
    body: JSON.stringify({p_token:config.PRIMESPACES_SERVER_TOKEN,p_actor:user.userId,p_email:user.email,p_name:user.fullName || user.email,p_action:action,p:payload}),
    signal: AbortSignal.timeout(15000),
  });
  const data = await response.json() as any;
  if (!response.ok) throw new Error(data.message || 'The database could not complete this request.');
  return data;
}
