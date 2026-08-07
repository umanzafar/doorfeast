# DoorFeast — Project Rules for Claude Code

Read this file at the start of every session. Follow it exactly. Do not deviate without asking.

---

## What we are building

An online food ordering site for independent takeaways in Stoke-on-Trent, UK.

- Customers order food online and pay by card, Apple Pay or Google Pay.
- Takeaways do their own delivery or collection. We do NOT have drivers.
- We charge the takeaway 12% commission.
- A £0.50 customer service fee is INCLUDED INSIDE displayed item prices. It is NEVER added as a separate line at checkout. (UK law: DMCC Act 2024 — mandatory fees must be in the headline price.)

**V1 pilot:** 2 takeaways owned by the co-founder. Real customers, real card payments.

---

## Stack — do not change without asking

- Frontend: plain HTML/CSS/JS, one self-contained file per page. No React, no build step.
- Database + Auth: **Supabase** (Postgres)
- Payments: **Stripe** — Payment Element or Stripe Checkout
- Hosting: Hostinger VPS

**We are moving OFF Google Apps Script. Do not write any new Apps Script code.**

---

## HARD RULES — never break these

1. **Never use `fetch(..., {mode:"no-cors"})`.** The old code did this everywhere. It sends data and never learns if it worked. Orders will silently vanish. Every write must read the response and handle errors.

2. **Never put a secret key in frontend code.** Stripe secret key, Supabase service_role key, and any admin key live ONLY in Vercel environment variables, used ONLY inside `/api` functions.
   - Supabase `anon` key in the frontend is fine — that is its purpose.
   - Firebase web API key in frontend is fine — that is public by design.
   - Stripe **publishable** key (`pk_`) in frontend is fine. Stripe **secret** key (`sk_`) is NOT.

3. **Never protect anything with a JavaScript password check.** The old `admin.html` had a password in the code — anyone could read it. Real protection is server-side only.

4. **Row Level Security (RLS) must be ON for every Supabase table**, with explicit policies. Never leave a table open. After creating any table, show me the policies you wrote.

5. **All money is stored as integer pence.** Never use floats or decimals for money. `1250` = £12.50.

6. **Never trust a value sent from the browser for pricing.** Recalculate the order total on the server from database prices before creating the Stripe payment. A customer can edit anything in their browser.

---

## Database schema

Create these tables in Supabase, in this order.

### restaurants
| column | type | notes |
|---|---|---|
| id | uuid, pk | |
| name | text | |
| slug | text, unique | used in URL, e.g. `/r/golden-kebab` |
| address | text | |
| postcode | text | |
| phone | text | |
| cuisine | text | |
| is_live | boolean | default false — hides restaurant until ready |
| does_delivery | boolean | |
| does_collection | boolean | |
| delivery_fee_pence | integer | set by restaurant |
| min_order_pence | integer | |
| delivery_postcodes | text[] | which postcodes they deliver to |
| opening_hours | jsonb | |
| stripe_account_id | text | nullable, for later Stripe Connect |
| created_at | timestamptz | |

### menu_categories
| column | type | notes |
|---|---|---|
| id | uuid, pk | |
| restaurant_id | uuid, fk | |
| name | text | e.g. "Starters" |
| sort_order | integer | |

### menu_items
| column | type | notes |
|---|---|---|
| id | uuid, pk | |
| restaurant_id | uuid, fk | |
| category_id | uuid, fk | |
| name | text | |
| description | text | |
| price_pence | integer | **includes the £0.50 fee already** |
| allergens | text[] | REQUIRED — cannot be empty |
| is_available | boolean | out-of-stock toggle |
| photo_url | text | nullable |
| sort_order | integer | |

