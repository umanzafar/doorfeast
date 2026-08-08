# DoorFeast — Project Rules for Claude Code

Read this file at the start of every session. Follow it exactly. Do not deviate without asking.

This file replaces the old, smaller-scope CLAUDE.md and absorbs MARKETPLACE_STRUCTURE.md — this is now the single source of truth for the project. There is no separate marketplace-structure document anymore; everything lives here.

---

## What we are building

An online food ordering marketplace for independent takeaways in Stoke-on-Trent, UK, with room to grow into a full platform (accounts, reviews, promotions, staff roles, reporting) over time.

- Customers order food online and pay by card, Apple Pay or Google Pay.
- Takeaways do their own delivery or collection. We do NOT have drivers.
- We charge the takeaway 12% commission by default (stored per-restaurant, so it can be overridden later).
- A £0.50 customer service fee is INCLUDED INSIDE displayed item prices. It is NEVER added as a separate line at checkout. (UK law: DMCC Act 2024 — mandatory fees must be in the headline price.)

**Current phase — Phase 1 (pilot):** 2 takeaways owned by the co-founder. Real customers, real card payments, guest checkout only. Get one real paid order flowing end-to-end before building anything past that. See "Build dependency order" near the bottom — Phase 1 is Steps 1–7. Everything from Step 8 onward (payouts/ledger, full admin panel, customer accounts, reviews, promotions, referrals, reports) is real, planned work, but **not yet** — don't build it until asked, even though the roles/tables/pages for it are documented below.

---

## Stack — do not change without asking

- **Frontend:** plain HTML/CSS/JS, one self-contained file per page. No React, no build step.
- **Database + Auth:** **Supabase** (Postgres), including Realtime and Storage.
- **Backend/server-side logic:** **Supabase Edge Functions** — this is where secret keys live and where anything needing `service_role` or the Stripe secret key runs (same pattern as the existing `decide-application` function). We do **not** use Vercel or any `/api` folder — an earlier planning doc assumed Vercel; that's superseded. Edge Functions are deployed by pasting the file into the Supabase Dashboard → Edge Functions → Deploy.
- **Payments:** **Stripe Connect** — each restaurant onboards its own Connect account; customer payment is a destination charge with the commission taken as an application fee at the top. Payment UI is Stripe Payment Element or Stripe Checkout, with card, Apple Pay and Google Pay enabled.
- **Hosting:** Hostinger VPS (Apache), serving the plain HTML/CSS/JS pages directly. Server-side/secret-holding logic runs in Supabase Edge Functions, not on the VPS.

**We are fully off Google Apps Script. Do not write any new Apps Script code.**

---

## HARD RULES — never break these

1. **Never use `fetch(..., {mode:"no-cors"})`.** The old code did this everywhere. It sends data and never learns if it worked. Orders will silently vanish. Every write must read the response and handle errors.

2. **Never put a secret key in frontend code.** Stripe secret key, Stripe Connect webhook signing secret, Supabase `service_role` key, and any admin key live ONLY as Supabase Edge Function secrets (Dashboard → Edge Functions → Secrets), used ONLY inside Edge Functions.
   - Supabase `anon` key in the frontend is fine — that is its purpose.
   - Stripe **publishable** key (`pk_`) in frontend is fine. Stripe **secret** key (`sk_`) is NOT.

3. **Never protect anything with a JavaScript password check.** Real protection is server-side only — RLS policies, Edge Function auth checks, or (for whole-page pre-launch gates) server-level HTTP auth on the VPS. Never a password compared in browser JS.

4. **Row Level Security (RLS) must be ON for every Supabase table**, with explicit policies. Never leave a table open. After creating any table, show the policies written for it.

5. **All money is stored as integer pence.** Never use floats or decimals for money. `1250` = £12.50.

6. **Never trust a value sent from the browser for pricing.** Recalculate the order total on the server (in the Edge Function) from database prices before creating the Stripe payment. A customer can edit anything in their browser.

7. **A restaurant cannot go live or take real orders until its Stripe Connect account is fully onboarded** (`charges_enabled = true` from Stripe). Don't build a path that lets `is_live = true` happen before that check passes.

8. **Allergens must be shown on every menu item before purchase**, and the field cannot be empty. (UK Food Information Regulations.)

