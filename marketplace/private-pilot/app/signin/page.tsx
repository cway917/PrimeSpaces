'use client';
import { useState } from 'react';
import { PRIMESPACES_EMAIL, primespacesMailto } from '@/lib/contact';
export default function SignIn() {
  const [error, setError] = useState(''), [busy, setBusy] = useState(false);
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault(); if (busy) return; setBusy(true); setError('');
    const fields = new FormData(e.currentTarget);
    try {
      const r = await fetch('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: fields.get('email'), password: fields.get('password') }) });
      const data = await r.json() as { error?: string };
      if (!r.ok) throw new Error(data.error || 'Unable to sign in.');
      window.location.assign('/');
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to sign in.'); setBusy(false); }
  }
  return <main className="account-page"><a className="brand" href="/"><img className="brand-logo" src="/primespaces-logo.png" alt=""/><span className="brand-wordmark"><strong>Prime<span>Spaces</span></strong><small>SPACE RENTAL MARKETPLACE</small></span></a><section className="account-card"><div className="eyebrow">PRIVATE PILOT</div><h1>Welcome to PrimeSpaces</h1><p>Sign in with your invited PrimeSpaces account to find spaces or manage your facilities.</p><form onSubmit={submit}><label>Email address<input name="email" type="email" autoComplete="username" required maxLength={254}/></label><label>Password<input name="password" type="password" autoComplete="current-password" required maxLength={1024}/></label>{error&&<p className="account-error" role="alert">{error}</p>}<button className="btn" disabled={busy}>{busy?'Signing in…':'Sign in'}</button></form><p className="account-help">Need an account or help signing in? <a href={primespacesMailto('PrimeSpaces account assistance')}>{PRIMESPACES_EMAIL}</a></p></section></main>;
}
