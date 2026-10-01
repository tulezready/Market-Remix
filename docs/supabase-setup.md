# Setting up Supabase

What you need to do so the registration link actually receives applications.
Takes about twenty minutes. Nothing here can be done for you — the account has
to be created by whoever will own it.

---

## Before you start: who owns the account

Create it under a **new email that belongs to the project**, not your personal
one and not the account used for the MSME survey. Something like
`maketples@readydigital…` or a Division address.

This matters because ownership transfers to the Division at final payment
(Section 11 of the scope of work). Transferring a project is easy; untangling
a shared account is not.

---

## 1. Create the project

1. Go to **supabase.com** and sign up with that email.
2. **New project**.
3. Name: `maketples-enb`
4. Database password: generate a strong one and **write it down somewhere safe**.
   You will not be shown it again and it cannot be recovered.
5. Region: **Southeast Asia (Singapore)** — the closest to PNG, so the site
   feels faster than a US or European region.
6. Plan: **Free** is fine while building. Move to **Pro ($25/month)** before
   launch, because free projects are paused after a period of inactivity and an
   official platform going offline is not acceptable.

Wait a couple of minutes for it to finish setting up.

---

## 2. Run the database schema

1. Left sidebar → **SQL Editor** → **New query**.
2. Open `db/schema.sql` from this repository, copy all of it, paste, and press
   **Run**. It should finish with no errors.
3. New query again. Open `db/public-submissions.sql`, paste, **Run**.

Both files are safe to run more than once.

---

## 3. Create two storage buckets

Applications will not send photos, and approvals will not carry photos through
to the live site, until both of these exist.

**Bucket one — where applications land:**
1. Left sidebar → **Storage** → **New bucket**.
2. Name: `applications` — exactly that, lowercase.
3. **Public bucket: OFF.** Applicants upload into it, but only the Division may
   look inside.
4. Create it, then open its settings and set:
   - **File size limit:** `2MB` (the form shrinks photos well below this)
   - **Allowed MIME types:** `image/jpeg, image/png`

**Bucket two — where approved photos go to be shown publicly:**
1. **New bucket** again.
2. Name: `product-photos` — exactly that.
3. **Public bucket: ON.** These are the photos buyers actually see on the site,
   so this one has to be readable by anyone.

When the Division approves a business in the panel, its photos are copied
automatically from `applications` into `product-photos` and wired to the new
listing. If this second bucket doesn't exist yet, approval still creates the
business — it just tells you the photos couldn't be moved, and you can retry
once the bucket is there.

---

## 4. Make yourself Division staff

1. Left sidebar → **Authentication** → **Users** → **Add user**.
   Use your own email and a password you will remember — this is what you sign
   into `admin.html` with.
2. Copy the **User UID** it shows.
3. **SQL Editor** → new query:

```sql
update profiles set role = 'division_admin'
where id = 'PASTE-THE-UID-HERE';
```

Without this, signing into the Division panel will refuse you — correctly,
since the panel checks this role before letting anyone in. Add more staff the
same way, using `division_staff` if they should review but not need full admin
rights (the schema treats both the same for now).

---

## 5. Connect the form and the Division panel

Both `register.html` and `admin.html` need the same two values.

1. Left sidebar → **Project Settings** → **API**.
2. Copy **Project URL** and the **anon public** key.
3. Open `register.html`, find the block near the bottom of the script:

```js
const SUPABASE = {
  URL: "",
  KEY: "",
  BUCKET: "applications"
};
```

4. Paste the two values in.
5. Open `admin.html` and do the same in its own config block:

```js
const SUPABASE = {
  URL: "",
  KEY: "",
  APPLICATIONS_BUCKET: "applications",
  PHOTOS_BUCKET: "product-photos"
};
```

6. Save, commit, push.

The amber "preview mode" bar disappears on both pages once those are filled
in — that is how you know each one is connected.

### Is it safe to put that key in a public file?

Yes. The anon key is designed to be published; it identifies the project, it does
not grant permission. Row level security decides what it can do, and it has been
tested: with that key a visitor can submit an application and nothing else. They
cannot read applications — not even their own. The Division panel is protected
the same way, but with an extra layer: even a signed-in user who isn't marked as
`division_staff` or `division_admin` in the `profiles` table is refused entry.

**What must never go in these files** is the `service_role` key. That one bypasses
every security rule. It belongs only in server-side code, never in a web page.

---

## 6. Test it before sending the link out

1. Open your published `register.html` and submit a real application with
   two or three photos.
2. Open `admin.html`, sign in with the account from step 4, and check
   **Business applications** — the submission should be sitting there as
   pending, with its reference number.
3. Open it. You should see the products they entered and thumbnails of their
   photographs, each with a dropdown showing what it was tagged as. Fix any
   that look wrong before approving.
4. Press **Approve & create account**. You should see a confirmation saying
   how many photographs were moved to the live listing.
5. Check **Businesses** — the new business should be there, approved.
6. Check **Listing review** — its products should be waiting there as drafts,
   ready to publish.

If all of that happens without an error, the whole pipeline — link, database,
storage, and the Division panel — is working end to end.

---

## 7. Send the link

```
https://<your-user>.github.io/<repo>/register.html
```

Short enough to send by SMS or WhatsApp. Once the `.com.pg` domain is approved
it becomes something like `maketples.com.pg/register`.

---

## Approving an application

Sign into `admin.html` → **Business applications** → open the one you want →
**Approve & create account**. The panel creates the business, moves its
photographs into the public bucket, and copies its products across as drafts
for you to review under **Listing review**. No SQL required.

If you ever need to do it by hand — the panel is unreachable, for instance —
the same thing from the SQL editor is:

```sql
select approve_application('THE-APPLICATION-UUID');
```

That creates the business and copies its products across as drafts. It does
**not** move photographs — that part only happens through the panel, since it
needs to download and re-upload each file.

---

## What this does not do yet

- `index.html` and `seller.html` still run on sample data. `admin.html` is
  connected — the Division panel — but buyers browsing the site and sellers
  managing their own listings are the next pieces to wire up.
- Nobody is notified when an application arrives — open the panel to check,
  or set up a Supabase email trigger later.
- Approved sellers cannot log in yet; the panel creates their business record,
  but issuing them a login is still a manual step in Authentication → Users.

---

## Costs

| | |
|---|---|
| Free tier | $0 — fine for building and testing |
| Pro tier | $25/month — required before launch |
| Storage | Included up to 100GB on Pro; photos are ~150KB each |

Per Section 7 of the scope of work, this is a Division operating cost, not part
of the professional fee.