### orders
| column | type | notes |
|---|---|---|
| id | uuid, pk | |
| order_number | text, unique | short human code, e.g. `DF-4821` |
| restaurant_id | uuid, fk | |
| customer_name | text | |
| customer_phone | text | |
| customer_email | text | |
| order_type | text | `collection` or `delivery` |
| delivery_address | text | nullable |
| subtotal_pence | integer | |
| delivery_fee_pence | integer | |
| total_pence | integer | what the customer paid |
| commission_pence | integer | our 12% — calculated and stored at order time |
| status | text | see status flow below |
| payment_status | text | `pending`, `paid`, `failed`, `refunded` |
| stripe_payment_intent_id | text | |
| customer_note | text | nullable |
| created_at | timestamptz | |
| accepted_at | timestamptz | nullable |
| ready_at | timestamptz | nullable |

### order_items
| column | type | notes |
|---|---|---|
| id | uuid, pk | |
| order_id | uuid, fk | |
| menu_item_id | uuid, fk | |
| item_name | text | **copy of the name at order time** |
| item_price_pence | integer | **copy of the price at order time** |
| quantity | integer | |
| line_total_pence | integer | |

**Why we copy name and price into order_items:** if the restaurant changes their menu next week, old orders must still show what was actually bought and paid. Never join to `menu_items` to display an old order.

### Order status flow
```
pending_payment → paid → accepted → preparing → ready → completed
                      ↘ rejected
                      ↘ refunded
```
An order is only shown to the restaurant once `payment_status = 'paid'`.

---

## Build order for V1 — do these in sequence

**Step 1 — Supabase setup**
Create the project. Create all tables above. Turn on RLS with policies. Show me the policies.

**Step 2 — Seed the menus by hand**
Do NOT build a menu management screen yet. Insert the two restaurants and their menu items directly into Supabase. The founder will provide the menus.

**Step 3 — Customer restaurant page** (`/r/[slug]`)
Show restaurant name, opening hours, menu grouped by category, allergens visible on every item, out-of-stock items greyed out. No login required.

**Step 4 — Basket**
Add/remove items, change quantity, choose collection or delivery, show subtotal + delivery fee + total. Keep it in browser memory. No account needed.

**Step 5 — Checkout**
Collect name, phone, email, delivery address if delivery.
- Create the order server-side in `/api/create-order` with status `pending_payment`.
- **Recalculate the total on the server from database prices.**
- Create a Stripe Payment Intent server-side, return the client secret.
- Render Stripe Payment Element with card, Apple Pay and Google Pay enabled.
- On success, a Stripe **webhook** (`/api/stripe-webhook`) sets `payment_status = 'paid'` and `status = 'paid'`.
- Never mark an order paid based on the browser saying so. Only the webhook.

**Step 6 — Order inbox for the restaurant**
A single page that runs on a POS tablet in the shop.
- Uses Supabase Realtime to receive new orders live.
- Plays a loud repeating sound until someone taps the screen.
- Shows the order, lets staff Accept or Reject, then Mark Ready.
- Prints a ticket via the browser print function.

**Step 7 — Test**
One real order in the co-founder's Burslem shop, start to finish.

---

## Out of scope for V1 — do not build these

Order history, payouts screen, reports, promotions, customer accounts and logins, menu management UI, staff accounts, driver management, loyalty points, ratings, referrals.

Guest checkout only. No customer login in V1.

---

## Legal requirements that affect the code

- **Allergens must be shown on every menu item before purchase.** The field cannot be empty. (UK Food Information Regulations — allergen info required at point of order AND at delivery.)
- **The £0.50 fee is inside item prices.** Never a separate checkout line.
- **Privacy Policy, Terms and Cookies pages must exist and be linked** before taking any real order.
- **Company name, company number and registered address** must appear in the site footer once the company is registered.

---

## Mistakes from the previous build — do not repeat

1. `mode:"no-cors"` on every write. Fatal for orders.
2. Secret admin key written in a public HTML file.
3. A password check in JavaScript treated as real security.
4. Uploaded ID documents stored on public "anyone with the link" Google Drive URLs.
5. Homepage images of 5 MB each — every image must be under 300 KB.
6. Redirect checks placed after the page renders, causing a visible flash. Any required-parameter check goes in a synchronous script at the top of `<head>`.
