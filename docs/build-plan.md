# MaketPles ENB — What's Left to Build, and What Data We Need

**Status as of now:** everything produced so far is **design preview only**. The marketplace page and the seller dashboard look and behave like the real thing, but all data is hardcoded into the page. There is no database, no login, no real payment, and nothing is saved. The engineering work has not started yet.

**Deadline:** November. Working backwards, data collection is the long pole — not the code.

---

## PART A — What still needs to be built

### A1. Backend foundation *(can start immediately — nothing blocks this)*
- [ ] Supabase project on the **Pro tier** (the free tier suspends inactive projects)
- [ ] Database tables: `smes`, `products`, `product_images`, `orders`, `order_items`, `agents`, `agent_commissions`, `seller_applications`, `notices`, `price_history`
- [ ] Row-level security so each SME can only see and edit its own records
- [ ] File storage buckets for product and business photographs
- [ ] Move all hardcoded data out of the page and into the database

### A2. Public marketplace *(build on top of A1)*
- [ ] Connect the existing template to live data
- [ ] Individual product pages (currently products are cards only, with no page of their own)
- [ ] Individual SME stall pages
- [ ] Buyer accounts — login, order history, saved delivery details
- [ ] Working "Send home" recipient capture
- [ ] Order confirmation and status pages

### A3. Seller portal *(currently a mockup with no login)*
- [ ] Real authentication, one account per SME
- [ ] Product creation and editing, with photo upload
- [ ] Submit-for-review workflow
- [ ] Direct price and stock updates, with change logging
- [ ] Orders view, and marking orders fulfilled
- [ ] Payout statement

### A4. Division administration panel *(not started at all)*
- [ ] Staff login
- [ ] Approve or reject SME registration applications
- [ ] Review queue for submitted listings, with a reason field on rejection
- [ ] Oversight of all orders across all SMEs
- [ ] Agent account management and commission rates
- [ ] Publish notices to the public site
- [ ] Export orders and price data for economic reporting

### A5. Agent network *(currently a described concept only)*
- [ ] Agent accounts and login
- [ ] "Order on behalf of a buyer" checkout flow
- [ ] Commission calculation and statement per agent

### A6. Payments *(blocked — cannot start until the gateway responds)*
- [ ] Integration with the chosen PNG gateway, using their hosted payment page
- [ ] Server-side payment confirmation before an order counts as paid
- [ ] Price-at-time-of-sale snapshot on every order line
- [ ] Settlement ledger: collected, commission retained, owed per SME
- [ ] **Fallback if the gateway is not approved in time:** launch as a live catalogue with agent and offline settlement, and switch card payment on later. This keeps November safe.

### A7. Notifications
- [ ] Order confirmation to buyer
- [ ] Order notification to the SME
- [ ] SMS to the nominated recipient for "Send home" orders
- [ ] SMS provider account and per-message pricing (still to be quoted)

### A8. Launch preparation
- [ ] Deploy to the `.com.pg` domain
- [ ] Administrator guide for Division staff
- [ ] Seller guide for distribution to SMEs
- [ ] Training session for nominated staff
- [ ] End-to-end test with a real small transaction
- [ ] Soft launch in one district before opening all four

---

## PART B — Data we need to collect

This is the part that needs other people, and it is what will delay November if it slips.

### B1. SME records — one per business, 35 in total

Districts are identifying and funding these. For each business we need:

| Field | Notes |
|---|---|
| Registered business name | Exactly as on the IPA certificate |
| Trading name | If different from the registered name |
| District | Gazelle, Kokopo, Rabaul or Pomio |
| LLG / ward / village | For delivery zones and agent coverage |
| Primary industry | One of the seven |
| Secondary industry | Optional |
| IPA registration number | Or status if not yet registered |
| IRC TIN | Or status if not yet obtained |
| Owner / contact person | Full name |
| Contact phone | Required — this is the main channel |
| Contact email | If they have one |
| Bank name | For payout settlement |
| Account name and number | Must match the business |
| Stall description | 40–60 words, shown to buyers |
| Consent to publish | Written agreement to appear on a public site |

