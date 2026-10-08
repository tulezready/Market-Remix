# Security notes — how MaketPles ENB protects people and money

*8 October 2026.* Each control below is named in the vocabulary of the network-security
course it comes from: Easttom, *Network Defense and Countermeasures* (3rd ed., "Ch.") and
the NDC course lecture notes ("S" = session). Use it to explain the design to the Division
and to check that changes keep the protections in place.

## The frame: CIA (S1; Ch. 1)

| | What it means here | Main controls |
|---|---|---|
| **Confidentiality** | Buyers' phone numbers and sellers' bank and tax details stay private | Row level security, private-details table, secret key kept server-side |
| **Integrity** | Prices, payments and payouts can't be faked | Database prices every order; guard triggers; two-person payouts |
| **Availability** | The shop stays up on poor connections | Static site on Cloudflare's network; image fallbacks; keep-alive until Pro |

## Database

- **Deny all, then explicitly permit** (S3; Ch. 3). Every table has row level security
  switched on, so nothing is readable until a policy allows it. Each role then gets one
  narrow door: the public reads approved businesses and live listings only; a seller reads
  only their own business; the Division reads everything.
- **Least privilege and role-based access control** (Ch. 11). The roles are buyer, seller,
  agent, Division staff and Division admin. The API roles are granted only the public
  columns of `smes`; contact, tax and bank details sit in `sme_private`, which only the
  owner and the Division can read.
- **Chinese Wall** (Ch. 13). Sellers are competitors, so no seller can see another
  seller's orders, buyers or balances.
- **Clark-Wilson integrity: well-formed transactions** (Ch. 13). Orders are created only by
  `place_order()`, which prices everything itself; anything the browser sends about money
  is ignored. Guard triggers stop a seller publishing their own listing, marking an order
  paid, moving an order backwards, or editing money fields. A wording or photo change on a
  live listing goes back to the Division for review.
- **Clark-Wilson integrity: separation of duties** (Ch. 13). A payout is prepared by one
  officer and approved by a different one, and whoever verified the business's bank
  account cannot approve its payout. It is marked paid only with a bank reference, and only
  to a verified account. Changing bank details clears the verification automatically.
- **Implementation vulnerabilities: SQL injection** (S2; Ch. 12, OWASP). The site uses the
  Supabase client and database functions with typed parameters; no SQL is built from text.
- **Evidence trail** (Ch. 12). Price changes are logged by trigger; orders record who
  marked them paid and when, and payouts record who prepared, approved and paid them.

## Keys and accounts

- **Master keys stay server-side; exposure** (S3; Ch. 8). Only the publishable key is in
  the site. It grants nothing on its own; row level security decides. The secret key
  lives only inside the `seller-logins` Edge Function, which checks that the caller is
  Division staff before creating or resetting a login.
- **Password policy** (S1; Ch. 6, 11). Supabase Auth stores passwords hashed with
  key stretching (bcrypt). Seller logins start with a one-time temporary password, and the
  seller must choose their own at first sign-in. Before launch, turn on leaked-password
  protection (Pro plan).
- **Leaving employees** (Ch. 11). When an officer leaves, remove their Division role the
  same day; when a business leaves, use *Remove login* in the Division panel.
- **Least privilege for automation** (Ch. 8). The keep-alive workflow uses only the
  publishable key and reads one public row.

## The website

- **HTTPS everywhere** (S2 — a design vulnerability fixed by redesign; Ch. 7). Cloudflare
  issues the certificate; `Strict-Transport-Security` keeps browsers on HTTPS.
- **Hardening and safe defaults** (Ch. 8; OWASP, Ch. 12). The `_headers` file sets a
  content security policy (scripts, styles and connections only from known sources),
  blocks framing, and turns off camera, microphone and location access. The build
  publishes only the website: `docs/` and `db/` never go online.
- **Uploads** (Ch. 9, 10). Photos are resized to JPEG in the browser; the storage buckets
  accept only image types under a size limit; sellers can write only to their own folder.

## Payments

- **Never hold card data; PCI DSS as the benchmark** (Ch. 13). When cards go live, buyers
  pay on the bank's hosted page and the gateway confirms to the server directly. An order
  becomes paid only on that server-side confirmation, never from the browser's redirect.
- Until then the Division marks agent and bank-transfer orders paid, which requires an
  agent receipt number or bank reference.

## Continuity

- **No single point of failure: "losing the only sysadmin"** (S2; Ch. 14). The domain,
  DNS, Cloudflare, GitHub and Supabase accounts should belong to the Division, with at
  least two people able to sign in, and the handover should be documented.
- **Backups and tested restores** (S2; Ch. 14). Supabase Pro includes daily backups.
  Schedule a test restore before launch; a backup that has never been restored is untested.
- **Risk register to keep current** (S2; Ch. 12):
  - The database rules for payouts and seller permissions exist only in the live project.
    Their SQL file was removed from the repo, so record them again before any rebuild or move.
  - The domain's DNS host is not yet confirmed (see `docs/outreach/domain-application.md`).