---

## 1. User roles

| Role | Who | Access |
|---|---|---|
| **Guest** | Anyone browsing | Public pages, browse menus, guest checkout |
| **Customer** | Registered buyer (Phase 2+) | Account, order history, saved addresses, referrals |
| **Restaurant owner** | Takeaway owner | Full dashboard for their own restaurant only |
| **Restaurant staff** | Kitchen / counter staff (Phase 2+) | Order screen only. No payouts, no business settings |
| **Admin** | Founder and co-founder | Everything across all restaurants |
| **Support agent** | Later hire (Phase 2+) | Orders, refunds, customers. No financial settings |

In Phase 1, only Guest, Restaurant owner, and Admin actually exist. Guest checkout only — no customer login in Phase 1.

---

## 2. Customer-facing pages

### Discovery
| Page | Contents | Phase |
|---|---|---|
| `/` Homepage | Postcode search, how it works, trust signals, cuisine shortcuts | 1 |
| `/r/[slug]` Restaurant page | Full menu, hours, fees, hygiene rating, reviews | 1 (reviews come later) |
| `/search` Results | Filters: cuisine, open now, delivery/collection, min order, hygiene rating | 2 |
| `/cuisine/[type]` | Browse by cuisine | 2 |
| `/area/[town]` | Landing pages for Burslem, Hanley, Tunstall etc. — SEO | 2 |

### Ordering
| Page | Contents | Phase |
|---|---|---|
| `/basket` (or in-page panel) | Items, quantities, options, collection/delivery toggle, promo code, totals | 1 (promo code Phase 2) |
| `/checkout` | Contact details, address, delivery time, payment, allergen notice | 1 |
| `/order/[number]` | Live status tracking, restaurant contact, order summary | 1 |
| `/order/[number]/receipt` | Printable receipt | 1 |

### Account (Phase 2+)
`/login` `/register` (email/password, Google, magic link) · `/account` · `/account/orders` · `/account/addresses` · `/account/payments` · `/account/referrals` · `/account/notifications` · `/account/delete` (UK GDPR right to erasure)

### Information
`/how-it-works` · `/about` · `/help` · `/help/[article]` · `/contact` · `/allergens` · `/partners` (for takeaways) · `/blog` (optional, SEO) — Phase 2, except a minimal `/partners`-equivalent already exists via signup.html.

---

## 3. Restaurant dashboard

| Section | Function | Phase |
|---|---|---|
| **Order inbox** (`/pos`) | Live orders, loud alert, accept/reject, prep time, mark ready, print ticket. Runs on the kitchen tablet | 1 |
| **Menu management** | Categories, items, prices, descriptions, photos, allergens, availability toggle | 1 |
| **Business info** | Name, address, phone, cuisine, description, logo, cover photo | 1 |
| **Opening hours** | Weekly hours, holiday closures, temporary "closed now" switch | 1 |
| **Delivery settings** | Delivery postcodes, fee per zone, minimum order, estimated times, collection on/off | 1 |
| **Order history** | Past orders, search, filter by date, export CSV | 2 |
| **Payouts** | Balance, payout schedule, past payouts, statements (gross/commission/net) | 2 |
| **Reports** | Orders per day/week, revenue, AOV, top items, rejection rate, busiest hours | 2 |
| **Promotions** | Restaurant-funded discounts | 2 |
| **Reviews** | Customer reviews, reply to reviews | 2 |
| **Staff accounts** | Order-screen-only access for staff | 2 |
| **Documents** | Hygiene cert, insurance, business registration, expiry reminders | 2 (upload already happens at application time) |
| **Settings** | Stripe Connect bank details, notification preferences | 1 (Connect onboarding is Phase 1; everything else Phase 2) |
| **Option groups** | Sizes, toppings, extras per menu item — a pizza shop cannot sell without this | 1 — needed early; schema for it must exist before real menus can be fully modelled |

---

## 4. Admin panel

