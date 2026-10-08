# Supabase — the database behind MaketPles ENB

*Last updated 3 October 2026.*

## Current state

| | |
|---|---|
| Project | **maketples-enb** (`pqdstiwpqonvxuocelav`) |
| Region | **Sydney (ap-southeast-2)** — the closest Supabase region to PNG. *Decided 8 Oct 2026 to keep Sydney rather than start a new Singapore project; the region cannot be changed after a project is created.* |
| Plan | **Free** while building. Move to **Pro (US$25/month)** before launch: free projects pause after a week without activity |
| Organisation | Currently in the project lead's own Supabase organisation. **When payment is arranged:** upgrade to Pro and transfer it to an organisation under a project-dedicated email owned by the Division (Project Settings → General → Transfer project). |
| Website connection | `config.js` (one file, used by every page) |
| Keep-awake | `.github/workflows/supabase-keepalive.yml` queries the project every Monday and Thursday so the free plan does not pause it. **Delete it after the Pro upgrade** |
| Data | 7 sample businesses and 24 sample products, flagged `is_sample` |

**Done:** schema, security rules, storage buckets, ordering, applications, seller logins,
order payment, payout runs, sample data. Security advisor clean except the functions that are
public on purpose (each checks who is calling).

**Still to do by hand** (needs a person, not code):
1. Create the first Division admin login (section 4).
2. Enter the bank transfer details buyers should pay into (section 5).
3. Before launch: upgrade to Pro, transfer the project, remove sample data.

**Keep-awake workflow.** GitHub runs it twice a week; you can also run it from the
repository's **Actions** tab → *Keep Supabase awake* → **Run workflow**. A red run means
the project did not answer — if it shows as paused in the Supabase dashboard, press
**Restore**. GitHub switches scheduled workflows off after 60 days with no commits to the
repository; if that happens the Actions tab shows a banner to re-enable it.

---

## 1. The database files, in order

All in `db/`, safe to re-run. Run them in the SQL editor in this order to rebuild the
project from scratch:

1. `schema.sql` — tables, triggers, row level security, views
2. `public-submissions.sql` — public business applications, photo uploads
3. `security-and-orders.sql` — private business details, `place_order`,
   `submit_application`, settings, payouts, storage buckets, hardening
4. `accounts-and-payouts.sql` — marking orders paid, what sellers may change, holding period,
   `prepare_payout`, two-person payout approval, seller photo uploads, seller-login lookups
5. `seed-sample.sql` — *optional* sample businesses and products

Then deploy the Edge Function `supabase/functions/seller-logins` (Dashboard → Edge Functions →
Deploy a new function, paste `index.ts`, and turn **off** "Verify JWT" — the function checks
the caller itself). It creates seller logins with the secret key, which never reaches a browser.

### What the database protects

- The public can read only **approved** businesses and **live** listings, and only the
  public columns. Contact, tax and bank details live in `sme_private` (owner and Division only).
- Orders are created **only** by `place_order()`, which prices everything itself.
- A seller cannot publish a listing, approve or feature themselves, or mark an order paid.
- Only the Division marks an order **paid**, and only with an agent receipt number or bank
  reference. Paying an order takes the items out of stock.
- A seller can only move their own paid orders forward (preparing → ready → collected), and
  cannot change anything else on the order.
- Payouts are prepared by `prepare_payout()` (the database picks the orders and adds them up),
  approved by a second officer who did not verify that business's bank account, and marked paid
  only with a bank reference and a verified account. An order in a payout is locked.
- A seller can upload photos only to their own folder; a new photo or a wording change on a live
  listing sends it back to the Division for review. Price and stock change straight away.

Tested as a public visitor: catalogue and directory readable; bank and phone columns,
private details, orders and applications refused; direct order inserts refused; tampered
prices ignored; over-stock, below-minimum, missing-recipient and unknown-product orders
refused.

## 2. Settings the Division can change

`platform_settings` (Table Editor → platform_settings):

