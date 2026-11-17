# PrimeSpaces marketplace

The repository's `main` branch now serves an entry page that automatically opens the working, authenticated PrimeSpaces pilot.

- Entry URL: https://cway917.github.io/PrimeSpaces/
- Private application: https://primespaces-private-pilot.charter-one-3074.chatgpt.site/
- Application source: [marketplace/private-pilot/](marketplace/private-pilot/README.md)

The app retains the original PrimeSpaces logo and navy/teal brand. It supports searchable facilities, availability, booking requests, manual/automatic approval, the 10% facility-side commission and monthly admin review. Payments and transfers remain disabled.

## How this deployment works

GitHub Pages serves `index.html` and `marketplace-entry.js`. The entry forwards visitors to the existing private application, where the ChatGPT sign-in gate and database authorization remain in force. This is an entry-point change, not a GitHub Pages backend deployment or a public release of the marketplace.

The script uses a fixed destination and forwards only recognized application hashes. Existing links such as `#owners` and `#spaces` map to the facility hub and discovery page. A normal link and a no-JavaScript fallback are included.

The server application uses the existing Supabase project and private runtime secrets. No credential, access-policy, database-schema or payment configuration is changed by this entry-point update. The previous static marketing homepage is preserved in Git history.

## Development

Follow the [application README](marketplace/private-pilot/README.md) for installation, build, runtime configuration and validation limits. Changing application source on GitHub does not automatically redeploy the private host; application changes must go through the existing private deployment workflow.

No browser-visible service-role keys or server secrets belong in this repository.

## Contact and inquiries

All PrimeSpaces contact and inquiry email links use **info@primespaces.org**. Automatic booking or payout email notifications are not enabled in the current pilot.
