# Independent private Cloudflare hosting

The existing Sites pilot stays at https://primespaces-private-pilot.charter-one-3074.chatgpt.site. This configuration does not change DNS, the GitHub Pages redirect, or payment settings.

## Cloudflare repository settings

| Field | Value |
| --- | --- |
| Repository | `cway917/PrimeSpaces` |
| Branch | `main` |
| Project / Worker name | `primespaces` |
| Root directory / Path | `marketplace/private-pilot` |
| Build command | `npm run build:cloudflare` |
| Deploy command | `npm run deploy:cloudflare` |
| Preview builds | Off |
| Protect with Cloudflare Access | On, **All traffic** |
| Authentication policy | Cloudflare account, initially restricted to the owner |

Use Node 22.13 or newer. The build system installs the committed npm lockfile automatically. This is a Worker application; do not select a static Pages preset or deploy the repository root.

The explicit build uses `vite.cloudflare.config.ts` and `wrangler.cloudflare.jsonc`. The original build and `vite.config.ts` retain Sites hosting. The generated deployment configuration is `dist/server/wrangler.json`; the pinned Wrangler deploy script uses that file and the same Worker name as the dashboard.

## Runtime configuration

Add these through the Worker's runtime settings (Variables and Secrets). They must be runtime bindings, not only build environment variables. Keeping them as Secrets avoids having dashboard-managed values overwritten by a later deploy. No service-role key or pilot server token is required on this independent host.

| Name | Value source |
| --- | --- |
| `SUPABASE_URL` | Existing PrimeSpaces project's API URL |
| `SUPABASE_PUBLISHABLE_KEY` | Existing PrimeSpaces publishable API key |
| `TEAM_DOMAIN` | Access team URL, `https://<team>.cloudflareaccess.com` |
| `POLICY_AUD` | Audience tag of the Access application protecting this Worker |

The tracked configuration selects Supabase login and restricts signed Access identities to `carla@primespaces.org`. Additional private testers need both an Access policy invitation and an intentional update to `PILOT_ALLOWED_EMAILS`. Neither grants marketplace roles. Never use a policy that bypasses Access or allows everyone during this private pilot.

The Worker verifies Access JWT signatures, issuer, audience, expiry and the explicit pilot email list before serving routes or static assets. Missing setup blocks every request. Static assets use `run_worker_first: true`, and version previews are disabled. Turning the dashboard Access switch off does not remove the application's signed-token check. Keep the Access application protecting **all traffic**, including the workers.dev hostname and any future custom domain.

## PrimeSpaces accounts

Cloudflare hosting membership and PrimeSpaces application membership are separate. `carla@primespaces.org` owns hosting; it has not been promoted to marketplace admin by this change. The existing marketplace owner remains the configured email `cway781@gmail.com`.

Create the first matching Supabase Auth account using **Authentication → Users → Add user → Create new user**, choosing its password in the Supabase dashboard. No account is created automatically by this source update and no invitation email is sent by the deployment. If the dashboard offers email confirmation, complete/confirm it before signing in. Do not share passwords or service-role keys in chat or commit them. Authorized users sign in at `/signin` with an invited, confirmed Supabase email/password account. There is no public signup form.

The account adapter derives identity from Supabase `auth.uid()` and the confirmed user in `auth.users`, verifies that the JWT's session still exists and has not expired, rejects banned users, and resolves the existing marketplace membership by verified email. It preserves actor IDs, bookings, organization membership and admin roles. Editable user metadata and email claims cannot grant privileges. Uninvited accounts cannot reach marketplace data even if they authenticate with Supabase. Ambiguous duplicate memberships are rejected for manual resolution.

The application stores only an access token in a Secure, HttpOnly, SameSite=Strict host-only cookie, capped at one hour. Refresh tokens are not stored; users sign in again when the session expires. Sign out attempts to revoke the Supabase session and always removes the local cookie. Password reset and user invitation administration remain in the Supabase dashboard for this pilot. Inquiries go to info@primespaces.org; automatic booking emails are still off.

`supabase/cloudflare-auth.sql` is the incremental update applied to the existing project. It retains the original server-token RPC for the Sites pilot and delegates both hosts to shared private business rules with no direct public grants. New independent-host calls use the authenticated-only `primespaces_account` RPC and cannot supply their own actor or role. Do not rerun the pilot schema or seed data. For another environment, review the schema and apply the account adapter after the pilot and add-on schema.

## Validation and cutover

The TypeScript check, independent production build, Access signature/identity tests, deployment dry run, original database workflows, equipment pricing tests, and account/session permission tests are checked before committing. Database fixtures roll back and do not create real users or send emails. The existing Sites build remains a separate supported target.

Cloudflare account-specific checks require the user's actual Access/runtime configuration and first Supabase Auth user. Before changing DNS: verify the new private workers.dev URL in a signed-out browser; sign in as the owner; confirm admin listing edits and a rental request/approval; invite controlled renter/facility test accounts and verify data isolation. Mark verification-only bookings clearly and cancel them after testing. Leave the current pilot and domain unchanged until those checks pass and the owner approves cutover.

Payments stay disabled. There is no Stripe integration, charge, transfer or payout action. The 10% facility-side commission and admin review are accounting previews only.
