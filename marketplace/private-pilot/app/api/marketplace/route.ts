import { marketplace } from '@/lib/marketplace';
export const dynamic = 'force-dynamic';
const headers = {'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'};
function failure(error: unknown) {
 const message = error instanceof Error ? error.message : 'Something went wrong. Please try again.';
 return Response.json({error:message}, {status:message==='SIGN_IN_REQUIRED'?401:/access required|Access denied|invited|Identity mismatch/i.test(message)?403:400,headers});
}
export async function GET() {
 try { return Response.json(await marketplace('state'),{headers}); } catch(e) { return failure(e); }
}
export async function POST(request: Request) {
 try {
   const origin = request.headers.get('origin');
   if (!origin || origin !== new URL(request.url).origin) return Response.json({error:'A same-origin request is required.'},{status:403,headers});
   if (!(request.headers.get('content-type')||'').includes('application/json')) return Response.json({error:'JSON required'},{status:415,headers});
   const text = await request.text();
   if (text.length > 18000) return Response.json({error:'Request too large'},{status:413,headers});
   const {action,payload} = JSON.parse(text);
   if (!['book','transition','save_facility','add_blackout','remove_blackout','review'].includes(action)) return Response.json({error:'Unsupported action'},{status:400,headers});
   return Response.json(await marketplace(action,payload),{headers});
 } catch(e) { return failure(e); }
}
