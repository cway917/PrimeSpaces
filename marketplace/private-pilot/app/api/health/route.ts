import {env} from 'cloudflare:workers';
export const dynamic='force-dynamic';
// Read-only connection check behind the owner-only Sites gate. Returns no records.
export async function GET(){
 try{
  const c=env as unknown as Record<string,string>;
  if(!c.SUPABASE_URL||!c.SUPABASE_PUBLISHABLE_KEY||!c.PRIMESPACES_SERVER_TOKEN)throw new Error('configuration');
  const r=await fetch(c.SUPABASE_URL+'/rest/v1/rpc/primespaces_pilot',{method:'POST',headers:{'Content-Type':'application/json',apikey:c.SUPABASE_PUBLISHABLE_KEY},body:JSON.stringify({p_token:c.PRIMESPACES_SERVER_TOKEN,p_actor:'sample-renter',p_email:'renter@example.test',p_name:'Sample community renter',p_action:'state',p:{}}),signal:AbortSignal.timeout(15000)});
  const data:any=await r.json();
  if(!r.ok||!Array.isArray(data.facilities))throw new Error('connection');
  return Response.json({connected:true,facilityCount:data.facilities.length,paymentsEnabled:false},{headers:{'Cache-Control':'private, no-store'}});
 }catch{return Response.json({connected:false,paymentsEnabled:false},{status:503,headers:{'Cache-Control':'private, no-store'}})}
}
