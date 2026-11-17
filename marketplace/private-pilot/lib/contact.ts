/** PrimeSpaces business email destination for contact and inquiry links. */
export const PRIMESPACES_EMAIL = 'info@primespaces.org';

export function primespacesMailto(subject = 'PrimeSpaces inquiry') {
  return `mailto:${PRIMESPACES_EMAIL}?subject=${encodeURIComponent(subject)}`;
}
