# Domain — maketples.com.pg

**Registry:** PNG Internet Name Service, IT Services, PNG University of Technology (Unitech), Lae.
**Fee:** K300 to register, K100 renewal every two years.
**Apply:** email the completed `.com.pg` application form and proof of payment to
**dns@pnguot.ac.pg**, or post to PNG Internet Name Service, IT Services, UNITECH, PMB,
Lae. Pay by direct deposit or e-banking to the **UNITECH Trust Fund**. The form is on
https://www.unitech.ac.pg/?p=4754 (Domain Name Service).

> **Unitech will not process the application until two working nameservers already
> answer for the domain.** So set up Cloudflare first (steps 1–3), then apply.

## Steps

1. **Check availability** of `maketples.com.pg` with Unitech (email dns@pnguot.ac.pg).
   Backup names: `maketplesenb.com.pg`, `enbmaket.com.pg`.
2. **Create the Cloudflare account** in the name of the D1 entity, using a shared work
   email (not personal). Turn on two-factor sign-in and add a second admin.
3. **Add the domain to Cloudflare** (Add a domain → `maketples.com.pg` → Free plan).
   Cloudflare shows two nameservers, like `aaaa.ns.cloudflare.com` and
   `bbbb.ns.cloudflare.com`. Write them below.
4. **Create the Pages project** (Workers & Pages → Create → Pages → connect the GitHub
   repository, branch `main`) and add `maketples.com.pg` and `www.maketples.com.pg`
   as custom domains. See `docs/deploy.md`.
5. **Pay K300** to the UNITECH Trust Fund and keep the receipt.
6. **Send the form** with the details below and the receipt.
7. When Unitech activates the domain, Cloudflare shows it as **Active** and turns on
   HTTPS by itself.

## Details for the form

| Field | Value |
|---|---|
| Domain name | maketples.com.pg |
| Registrant (organisation) | [D1 entity — full legal name] |
| Registrant address | [Postal address, Kokopo, East New Britain Province] |
| Local presence in PNG | Yes — [IPA registration no. / ENBPA] |
| Administrative contact | [Name, position, phone, email] |
| Technical contact | [Name, phone, email] |
| Primary nameserver | [from Cloudflare step 3] |
| Secondary nameserver | [from Cloudflare step 3] |
| Purpose | Official online marketplace for East New Britain SMEs, Division of Commerce & Industry |

Keep the domain, Cloudflare and GitHub accounts in the organisation's name, with at
least two people able to sign in, so the site never depends on one person.