**Decision needed before this can be finalised:** can businesses without IPA registration sell on the platform, or must all 35 be formally registered?

### B2. Product records — several per SME

| Field | Notes |
|---|---|
| SME it belongs to | Links the product to its seller |
| Product name | As buyers would search for it |
| Industry / category | One of the seven |
| Price in Kina | |
| Unit | Per kg, per bundle, each, per bottle |
| Stock quantity | Starting figure |
| Description | 30–50 words |
| Perishable | Affects which delivery options can be offered |
| Can be shipped outside the district | Fresh greens cannot; a bilum can |
| Photographs | See B3 |

Assuming roughly three products per SME, that is **around 100 product records**.

### B3. Photography — the largest single task

| Purpose | Quantity | Specification |
|---|---|---|
| Homepage slideshow | 7–12 | Landscape, 1800px wide minimum, people at work, clear space on the left third for the headline |
| SME business photo | 1 per SME (35) | The owner at their premises, stall or workshop |
| Product photos | 1–3 per product (100–300) | Daylight, plain background, product filling the frame |

**Total: roughly 150–350 photographs.** Phone cameras are fine if shot in daylight. This is a field operation, not a desk task — it should happen at the same time as SME onboarding visits, not afterwards.

### B4. Institutional content — from the Division
- [ ] **Confirmed platform name** ("MaketPles ENB" is a working title only)
- [ ] Official ENBPA logo files, high resolution, supplied by the Administration
- [ ] Division office address, phone, email and opening hours
- [ ] Approved wording for the "Who stands behind this" section
- [ ] Confirmation that the listed partner organisations agree to be named
- [ ] Any disclaimers or terms the Administration requires
- [ ] Name and title of the officer authorised to approve deliverables

### B5. Decisions the Division must make

None of these are technical, but each one changes how the platform is built:

- [ ] **Platform commission rate** — the percentage retained on each sale
- [ ] **Agent commission rate** — what an agent earns per completed order
- [ ] **Payout frequency** — weekly, fortnightly or monthly (affects bank fees)
- [ ] **Delivery zones and charges** — which areas, at what price
- [ ] **Minimum order value** — currently shown as K15, a placeholder
- [ ] **Informal sellers** — permitted or not, and on what terms
- [ ] **Who reviews listings** — a named, ongoing staff responsibility after launch
- [ ] **Who operates the platform after handover** — this is not currently assigned to anyone

### B6. Payment gateway — from BSP or Cloudcode
- [ ] Merchant account approval
- [ ] Merchant ID and API credentials
- [ ] Integration documentation
- [ ] Sandbox or test environment access
- [ ] Confirmed fee structure and settlement timeframe

### B7. Domain — from PNG University of Technology
- [ ] `.com.pg` application lodged (K300)
- [ ] Two working nameservers configured before submission
- [ ] Approval and delegation

---

## PART C — Order of work

**Start now, in parallel — these are the slowest and least within our control:**
1. Lodge the payment gateway enquiry (BSP and Cloudcode)
2. Lodge the `.com.pg` domain application
3. Send the SME and product data templates to the districts
4. Get the Division's decisions in B5 confirmed in writing

**August — build the foundation:**
5. Supabase Pro, database schema, security rules
6. Connect the marketplace template to live data

**September — build the portals:**
7. Seller portal with real login
8. Division administration panel
9. Agent flow
10. Payment integration *if* credentials have arrived; otherwise build catalogue mode

**October — fill it with reality:**
11. Load all 35 SMEs and their products
12. Load photography
13. Notifications, testing, guides, staff training

**November — launch:**
14. Soft launch in one district, then province-wide
15. Keep a buffer week — it will be needed

---

## The two things most likely to cause a problem

1. **Photography.** It is 150+ images, it needs people to travel, and it cannot be done from a desk. If it has not started by early October, November is at risk.
2. **Gateway approval.** Entirely outside our control. The catalogue-mode fallback in A6 exists so that this cannot sink the launch date — but the decision to use that fallback should be made deliberately, not discovered in November.
