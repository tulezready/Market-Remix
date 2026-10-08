# Domain — maketples.com.pg

*Updated 8 October 2026.*

**Decision:** register a **.com.pg** through PNG University of Technology (PNGUoT / Unitech).
Skip .gov.pg. The **registrant is the Division** (Division of Commerce & Industry, ENBPA);
the developer is the **technical contact**.

**Cost:** K300 to register, then K100 every two years.

## The rules on the form

- The name must be **at least 4 characters**, with no hyphens, underscores or spaces.
- A registered name **cannot be changed**. Changing it means de-registering and paying again,
  so settle the final platform name first (decision sheet D7).
- The form needs **two or more nameservers, each with a hostname and an IP address**.
- **PNGUoT will not process the form until the zone (DNS records) for the name already
  exists and answers on both nameservers.**
- The form is **signed and sealed** with the Division's official seal.

## The catch with Cloudflare

Cloudflare only lets you add a domain that is **already registered** and already returns
NS records for working nameservers (Cloudflare docs, "Cannot add domain", error 1049).
PNGUoT wants the zone answering *before* it registers the name. Each waits for the other.
Nobody has tested a .pg name with any DNS host yet. Ways through, in order to try:

1. **Ask PNGUoT** (dns@pnguot.ac.pg) whether they will register with nameservers that will
   be configured right after, or accept a nameserver change once the name exists. If yes:
   register with a temporary host, then move the nameservers to Cloudflare.
2. **Ask Cloudflare Support** to add the zone manually. Their docs say domains with special
   registration rules (they name .gov) can be added this way. Free-plan support is limited.
3. **Use a DNS host that lets you create a zone for a name before it is registered.** Check
   this with the host first; then point the website records at Cloudflare Pages
   (`maketples.pages.dev`) from that host. The site still runs on Cloudflare; only the DNS is
   elsewhere.

Whichever host is used, it must give each nameserver's **IP address** for the form.

## Steps

1. **Check availability** at **whois.nic.pg**. Backups: `maketplesenb.com.pg`, `enbmaket.com.pg`.
2. **Settle the DNS host** using the section above, and create the zone with records for
   the website.
3. **Download the form:** https://www.pnguot.ac.pg/wp-content/uploads/2024/11/DNS_Application_2024_.pdf
   (from https://www.pnguot.ac.pg/icts-dns/).
4. **Phone +675 473 4206 to confirm the bank details first**, then pay **K300** by deposit
   or e-banking to the **Unitech Trust Fund** account on that page. Write the domain name
   on the deposit slip and keep the receipt.
5. **Sign and seal** the form (the Division's signatory and official seal).
6. **Email the form and the receipt** to **dns@pnguot.ac.pg**.
7. When the domain is active, add `maketples.com.pg` and `www.maketples.com.pg` as custom
   domains on the Cloudflare Pages project (see `docs/deploy.md`). HTTPS turns on by itself.

## Details for the form

| Field | Value |
|---|---|
| Domain name | maketples.com.pg (confirm the final platform name first) |
| Registrant (organisation) | Division of Commerce & Industry, East New Britain Provincial Administration |
| Registrant address | [Postal address, Kokopo, East New Britain Province] |
| Administrative contact | [Division signatory — name, position, phone, email] |
| Technical contact | [Developer — name, phone, email] |
| Nameserver 1 | [hostname] — [IP address] |
| Nameserver 2 | [hostname] — [IP address] |
| Purpose | Official online marketplace for East New Britain SMEs, Division of Commerce & Industry |

## A risk to note in the cover letter

The 2023 PNG Government Domain Name Standards tell public bodies to use .gov.pg. Standard
2.1(3) allows commercial or semi-commercial operations to use a non-government domain, and
the standards do not cover .com.pg registration. The cover note cites this; DICT could
still question it later.

Keep the domain, DNS host, Cloudflare and GitHub accounts in the Division's name, with at
least two people able to sign in, so the site never depends on one person.