| Section | Function | Phase |
|---|---|---|
| **Applications** | Review new takeaways, view documents, approve/reject with reason | 1 (done) |
| **Restaurants** | All restaurants, set live/offline, edit anything, override commission rate, suspend | 1 |
| **Orders** | Every order across the platform, search, investigate, manually change status | 1 |
| **Refunds** | Full or partial refunds, reason codes, refund history | 1 (needed as soon as real orders exist) |
| **Payouts** | Payout runs, failed payouts, adjustments, commission reconciliation | 2 |
| **Customers** | Search customers, order history, issue credit, block abusive accounts | 2 |
| **Promotions** | Platform-funded campaigns, discount codes, referral settings | 2 |
| **Reports** | GMV, order count, commission earned, new vs repeat customers, league table, cohort retention | 2 |
| **Support** | Ticket queue, order-linked complaints | 2 |
| **Content** | Help articles, area pages, homepage banners | 2 |
| **Compliance** | HMRC platform-operator seller records, annual report export, document expiry tracking | 2 |
| **Settings** | Commission rate, service fee, minimum order defaults, live postcodes | 2 |
| **Audit log** | Every admin action recorded: who, what, when | 1 — cheap to add early, do it alongside Orders/Refunds |

---

## 5. Database schema

Tables are created in dependency order. RLS is ON for every table, with explicit policies — no table is ever left open. A restaurant can only read/write its own rows; a customer (once accounts exist) can only read their own orders.

### Restaurants
| Table | Key fields |
|---|---|
| `restaurants` | id, name, slug, description, address, postcode, lat, lng, phone, email, cuisine, logo_url, cover_url, is_live, is_open_now, commission_rate, min_order_pence, delivery_fee_pence, delivery_postcodes, prep_time_minutes, stripe_account_id, fhrs_rating, fhrs_id, owner_user_id, created_at |
| `restaurant_users` | id, restaurant_id, user_id, role (owner/staff), created_at |
| `opening_hours` | id, restaurant_id, day_of_week, opens_at, closes_at, is_closed |
| `special_hours` | id, restaurant_id, date, opens_at, closes_at, is_closed, reason |
| `delivery_zones` | id, restaurant_id, postcode_prefix, delivery_fee_pence, min_order_pence, estimated_minutes |
| `restaurant_documents` | id, restaurant_id, type, file_path, expires_at, verified_at, verified_by |
| `restaurant_applications` | id, user_id, business_name, owner_name, phone, email, address, cuisine, hygiene_cert_path, business_reg_path, id_doc_path, status, reject_reason, restaurant_id, created_at, decided_at |

### Menu
| Table | Key fields |
|---|---|
| `menu_categories` | id, restaurant_id, name, description, sort_order, is_active |
| `menu_items` | id, restaurant_id, category_id, name, description, price_pence, photo_url, allergens[] (required, non-empty), is_available, is_vegetarian, is_vegan, is_spicy, sort_order |
| `option_groups` | id, menu_item_id, name ("Size", "Extras"), is_required, min_choices, max_choices, sort_order |
| `option_choices` | id, option_group_id, name ("Large", "Extra cheese"), price_delta_pence, is_available, sort_order |

### Customers (Phase 2)
| Table | Key fields |
|---|---|
| `customers` | id, user_id, name, email, phone, marketing_opt_in, credit_balance_pence, referral_code, referred_by, created_at |
| `customer_addresses` | id, customer_id, label, line1, line2, city, postcode, lat, lng, delivery_notes, is_default |

### Orders
| Table | Key fields |
|---|---|
| `orders` | id, order_number, restaurant_id, customer_id (nullable for guest), guest_name, guest_phone, guest_email, order_type (collection/delivery), delivery_address, scheduled_for, subtotal_pence, delivery_fee_pence, discount_pence, total_pence, commission_pence, stripe_fee_pence, restaurant_payout_pence, promo_code, status, payment_status, customer_note, rejection_reason, created_at, accepted_at, ready_at, completed_at |
| `order_items` | id, order_id, menu_item_id, item_name, item_price_pence, quantity, line_total_pence, note |
| `order_item_options` | id, order_item_id, option_name, choice_name, price_delta_pence |
| `order_status_history` | id, order_id, from_status, to_status, changed_by, changed_at |

**Why `order_items` copies `item_name`/`item_price_pence`:** if the restaurant changes their menu next week, old orders must still show what was actually bought and paid. Never join to `menu_items` to display an old order.

