# Duke of York Trading Co. — Launch Checklist

## 1. Legal & Business Foundation
- [ ] Register the business with **IPA** (Investment Promotion Authority) — you already have a head start via your business plan generator tool
- [ ] Get an **IRC** (Internal Revenue Commission) TIN for tax purposes
- [ ] Decide on business structure (sole trader vs. company) — affects liability and how you contract with BSP/Cloudcode
- [ ] Check if you need any local ENB provincial business license alongside national registration
- [ ] Draft basic terms of service + refund/dispute policy (even one page protects you)
- [ ] Decide who legally owns the business — you mentioned GitHub/Supabase ownership is deliberately not transferred to ENBPA pending payment; make sure the *business entity* ownership is equally clear before you take real money through it

## 2. Payments — the critical path item
- [ ] Call BSP: **3201212 / 70301212** or email **servicebsp@bsp.com.pg** — ask specifically for **BSP IPG** (Internet Payment Gateway), not BSP Pay
- [ ] In parallel, get a quote from **Cloudcode PNG Limited** — their gateway wraps Visa, Mastercard, BSP Pay, and mobile money in one integration, which may be less work than BSP alone
- [ ] Ask both for: setup cost, per-transaction fee, settlement time (how fast money hits your account), and multi-currency support (for diaspora buyers)
- [ ] Confirm what business paperwork they require (likely your IPA cert + TIN from step 1)
- [ ] Do NOT build the real checkout until one of these is confirmed — no point wiring Stripe-style code to a processor that isn't actually available to you

## 3. Product & Tech Build
- [ ] Move from this static template to the real stack: Supabase (database + auth + storage) + your existing GitHub Pages / PWA deployment pattern
- [ ] Core tables: `products`, `sellers`, `orders`, `order_items`, `agents`, `inventory`
- [ ] Real checkout flow wired to whichever payment gateway you picked in step 2
- [ ] Agent/reseller flow: agent login, commission tracking, "order on behalf of" screen
- [ ] "Send Home" flow: recipient name/phone fields, SMS notification on delivery-ready
- [ ] Admin view for you: manage listings, see orders, approve new sellers
- [ ] Decide hosting/domain — this is where DigitalPlat FreeDomain or a paid domain comes in

## 4. Sellers, Agents & Content
- [ ] Recruit your first 5–10 real sellers (start small, real inventory beats a big empty catalog)
- [ ] Take real photos of their actual products — this replaces every stock/icon placeholder in the template
- [ ] Recruit a handful of agents in Rabaul/Kokopo to test the reseller flow before scaling
- [ ] Set your commission rate for agents (JiveMarket's model pays per completed sale)
- [ ] Write simple onboarding instructions for both sellers and agents (most won't be technical)

## 5. Before You Flip It On
- [ ] Test the full buy flow end-to-end with a real small card payment (your own card, small amount)
- [ ] Test the agent flow with one real agent completing one real order
- [ ] Test the "Send Home" flow with someone actually overseas if possible
- [ ] Confirm what happens on a failed payment, a refund request, and a dispute — know the process before a customer hits it
- [ ] Soft-launch to a small group (friends, one LLG) before public launch

## 6. Ongoing Once Live
- [ ] Monitor BSP/Cloudcode settlement to make sure money is actually landing in your account on schedule
- [ ] Track which products/sellers/agents are actually converting — cut what's not working
- [ ] Keep GitHub/Supabase ownership question resolved with ENBPA before this scales past a personal project

---
**Suggested order of operations:** 1 (legal) and 2 (payments) can run in parallel starting now, since they're the slowest-moving and most out of your direct control. Don't sink real build time into 3 until 2 is confirmed — the payment gateway choice affects how checkout is built.
