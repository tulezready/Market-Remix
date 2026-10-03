# Hosting and domain

*How MaketPles ENB goes live on its own domain. Last updated 3 October 2026.*

## Summary

| | Choice | Cost |
|---|---|---|
| **Hosting** | **Cloudflare Pages**, connected to the GitHub repository | Free plan: unlimited bandwidth, 500 deploys a month, HTTPS included |
| **Domain** | **maketples.com.pg**, registered with Unitech | K300, then K100 every two years |
| **DNS** | Cloudflare (free), which Unitech's nameserver requirement needs anyway | Free |
| **Database** | Supabase project `maketples-enb`, Sydney region | Free while building; Pro (US$25/month) before launch |

**Why not stay on GitHub Pages:** GitHub's own rules say Pages may not be used to run an
e-commerce site or anything mainly for commercial transactions, or for passwords and
card numbers. Fine for the preview; not for launch.

**Why not Vercel's free plan:** non-commercial use only. Netlify's free plan is a good
fallback if Cloudflare is not possible.

## Accounts — set these up in the organisation's name

Use a shared work email for the merchant of record (decision D1), turn on two-factor
sign-in, and add at least **two** admins to each: Cloudflare, GitHub, Supabase, Unitech
domain record. The site must never depend on one person's login.

## Step by step

1. **Make the GitHub repository private** (Settings → General → Danger zone → Change
   visibility). Cloudflare Pages works with private repositories. Internal documents
   (`docs/`, `db/`) should not be public.
2. **Create the Cloudflare account** and **add the domain** `maketples.com.pg`
   (Add a domain → Free plan). Note the two nameservers Cloudflare assigns.
3. **Create the Pages project**: Workers & Pages → Create → Pages → Connect to Git →
   choose the repository → production branch `main` → *Framework preset: None*,
   *Build command: none*, *Build output directory: `/`* → Save and deploy.
4. **Add custom domains** in the Pages project: `maketples.com.pg` and
   `www.maketples.com.pg`.
5. **Apply to Unitech** with the two Cloudflare nameservers and the K300 receipt —
   details and form fields in `docs/outreach/domain-application.md`.
6. When Unitech activates the domain, Cloudflare shows it as **Active** and issues the
   HTTPS certificate automatically.
7. **Tell Supabase about the domain**: Authentication → URL Configuration → Site URL
   `https://maketples.com.pg`, and add it to the redirect URLs.
8. **Switch GitHub Pages off** (Settings → Pages → Unpublish) so only one copy is public.

From then on every change merged into `main` is live within a minute, and every other
branch gets its own preview address for review before it goes live.

## Before going public

- [ ] Repository private; only site files published (pages, `site.css`, `site.js`,
      `shop-data.js`, `config.js`, `logo*.{svg,png}`, `photos/`, `tools/` if the intake
      tool should be reachable)
- [ ] `_headers` file with security headers, and a `404.html` page
- [ ] Legal pages linked in the footer: Terms of use, Refunds & returns, Privacy, Seller terms
- [ ] `config.js` points at the production Supabase project
- [ ] Supabase on the **Pro** plan (free projects pause after a week without activity);
      then delete `.github/workflows/supabase-keepalive.yml`
- [ ] Sample data removed: `delete from smes where is_sample;`