### Money
| Table | Key fields |
|---|---|
| `payments` | id, order_id, stripe_payment_intent_id, amount_pence, currency, method (card/apple_pay/google_pay), status, failure_reason, created_at |
| `refunds` | id, order_id, payment_id, stripe_refund_id, amount_pence, reason, issued_by, created_at |
| `payouts` | id, restaurant_id, period_start, period_end, gross_pence, commission_pence, refunds_pence, adjustments_pence, net_pence, stripe_transfer_id, status, paid_at |
| `ledger` | id, restaurant_id, order_id, type (commission/refund/adjustment/payout), amount_pence, description, created_at |

**The ledger is the single source of truth for money owed.** Every financial event writes one row.

### Marketing (Phase 2)
| Table | Key fields |
|---|---|
| `promotions` | id, code, type (percent/fixed/free_delivery), value, min_order_pence, max_discount_pence, funded_by (platform/restaurant), restaurant_id, starts_at, ends_at, usage_limit, per_customer_limit, first_order_only, is_active |
| `promotion_uses` | id, promotion_id, order_id, customer_id, discount_pence, used_at |
| `referrals` | id, referrer_customer_id, referred_customer_id, referrer_credit_pence, referred_credit_pence, qualifying_order_id, status |
| `reviews` | id, order_id, restaurant_id, customer_id, rating, comment, restaurant_reply, is_published, created_at |

### Platform
| Table | Key fields |
|---|---|
| `admins` | user_id, created_at |
| `notifications` | id, type, channel (email/sms/push), recipient, order_id, template, status, sent_at, error |
| `support_tickets` | id, order_id, customer_id, restaurant_id, subject, status, priority, assigned_to, created_at |
| `ticket_messages` | id, ticket_id, sender_type, sender_id, message, created_at |
| `audit_log` | id, actor_id, actor_type, action, entity_type, entity_id, before, after, ip_address, created_at |
| `platform_settings` | key, value — commission rate default, service fee, live postcodes |

---

## 6. Order lifecycle

```
cart
  ↓ customer pays
pending_payment
  ↓ Stripe webhook confirms
paid ──────────────→ restaurant is notified
  ↓ restaurant accepts        ↓ restaurant rejects
accepted                    rejected → auto refund
  ↓
preparing
  ↓
ready
  ↓ (delivery)          ↓ (collection)
out_for_delivery      awaiting_collection
  ↓                     ↓
completed             completed

Any state → cancelled → refund
```

**Rules**
- An order becomes visible to the restaurant only when `payment_status = 'paid'`.
- Payment is confirmed by the Stripe **webhook** (Supabase Edge Function), never by the browser.
- Auto-reject if not accepted within 10 minutes, with automatic refund.
- Every status change writes a row to `order_status_history`.

---

## 7. Money flow (Stripe Connect)

```
Customer pays £22.50
        ↓
   Stripe (Connect destination charge)
        ↓
   ├─ 12% commission (application fee) → DoorFeast
   └─ remainder → restaurant's connected account
        ↓
   Stripe fee deducted (~1.5% + 20p)
        ↓
   Payout to restaurant bank account (Stripe-managed)
```

**Rules**
- Prices stored as integer pence. Never floats.
- The £0.50 service fee is inside displayed item prices, never a separate checkout line (DMCC Act 2024).
- Totals are recalculated server-side (Edge Function) from database prices before payment. Never trust the browser.
- Commission is calculated and stored on the order at the moment it is placed, so a later rate change doesn't rewrite history.
- Refunds return the commission to the restaurant proportionally.
- A restaurant must complete Stripe Connect onboarding (`charges_enabled = true`) before it can be set `is_live = true`.

---

## 8. Notifications (Phase 2, except order-placed alert which is Phase 1)

| Event | Customer | Restaurant | Phase |
|---|---|---|---|
| Order placed | Email + SMS confirmation | Loud alert on POS + SMS backup | 1 (POS alert), 2 (email/SMS) |
| Order accepted | Push/SMS with time estimate | — | 2 |
| Order rejected | Email + SMS with refund notice | — | 2 |
| Order ready | SMS | — | 2 |
| Out for delivery | SMS | — | 2 |
| Refund issued | Email | Email | 2 |
| Weekly payout | — | Email statement | 2 |
| Document expiring | — | Email reminder at 30 and 7 days | 2 |

---

## 9. External services

