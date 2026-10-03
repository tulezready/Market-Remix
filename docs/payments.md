# Payments, money flow and accounts

*How buyers pay, how money reaches each SME, and who can do what.*
*Last updated 3 October 2026.*

---

## 1. What is available in Papua New Guinea

| Option | Status for MaketPles |
|---|---|
| **Stripe** | **Not available.** Stripe does not support businesses based in PNG. The only workaround — registering a company overseas — is not appropriate for a provincial programme. |
| **PayPal** | **Not available** in PNG. |
| **Cloudcode PNG — KumulPay / Cloudcode IPG** | BSP Pay, Visa/Mastercard and USSD (basic phones) in **one integration**; multi-currency, e-receipts. Built the Department of Finance's online receipting system. **Recommended first choice.** |
| **BSP Internet Payment Gateway (IPG)** | Visa debit/credit and BSP EasyCard; funds settle to a BSP account **overnight**; merchant portal. Used by Air Niugini and Jack's of PNG. |
| **Kina Bank IPG** | Visa/Mastercard **and local ATM cards** (magnetic strip); 3-D Secure 2.0; pitched as lower cost. |
| **Digicel CellMoni** | Mobile wallet (~1.6 million users) with "Pay Merchants"; no documented web checkout found — ask Digicel. A later phase. |
| **Cash through agents** | Already in the design. Covers buyers with no card or bank account. |

**Plan:** ask Cloudcode, BSP and Kina at the same time (`docs/outreach/gateway-enquiry.md`),
launch with one, add a second later if needed, and keep agents for cash.

## 2. Launch mode: catalogue first, cards when ready

Card payment cannot go live until a gateway approves and supplies credentials. So the
site works now in **catalogue mode**, which is already built:

1. The buyer fills the basket and checks out with their name and mobile number
   (and the recipient's, for *Send home*).
2. They choose **cash through a local agent** or **bank transfer**. *Card or BSP Pay*
   is shown greyed out ("Coming soon").
3. The order is created by the database function `place_order`, which recalculates
   every price, fee and delivery charge itself — nothing the browser sends about
   money is trusted.
4. The buyer sees their order numbers and how to pay (bank transfer details come from
   `platform_settings.bank_transfer_details`; agents need only the order number).
5. Division staff mark the order **paid** when the money arrives; from there the
   business prepares it.

**Switching cards on later** is a setting (`platform_settings.card_payments_enabled`),
plus the gateway integration: the buyer is sent to the gateway's own hosted payment
page, and the gateway confirms the payment **server to server** (a Supabase Edge
Function) before the order is marked paid. Card details never touch our site.

## 3. How the money flows to each SME

One platform account receives every payment; a ledger records what each business is owed.
Individual merchant accounts for every SME are not realistic.

```
Buyer pays once ──► Platform account ──► ledger per order ──► payout run ──► SME bank accounts
 (basket of 3 SMEs)   (merchant of record)   subtotal              fortnightly,     (verified accounts only)
                                             − platform fee        approved by
                                             − agent commission    two people
                                             = seller_net
```

- **One basket, several businesses** → one order per business, sharing a basket reference.
- **Each order records** `subtotal`, `platform_fee`, `agent_fee` and `seller_net` (what the
  SME is owed). These are computed in the database and cannot be edited by sellers.
- **Holding period**: money becomes *available* `payout_hold_days` after the order is
  fulfilled (default 5) — time for refunds and disputes. The view `seller_balances`
  shows *held*, *available* and *paid out* per business.
- **Payout run**: a finance officer prepares a payout (`payouts`, linked to its orders in
  `payout_orders`); **a different person** must approve it; it can only be marked paid
  if the business's bank account is **verified**. All enforced in the database.
- **Reconciliation**: check the gateway / bank statement against paid orders daily.

> **Legal check before taking real money.** Holding money for SMEs and paying it out may
> need a Bank of PNG payment service provider licence under the National Payment System
> Act 2013 (K500,000 minimum capital, segregated funds). Options: a government trust
> account, a licensed gateway or bank holding and paying out, or a ruling that it does not
> apply. Request: `docs/outreach/holding-funds-ruling.md`. *Not legal advice.*

## 4. Accounts and who can do what

| Role | Can | Cannot |
|---|---|---|
| **Buyer** | Browse, order as a guest with a mobile number, check a basket by its reference | See anyone else's orders |
| **SME owner** (`seller`) | Edit their own business description and photos, manage their own listings (submit for review), see their own orders, payouts and balance, update their bank details | Publish a listing (the Division does), approve or feature themselves, change their district, see other businesses' data, mark their own bank account verified |
| **Agent** | Place orders for buyers, see orders they placed and their commission | Change prices or fees |
| **Division staff / admin** | Approve applications and listings, mark orders paid, verify bank accounts, prepare and approve payouts, edit settings | Approve a payout they prepared themselves |

**Signing up a business**
1. The business applies (`register.html`) or a district officer enters it.
2. The Division checks the IPA certificate, TIN (if any) and a bank letter or statement
   whose **account name matches the business name**.
3. *Approve & create account* in the Division panel creates the business; its contact
   details go to the private table `sme_private`.
4. Bank details are confirmed **by phone** before `bank_verified` is set. Any later change
   to bank details automatically clears verification.

**Where personal data lives:** contact, tax and bank details are in `sme_private`, readable
only by the business owner and the Division. The public `smes` table and the public views
hold only what appears on the website.

## 5. Decisions still needed (`docs/outreach/decisions.md`)

Merchant of record · platform fee % · agent commission % · payout frequency · holding
period · delivery areas and charge · minimum order · named payout approvers. The current
values in `platform_settings` (10% fee, K15 delivery, free over K150, K15 minimum, 5-day
hold) are **placeholders** until signed off.
