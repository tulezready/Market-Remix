# MaketPles ENB — Prioritised Roadmap

*Written 3 October 2026. Replaces the month-by-month order in `build-plan.md` Part C,
which assumed the backend would start in August.*

**Where we are:** the whole site is designed and live as a preview. A free Supabase
project (Sydney) now runs behind it: the Shop reads live listings, checkout places real
orders in catalogue mode (pay through an agent or by bank transfer), and the register
form submits applications. Listings are still sample data; card payment, seller logins
and payouts screens are not built yet. See `docs/payments.md`, `docs/deploy.md`,
`docs/supabase-setup.md`.

**Launch target:** November. The realistic November launch is **catalogue mode** —
real businesses and products online, orders taken and paid through agents or bank
transfer — with card payment switched on as soon as a gateway is approved. Decide
this deliberately now (decision D3 below), not in November.

**How this is ordered:** whatever takes longest and is outside our control goes first,
because everything else waits on it. Building work runs in parallel underneath.

Owner key: **You** = project lead · **Division** = Commerce & Industry staff ·
**Claude** = can be done in a Claude Code session.

---

## Priority 0 — Decisions (this week; everything depends on them)

Use `docs/outreach/decisions.md` as the sign-off sheet.

| # | Decision | Owner | Why it blocks |
|---|---|---|---|
| D1 | **Who is the merchant of record** — the Division/ENBPA, or the operator's company — and who owns the platform after handover | You + Division | The gateway contract, bank account, domain registrant and legal pages all name this entity |
| D2 | Platform fee %, agent commission %, payout frequency, holding period before payout | Division | Built into the database and every statement |
| D3 | **Go/no-go on catalogue mode for November** | You + Division | Decides what gets built in October |
| D4 | Delivery zones and charges, minimum order (K15 is a placeholder), informal sellers allowed? | Division | Shown at checkout |
| D5 | Named staff: listing reviewer, finance officer who approves payouts, platform operator after handover | Division | Separation of duties for payouts; someone must run it |

## Priority 1 — Lodge everything slow (this week, in parallel)

| # | Task | Owner | Status | Notes |
|---|---|---|---|---|
| 1 | **Payment gateway enquiries** — Cloudcode (KumulPay/IPG), BSP IPG, Kina Bank IPG | You | Draft ready | `docs/outreach/gateway-enquiry.md` |
| 2 | **Ruling on holding SME funds** (National Payment System Act 2013) — Division finance/legal, and Bank of PNG if needed | You + Division | Draft ready | `docs/outreach/holding-funds-ruling.md` |
| 3 | **Domain** — Cloudflare account in the merchant-of-record's name, then Unitech `.com.pg` application with Cloudflare nameservers (K300) | You | Details ready | `docs/outreach/domain-application.md` |
| 4 | **SME data and photography** — templates to the districts, photo trips booked. *The build plan's biggest risk: 150+ photos, must start by early October* | Division | Not started | Templates: `tools/sme-form.pdf`, `tools/intake.html`; photo guide `photos/README.md` |
| 5 | **Legal pages** — Terms of use, Refunds & returns, Privacy, Seller terms. Gateways ask to see these before approving | Claude drafts → Division legal reviews | Next | Must name the D1 entity |

## Priority 2 — Build now (not blocked)

| # | Task | Owner | Status |
|---|---|---|---|
| 6 | **Deploy setup** — publish only site files, `_headers`, `404.html`, `docs/deploy.md`; make the repo private | Claude (files) + You (private repo, Cloudflare) | Next |
| 7 | **Catalogue mode** — checkout that takes an order and offers *pay an agent* / *bank transfer with reference*; card button appears when a gateway is configured | Claude | **Done** — `place_order` + checkout |
| 8 | **Seller money screens** — bank details with verification status, held vs available balance, payout statements; Division payout-run approval with two approvers | Claude | Database done (`sme_private`, `seller_balances`, `payouts`); screens to do |

## Priority 3 — Backend (starts when the Supabase plan is paid)

| # | Task | Notes |
|---|---|---|
| 9 | Supabase in **Sydney** — **free project created, schema and security fixes applied, sample data loaded**, kept awake by a twice-weekly GitHub Action until Pro. Still: Pro plan before launch, phone-number sign-in (SMS) | `docs/supabase-setup.md` |
| 10 | Shop, product and stall pages read live data (**done**); seller portal and Division panel get real logins (to do) | `config.js` |
| 11 | Gateway integration via the gateway's hosted payment page; **server-side** payment confirmation; settlement ledger | Needs task 1 approved |
| 12 | Payout runs, refunds, disputes, daily reconciliation | Needs D2, D5 and task 2 |
| 13 | SMS notifications (order placed, ready, Send home recipient) | Pick an SMS provider |

## Priority 4 — Launch readiness (October–November)

| # | Task | Owner |
|---|---|---|
| 14 | Load the launch cohort (35 SMEs) and real photos | Division + Claude |
| 15 | Tok Pisin read-through by a local speaker | Division |
| 16 | End-to-end test: real small card payment, one agent order, one Send home from overseas | You |
| 17 | Seller and agent guides; staff training | Claude drafts, Division delivers |
| 18 | Soft launch in one district, then province-wide; keep a buffer week | Everyone |

---

## Already done

- Free Supabase project with schema, security fixes (private bank/contact details, server-side order pricing, working application submission), settings, payouts tables, sample data; live Shop and catalogue-mode checkout
- Plans written up: `docs/payments.md` (gateways, money flow, accounts), `docs/deploy.md` (Cloudflare Pages + maketples.com.pg)

- Full redesign: East New Britain palette and motifs, shop-first layout, Home / Shop / Help & about split
- Product, stall, register, seller and Division pages on the same design
- Phone and speed pass: 44px touch targets, 12px text floor, contrast, ~2s loads on 3G
- Design system (`design-system/maketples-enb/MASTER.md`) and the ui-ux-pro-max skill
- Research: payments in PNG, hosting, domain (see `docs/outreach/`)
