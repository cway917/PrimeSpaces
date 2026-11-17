import handler from 'vinext/server/fetch-handler';
import { privateAccessAllowed } from '../lib/private-access';

export default {
  async fetch(request: Request, env: Cloudflare.Env, ctx: ExecutionContext) {
    if (!await privateAccessAllowed(request, env as unknown as Record<string, string>)) {
      return new Response('PrimeSpaces private pilot. Authorized access is required. Hosting setup may still be in progress.', {
        status: 403, headers: { 'Cache-Control': 'private, no-store', 'X-Robots-Tag': 'noindex, nofollow', 'Content-Type': 'text/plain; charset=utf-8' },
      });
    }
    const clean = new Headers(request.headers);
    for (const name of [...clean.keys()]) if (name.toLowerCase().startsWith('oai-authenticated-user-')) clean.delete(name);
    const response = await handler.fetch(new Request(request, { headers: clean }), env, ctx);
    const secured = new Response(response.body, response);
    secured.headers.set('Cache-Control', 'private, no-store');
    secured.headers.set('X-Robots-Tag', 'noindex, nofollow');
    secured.headers.set('X-Content-Type-Options', 'nosniff');
    secured.headers.set('X-Frame-Options', 'DENY');
    secured.headers.set('Referrer-Policy', 'same-origin');
    return secured;
  },
};