| Service | Purpose |
|---|---|
| **Supabase** | Postgres database, auth, realtime order updates, file storage, Edge Functions |
| **Stripe Connect** | Payments, commission split, restaurant payouts |
| **Hostinger VPS (Apache)** | Hosting for the static HTML/CSS/JS pages |
| **postcodes.io** | Free UK postcode lookup and coordinates (already integrated on the homepage) |
| **Resend or Postmark** | Transactional email (Phase 2) |
| **Twilio or MessageBird** | SMS (Phase 2) |
| **FSA Food Hygiene Rating API** | Free hygiene ratings — food.gov.uk (Phase 2) |
| **Sentry** | Error monitoring (Phase 2) |
| **Plausible or GA4** | Analytics — requires cookie consent (Phase 2) |

---

## 10. Security requirements

- Row Level Security on every Supabase table, with explicit policies.
- A restaurant can only read and write its own rows.
- A customer (once accounts exist) can only read their own orders.
- Secret keys only as Supabase Edge Function secrets, only used inside Edge Functions — never in frontend code, never in a Vercel-style `/api` folder (we don't use Vercel).
- Stripe secret key, Stripe webhook signing secret, Supabase `service_role` key never in frontend code.
- No password checks in JavaScript.
- All writes read the response and handle errors — never `mode:"no-cors"`.
- Uploaded documents in private Supabase Storage, access controlled by RLS (signed/expiring URLs if a public link is ever needed).
- Rate limiting on checkout, login and application submission.
- Card details never touch our servers — Stripe hosted fields only (PCI SAQ-A).
- Every admin action written to the audit log.
- Daily database backups (check this is enabled on the Supabase plan tier in use).

---

## 11. Legal pages

| Page | Notes | Phase |
|---|---|---|
| `/terms` | Customer terms and conditions | 1 — required before any real order |
| `/privacy` | Privacy policy | 1 — required before any real order |
| `/cookies` | Cookie policy | 1 — required before any real order |
| `/refunds` | Refund and cancellation policy | 1 |
| `/partner-agreement` | Takeaway partner agreement | 1 |
| Cookie consent banner | Refusal must be as easy as acceptance | 1 |
| Footer | Company name, number, registered office, contact details — add once the company is registered | 1 |

**Compliance obligations built into the platform**
- Allergens displayed before purchase and printed on the order ticket for delivery.
- Service fee inside headline prices (DMCC Act 2024).
- HMRC platform-operator reporting — seller due diligence records and annual export (Phase 2, but keep in mind from Phase 1 — start keeping the records now).
- ICO registration.
- Data export and account deletion for customers (UK GDPR) — Phase 2, once accounts exist.

---

## 12. Build dependency order

You cannot build these out of order — each depends on the one before. **Steps 1–7 are Phase 1** (the pilot, the current focus). Nothing after Step 7 works until real orders exist, and nothing after Step 7 should be built before Step 7 is done and tested.

```
1. Database schema + RLS
2. Restaurant records + menu data (seed by hand for the 2 pilot restaurants for now)
3. Restaurant page (browse menu) — real Supabase data, not placeholder
4. Basket
5. Checkout + Stripe Connect payment + webhook (Edge Functions)
6. Order inbox on POS (Realtime, sound alert, accept/reject, print)
7. Order status tracking + notifications (POS alert is Phase 1; email/SMS is Phase 2)
── Phase 1 ends here — test one real order start to finish in the Burslem shop ──
8. Menu management dashboard (done, ahead of schedule)
9. Payouts + ledger
10. Admin panel (Restaurants, Orders, Refunds, Audit log first; Reports/Content/Compliance later)
11. Customer accounts + order history
12. Reviews, promotions, referrals
13. Reports and analytics
```

---

## Mistakes from the previous build — do not repeat

1. `mode:"no-cors"` on every write. Fatal for orders.
2. Secret admin key written in a public HTML file.
3. A password check in JavaScript treated as real security.
4. Uploaded ID documents stored on public "anyone with the link" Google Drive URLs.
5. Homepage images of 5 MB each — every image must be under 300 KB.
6. Redirect checks placed after the page renders, causing a visible flash. Any required-parameter or auth check goes as early as possible — synchronous where the check itself is synchronous (e.g. a URL param), or with the page content hidden until an async check (e.g. Supabase session) resolves.