| Setting | Current (placeholder) |
|---|---|
| `platform_rate` | 10% |
| `delivery_fee` / `free_delivery_over` | K15, free over K150 |
| `min_order` | K15 |
| `payout_hold_days` | 5 |
| `card_payments_enabled` | false — switch on only when a gateway is integrated |
| `bank_transfer_details` | *empty* — see section 5 |

## 3. Storage

Created by `security-and-orders.sql`:

- `applications` — **private**, 2 MB limit, JPEG/PNG. Applicants upload; only the Division can view.
- `product-photos` — **public** to view; only the Division can upload or change files.

## 4. Make yourself Division staff

1. **Authentication → Users → Add user** with your work email and a strong password.
2. Copy the user's **UID**.
3. **SQL Editor**:

```sql
update profiles set role = 'division_admin' where id = 'PASTE-THE-UID-HERE';
```

Add more staff the same way (`division_staff` for reviewers). For payouts, at least
**two** staff accounts are needed — the person who prepares a payout cannot approve it.

## 4a. Seller logins

Supabase's free email service cannot send sign-up or password emails to sellers, so the
Division issues logins from the panel:

1. **Division panel → Businesses → Open** the business → **Seller login**.
2. Enter their **email**, or their **mobile number** if they have no email (it is stored as
   `675XXXXXXXX@phone.maketples.com.pg`; they sign in by typing their mobile number).
3. **Create login.** A temporary password is shown **once** — give it to the owner in person or
   by phone. On first sign-in at `seller.html` they must choose their own password.
4. Forgotten password: **New temporary password** on the same screen.

When SMS sign-in is added (Pro plan + an SMS provider), mobile-number logins can move to it.

## 4b. Day-to-day money

1. **Orders → Waiting for payment.** When an agent hands in cash or a bank transfer arrives,
   open the order, enter the receipt number or bank reference, **Mark paid**. The seller then
   sees it and prepares it.
2. **Businesses → Open → Bank account.** Phone the business on its registered number, read the
   details back, then **I have confirmed these by phone**.
3. **Payouts.** One officer presses **Prepare payout** for each business with money ready.
   A second officer opens it and **Approves**. After the bank transfer, enter the bank reference
   and **Mark paid**. The seller sees each step in their portal.

## 5. Bank transfer details for buyers

Until card payment is live, buyers can pay by bank transfer. Enter the account they
should pay into (the Division's settlement account, decision D1):

```sql
update platform_settings set bank_transfer_details =
'Bank: ...
Account name: ...
Account number: ...
Use your order number as the reference.';
```

If this is empty, buyers are told the Division will send the details by SMS.

## 6. The website connection

`config.js` holds the project URL and the **publishable** key. Both are meant to be public:
the key identifies the project and grants nothing on its own — row level security decides
what anyone can do. **Never** put the secret or service-role key in any file in this
repository.

Leave `supabaseUrl` empty to run the whole site on its built-in sample data. If the
database cannot be reached, the shop falls back to the samples automatically.

## 7. Test the application pipeline

1. Submit an application through `register.html` with two or three photos.
2. Sign into `admin.html` → **Business applications** → open it → check the photos
   → **Approve & create account**.
3. **Businesses** shows it; **Listing review** shows its products as drafts.
4. Publish a listing; it appears on the Shop page.

## 8. Before launch

```sql
-- remove the sample businesses (their products and images go with them)
delete from smes where is_sample;
```

Then: upgrade to Pro (turn on leaked-password protection under Authentication, and delete `.github/workflows/supabase-keepalive.yml`), transfer the project to the Division's organisation,
add the live domain under Authentication → URL Configuration, and remove the eight
legacy columns on `smes` (see the comment in `security-and-orders.sql`).

## Costs

| | |
|---|---|
| Free | US$0 — building and testing |
| Pro | US$25/month — required before launch |
| Storage | 100 GB included on Pro; product photos are ~100–250 KB each |
