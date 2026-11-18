# Gordon Protection — Backend setup (Supabase)

This turns the demo logins into **real customer accounts** and gives you an
**admin dashboard** you can open from your phone to control everything.

You only do this once. It takes about 10 minutes. Nothing here costs money —
the free tier covers you well past your first hundreds of customers.

> The only things I can't do for you are create the account and type your
> password. Everything else (database, security rules, logins, the dashboard)
> is already built and in this repo. Do steps 1–6 and you're live.

---

## Step 1 — Create your Supabase project
1. Go to **supabase.com** and click **Start your project** → sign in with GitHub or email.
2. Click **New project**.
3. Name it `gordon-protection`. Pick a **database password** (save it somewhere safe — you rarely need it, but don't lose it). Choose region **East US** (closest to you).
4. Click **Create new project** and wait ~2 minutes for it to finish setting up.

## Step 2 — Create the database
1. In the left sidebar click **SQL Editor** → **New query**.
2. Open the file **`supabase/schema.sql`** from this repo, copy the whole thing, paste it in, and click **Run**.
3. You should see "Success. No rows returned." That built your tables, security rules, and sign-up automation.

## Step 3 — Turn on the login settings
1. Left sidebar → **Authentication** → **Sign In / Providers**. Make sure **Email** is enabled (it is by default).
2. Left sidebar → **Authentication** → **URL Configuration**. Set **Site URL** to your live site:
   `https://donngordon.github.io/home-security-demo/`
   This makes password-reset and confirmation links point back to your real site.
3. Two-factor (authenticator-app) support is already on by default — nothing to do.

> **Email confirmation:** by default Supabase emails a confirmation link when
> someone signs up. That's the secure choice — keep it on. (If you want faster
> testing for yourself, you can temporarily turn it off under Authentication →
> Sign In / Providers → Email → "Confirm email", then turn it back on.)

## Step 4 — Get your two keys
1. Left sidebar → **Project Settings** (gear icon) → **API**.
2. Copy the **Project URL** (looks like `https://abcd1234.supabase.co`).
3. Copy the **anon public** key (a long `eyJ…` string). This one is **safe to be public** — your data is protected by the security rules from Step 2.

## Step 5 — Connect the site to the backend
**Easiest:** send me those two values and I'll paste them in and push. 

**Or do it yourself** — in each of these two files, fill in the two lines near the top of the `<script>` block:
- `portal/index.html`
- `admin/index.html`

```js
window.GP_SUPABASE_URL      = "https://abcd1234.supabase.co";
window.GP_SUPABASE_ANON_KEY = "eyJhbGciOi...your-anon-key...";
```

(Optional, in `portal/index.html` only — turn on card payments later:)
```js
window.GP_STRIPE_PAYMENT_LINK = "https://buy.stripe.com/your-link";
```

## Step 6 — Make yourself the admin
1. Open the **customer portal**, click **Create an account**, and sign up with your own email + a strong password. (Confirm via the email link if confirmation is on.)
2. Back in Supabase → **SQL Editor** → **New query**, run this once (use the email you signed up with):
   ```sql
   update public.profiles set role='admin', status='active'
   where email = 'donn.cyber@gmail.com';
   ```
3. Open the **admin console** at `…/home-security-demo/admin/` and sign in. You now see every customer and can change plans, status, billing, and devices. Turn on **2FA** from the button in the top bar — strongly recommended for the admin account.

---

## What you now have
- **Customer portal** (`/portal/`): real sign-up, sign-in, password reset, optional 2FA, live plan + billing + device status pulled from your database.
- **Admin console** (`/admin/`): phone-friendly. See all customers and revenue at a glance; tap any customer to change plan/price/status, toggle autopay, set the next due date, add invoices, and manage their devices. Admin-only — a normal customer who tries it is turned away.
- **Security:** passwords are hashed by Supabase, every table is protected by row-level rules (customers only ever see their own data), sessions time out after 15 minutes idle / 12 hours max (NIST SP 800-63B AAL2), and 2FA is available.

## Security notes
- The **anon key** in the two HTML files is meant to be public — it only lets the browser talk to Supabase, and the row-level rules decide what each signed-in person can see or change.
- **Never** put the **service_role** key (also on the API settings page) into any website file. That one bypasses all security. Keep it for the Supabase dashboard only.
- Customers can edit their name, phone, and card-on-file label, but **cannot** change their own plan, price, status, or role — only an admin can (enforced in the database, not just the screen).
