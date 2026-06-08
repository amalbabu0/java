# Pre-Owned Vehicle Marketplace — Full Project Specification

> A platform connecting customers with pre-owned car and bike showrooms. The platform acts as a middleman, enabling shop owners to manage and showcase their inventory digitally while customers discover, compare, and enquire about vehicles.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [User Roles](#2-user-roles)
3. [Tech Stack](#3-tech-stack)
4. [Feature Specification by Role](#4-feature-specification-by-role)
   - [Shop Owner](#41-shop-owner)
   - [Customer](#42-customer)
   - [Association Admin](#43-association-admin)
   - [Super Admin](#44-super-admin)
5. [Subscription Model](#5-subscription-model)
6. [Verification System](#6-verification-system)
7. [Vehicle Data Handling](#7-vehicle-data-handling)
8. [Chat & Communication](#8-chat--communication)
9. [RC Transfer Tracker](#9-rc-transfer-tracker)
10. [Notifications](#10-notifications)
11. [Analytics Dashboards](#11-analytics-dashboards)
12. [Feature Roadmap](#12-feature-roadmap)
13. [System Architecture](#13-system-architecture)
14. [Key Business Rules](#14-key-business-rules)

---

## 1. Project Overview

This is a **pre-owned car and bike marketplace** where the platform acts as a trusted middleman between customers and registered showrooms/dealers.

**Core idea:**
- Shop owners get a digital storefront (like an Instagram profile) for their entire inventory.
- Customers can browse, filter, compare, and enquire about vehicles.
- The platform does not handle the financial transaction — it facilitates discovery and communication between buyer and seller.
- Each vehicle has an **Enquire** button (not a Buy button). The actual sale happens offline between the shop and the customer.

**Launch geography:** Single state first, with a roadmap to PAN India expansion.

**Target vehicles:** Bikes, scooters, cars, auto rickshaws, and commercial vehicles.

---

## 2. User Roles

| Role | Description |
|------|-------------|
| **Customer** | Browse, wishlist, compare, and enquire about vehicles |
| **Shop Owner** | List vehicles, manage inventory, chat with customers, track sales |
| **Association Admin** | District-level partner account with limited analytics access |
| **Super Admin** | Founder/founding team — full platform control |

---

## 3. Tech Stack

### Mobile Application
**Flutter** — single codebase for Android and iOS.

### Web Application
**Next.js (React)** — server-side rendering for SEO on vehicle listing and shop profile pages. Shop shareable URLs and vehicle pages must be indexed by Google for organic discovery.

### Backend API
**Node.js + Express** — single REST API shared between the Flutter mobile app and the Next.js web app.

### Database
**PostgreSQL** — primary relational database for all structured data (users, vehicles, subscriptions, sales, reviews, etc.)

### Real-Time Features
**Firebase** — real-time chat between customers and shop owners, and push notifications to mobile devices.

### Payments
**Razorpay** — in-app subscription payments supporting UPI, cards, and net banking.

### Media Storage
**Cloudinary** — vehicle photo uploads, storage, and optimised delivery.

### Caching
**Redis** — cache vehicle data fetched from the RTO/vehicle API so the API is only called once at listing creation and once per month for refresh. Prevents repeated API calls and reduces cost.

### Hosting (Recommended)
- Backend API + PostgreSQL: Railway or AWS EC2
- Next.js web: Vercel
- Redis: Railway or Upstash

---

## 4. Feature Specification by Role

### 4.1 Shop Owner

#### Onboarding
- Register with name, phone number, shop name, location (district), and GST number.
- GST number is validated via API before the account is activated.
- After GST validation, the account is auto-approved and the 30-day free trial begins.
- A notification is sent to the district's Association Admin to review the shop's genuinity in the background.
- After the trial ends, the shop owner must subscribe to continue listing vehicles.

#### Shop Profile Page
- Instagram-style grid displaying all listed vehicles.
- Shop profile includes: shop name, location, phone number (revealed only after enquiry), verified badge (if earned), rating, and total vehicles listed.
- A unique shareable URL is generated per shop (e.g. `platform.com/shop/shop-name`).
- **Guest view of the shareable URL:** Vehicle photos and shop name are visible, but price and full specs are blurred. A prompt encourages the guest to sign up to see full details and enquire.

#### Vehicle Listing
- Shop owner enters **only the vehicle registration number**.
- All vehicle details are fetched automatically via the RTO/vehicle API (make, model, year, engine CC, fuel type, colour, insurance expiry, RC details, etc.).
- The shop owner then adds: asking price (mandatory), photos (via Cloudinary), and any additional notes.
- Vehicle is published to the shop's profile and appears in search results.

#### Inventory Management
- View all listed vehicles in a grid or list view.
- Mark a vehicle as **Sold** (triggers the sale confirmation flow).
- Edit price or additional details at any time.
- Archive or delete a listing.
- View insurance expiry dates for all vehicles in one place.
- Track enquiries per vehicle.

#### Enquiry & Chat
- When a customer clicks Enquire, a chat thread is created between the customer and the shop owner.
- Chat is text-only inside the app.
- The shop owner's phone number is revealed inside the chat thread so the customer can call outside the app.
- Shop owner receives a push notification for every new enquiry.

#### Test Drive Booking
- Shop owners can enable test drive booking per listing.
- Two modes (set per listing):
  - **At shop** — customer comes to the showroom.
  - **Home delivery** — shop brings the vehicle to the customer's location.
- Customer selects a preferred date and time. Shop owner approves or proposes an alternative slot.
- Both parties receive a reminder notification the day before the scheduled test drive.

#### Sale Confirmation
- When a sale is agreed, the shop owner marks the vehicle as Sold in their inventory.
- The customer receives a notification to confirm the sale from their side.
- **Both parties must confirm** for the sale to be counted.
- After confirmation: the vehicle is marked as sold, the shop's confirmed sale count increases by 1, and the RC Transfer Tracker is automatically created for that vehicle.

#### Verified Badge
- Awarded automatically when a shop reaches **5 confirmed sales** (both parties confirmed).
- Displayed prominently on the shop profile and on all listing cards.

#### Shop Analytics Dashboard
- Total enquiries received (all time and this month)
- Enquiries per vehicle
- Most viewed vehicles
- Test drives booked vs completed
- Wishlist saves per vehicle (how many customers saved a vehicle)
- Profile views from the shareable URL
- Subscription status and days remaining

---

### 4.2 Customer

#### Onboarding
- Register with name, phone number, and location.
- **Guest browsing:** Customers can browse vehicle listings and shop profiles without logging in, but vehicle prices, full specs, and contact details are blurred. Login is required to see full details or send an enquiry.

#### Browse & Search
- Search all vehicles across all shops on the platform.
- **Filters available:**
  - Vehicle type (bike, scooter, car, auto, commercial)
  - Location / district
  - Price range
  - Year of manufacture
  - Fuel type
  - Brand / make
- Search for shops by name or location.
- New vehicle listings near the customer's saved location trigger push notifications (opted in).

#### Vehicle Detail Page
- Full vehicle details (fetched from RTO API): make, model, year, engine CC, BHP, fuel type, colour, insurance expiry date, RC details.
- Photos uploaded by the shop owner.
- Price set by the shop owner.
- Shop name and verified badge status.
- **Enquire button** — opens the chat thread.
- **EMI Calculator** — embedded on the page:
  - Vehicle price (pre-filled from the listing)
  - Down payment (customer enters)
  - Loan tenure in months (customer selects)
  - Interest rate (customer enters manually)
  - Calculated monthly EMI displayed instantly
- **Similar vehicles** section (v2) — comparable vehicles from other shops by CC and price range.

#### Wishlist
- Save any vehicle to a personal wishlist.
- Receive a push notification when the price of a wishlisted vehicle drops.

#### Vehicle Comparison
- Compare up to **3 vehicles** side by side.
- Comparison fields: CC, BHP, insurance due date, colour, manufacturing date, fuel type, price.
- Vehicles can be from different shops.

#### Enquiry & Chat
- Click Enquire on any vehicle to start a chat with the shop owner.
- Text chat only inside the app.
- Shop owner's phone number is revealed inside the chat so the customer can call.

#### Reviews
- Any customer who has sent at least one enquiry to a shop can leave a public review.
- Reviews are visible on the shop's profile page.
- Shop owners cannot reply to reviews.

#### RC Transfer Tracker (read-only)
- After a sale is confirmed, the customer can view the current RC transfer stage from their profile (read-only view).

---

### 4.3 Association Admin

One Association Admin account per district. These are partner organisations who help onboard and monitor shops in their district.

#### Dashboard
- Total number of shops registered under their district
- Total number of confirmed sales across all shops in their district (count only — no revenue or price data)
- List of shops with registration date and subscription status
- Notifications when a new shop registers in their district (for genuinity review)

#### Permissions
- Can view shop profiles and listings
- **Cannot** access any financial data (subscription amounts, vehicle prices, sale amounts)
- Cannot modify any shop data
- Can flag a suspicious shop to the Super Admin

#### Reports (v2)
- Downloadable PDF monthly activity report: new shops, vehicles listed, sales confirmed, enquiries made — all within their district.

---

### 4.4 Super Admin

Accessible only to the founding team. Single role, not assignable to others.

#### Platform Dashboard
- Total active shops (subscribed)
- Total shops in free trial
- Total vehicles listed
- Total enquiries made (platform-wide)
- Total confirmed sales (platform-wide)
- Subscriptions active vs expired
- Verified badges awarded

#### Shop Management
- View all shops across all districts
- View individual shop details: GST number, subscription plan, sale count, verified status
- Manually override or extend a shop's subscription (useful for pilot deals or support cases)
- Suspend or deactivate a shop account
- View GST verification log (which shops passed/failed and when)

#### Flagging & Moderation
- Customers can report a shop or listing
- Association Admins can flag suspicious shops
- Super Admin reviews all flags and takes action

#### Communication
- Banner/announcement system: push a notice to all shop owners or all customers (e.g. platform updates, new features, maintenance windows)

#### Association Admin Management
- Create and manage Association Admin accounts per district

---

## 5. Subscription Model

Shop owners must subscribe after the 30-day free trial to continue listing vehicles and receiving enquiries.

| Plan | Price | Vehicle Listing Limit |
|------|-------|-----------------------|
| Basic | ₹299 / month | Unlimited |
| Premium | ₹599 / month | Unlimited |

### Premium Benefits (Boost)
1. **Top of search results** — premium shop vehicles appear above basic plan vehicles in search and browse results.
2. **Push notification to nearby customers** — new vehicle listings from premium shops trigger push notifications to customers in the same district.
3. **More photos per vehicle** — premium shops can upload more photos per listing than basic plan shops.

### Subscription Expiry
When a subscription expires and is not renewed:
- All listings remain visible on the platform.
- The shop profile shows an **"Inactive Shop"** label.
- The **Enquire button is disabled** — customers cannot start new chats.
- Existing chat threads remain accessible.
- The shop owner receives reminder notifications before expiry and after expiry urging them to renew.

### Payment
- Handled in-app via **Razorpay** (UPI, cards, net banking).
- Auto-renewal prompt sent before expiry date.

---

## 6. Verification System

### GST Verification
- Required at shop registration.
- Validated via GST API before account activation.
- If GST validation fails, the shop owner is prompted to re-enter or contact support.
- GST verification log is visible to Super Admin.

### Association Admin Review
- After GST passes and account is auto-approved, a notification is sent to the Association Admin of the relevant district.
- The Association Admin reviews the shop's genuinity in the background.
- If they find something suspicious, they flag it to the Super Admin.
- This is a background review — the shop is live immediately after GST verification.

### Verified Badge
- Automatically awarded after **5 confirmed sales** where both the shop owner and customer confirmed each sale.
- Displayed on the shop profile and on all vehicle listing cards from that shop.
- Cannot be purchased or manually assigned (except by Super Admin in exceptional cases).

---

## 7. Vehicle Data Handling

### Adding a Vehicle
1. Shop owner enters the vehicle registration number.
2. The platform calls the RTO/vehicle API (e.g. Vahan, vehicleinfo.in, or similar) to fetch vehicle details.
3. API response is stored in the database and cached in Redis.
4. Shop owner adds price, photos, and optional notes.
5. The listing goes live.

### Data Fetched from API
- Make and model
- Year of manufacture
- Engine CC
- Fuel type
- Colour
- Insurance expiry date
- RC status and ownership details
- (Any additional fields the chosen API returns)

### API Call Rules
- The API is called **only once** when the vehicle is first added.
- The API is called **automatically once per month** to refresh vehicle details (insurance expiry date changes, ownership transfer updates, etc.).
- All other reads use the cached data from Redis / the database — the API is never called on every page view.

### Photos
- Shop owner uploads photos manually via Cloudinary.
- Basic plan: limited number of photos per vehicle.
- Premium plan: higher photo limit per vehicle.

---

## 8. Chat & Communication

### In-App Chat
- Text-only chat between customer and shop owner.
- Powered by Firebase Realtime Database or Firestore.
- Chat thread is created when a customer clicks Enquire on a vehicle.
- Shop owner sees all active chat threads in an inbox.

### Phone Number Reveal
- The shop owner's phone number is displayed inside the chat thread.
- The customer can then call the shop owner directly outside the app.
- This keeps the platform simple (no in-app calling infrastructure needed) while still enabling voice communication.

### Enquiry Inbox (v1)
- Shop owners can tag enquiries with status labels:
  - New
  - In discussion
  - Test drive scheduled
  - Sold
- Helps shop owners manage multiple simultaneous enquiries.

---

## 9. RC Transfer Tracker

Triggered automatically after both parties confirm a sale. Tracks the RC (Registration Certificate) ownership transfer process.

### Stages

| Stage | Description |
|-------|-------------|
| 1. Documents collected | Shop owner has collected all required documents from the buyer |
| 2. Form 29/30 submitted | Transfer application submitted at the RTO |
| 3. Hypothecation cleared | If the vehicle had a loan, the bank's hypothecation has been removed |
| 4. RC copy received | New RC with updated ownership has been received |
| 5. Transfer complete | Full transfer done |

### How It Works
- **Shop owner** updates the current stage manually as things progress.
- **Customer** has a read-only view of the current stage from their profile.
- If a stage has not changed in **7 days**, both the shop owner and customer receive an automated reminder notification.
- Super Admin can view all stuck transfers across the platform as a health metric.

---

## 10. Notifications

| Notification | Recipient | Trigger |
|-------------|-----------|---------|
| New enquiry alert | Shop owner | Customer sends first message |
| Test drive reminder | Both parties | Day before scheduled test drive |
| Insurance expiry reminder | Shop owner | 30 days before vehicle insurance expires |
| Subscription renewal reminder | Shop owner | 7 days before subscription expires |
| Price drop alert | Customer | Price of a wishlisted vehicle is reduced |
| New vehicle nearby | Customer | New listing in customer's district |
| RC transfer stuck | Both parties | Transfer stage unchanged for 7 days |
| New shop registered | Association Admin | New shop signs up in their district |
| Shop genuinity flag | Super Admin | Association Admin flags a shop |

All push notifications are delivered via **Firebase Cloud Messaging (FCM)**.

---

## 11. Analytics Dashboards

### Shop Owner Dashboard
| Metric | Description |
|--------|-------------|
| Total enquiries | All-time and this month |
| Enquiries per vehicle | Which listings are getting the most interest |
| Most viewed vehicles | Top listings by page views |
| Test drives booked | Total booked vs completed |
| Wishlist saves | How many customers saved each vehicle |
| Profile views | Views from the shareable shop URL |
| Subscription status | Current plan and days remaining |

### Association Admin Dashboard
| Metric | Description |
|--------|-------------|
| Shops in district | Total registered shops |
| Active subscriptions | Shops with active plans |
| Confirmed sales | Total sale count in the district (no amounts) |
| New shop alerts | Shops pending genuinity review |

### Super Admin Dashboard
| Metric | Description |
|--------|-------------|
| Active shops | Subscribed shop count |
| Shops in trial | Free trial shops |
| Total vehicles listed | Platform-wide inventory count |
| Total enquiries | Platform-wide enquiry count |
| Confirmed sales | Total sales across all shops |
| Subscription health | Active vs expired subscriptions |
| Flagged shops | Shops under review |
| Verified badges given | Count of verified shops |

---

## 12. Feature Roadmap

### MVP — Months 1 to 3
*Core loop: list → browse → enquire*

- Auth & onboarding (GST verification, 30-day trial, role-based accounts)
- Vehicle listing (registration number → auto-fetch via API)
- Shop profile page (shareable URL, blurred guest view)
- Inventory management (mark sold, edit price, manage status)
- Browse & search (filters by type, location, price)
- Enquiry & chat (text chat + phone number reveal)
- Wishlist
- Subscription & payments (₹299/₹599 via Razorpay, inactive label on expiry)
- Super admin panel (shops, listings, subscriptions, flagging)
- Core notifications (new enquiry, subscription renewal, insurance expiry)

### v1 — Months 4 to 7
*Trust, transactions & discovery*

- Premium boost (top of search, push to nearby users, more photos)
- Shop analytics dashboard
- Test drive booking (at-shop or home delivery, day-before reminder)
- Sale confirmation flow (both parties confirm)
- RC transfer tracker (5-stage pipeline, 7-day stuck alert)
- Verified badge (auto-awarded after 5 sales)
- Vehicle comparison (up to 3 vehicles)
- EMI calculator (on vehicle detail page)
- Public reviews (post-enquiry, visible on shop profile)
- Association admin dashboard (district analytics, genuinity notifications)
- Full notifications (price drop, test drive reminder, new vehicle nearby, RC stuck)

### v2 — Months 8 to 12
*Scale to PAN India + growth features*

- Service history upload (shop attaches past service records to vehicles)
- Enquiry inbox status tags (new → discussing → test drive → sold)
- Referral program (invite shops, earn subscription credits)
- Similar vehicle recommendations (on vehicle detail page)
- Vehicle condition grading (standardised A/B/C grade on listing cards)
- Multilingual support (Tamil, Hindi, Telugu, Kannada)
- Monthly downloadable reports for Association Admins
- Banner/announcement system for Super Admin
- PAN India expansion (multi-state association admins, geo-based boosting)
- Automatic monthly vehicle API refresh (scheduled background job)

---

## 13. System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│                        Clients                          │
│   Flutter Mobile App      Next.js Web App               │
│   (iOS + Android)         (SSR for SEO)                 │
└──────────────┬───────────────────┬──────────────────────┘
               │                   │
               ▼                   ▼
┌─────────────────────────────────────────────────────────┐
│              Node.js + Express REST API                  │
│         (Shared backend for mobile and web)              │
└──┬──────────┬──────────┬────────┬────────────┬──────────┘
   │          │          │        │            │
   ▼          ▼          ▼        ▼            ▼
PostgreSQL  Firebase   Redis   Razorpay    Cloudinary
(main DB)  (chat +    (API    (payments)  (photos)
           push)      cache)
               │
               ▼
        RTO / Vehicle API
        (registration number lookup)
```

### API Layer
- Single Node.js + Express backend serves both Flutter and Next.js.
- REST API with JWT-based authentication.
- Role-based access control for all endpoints (customer, shop owner, association admin, super admin).

### Database (PostgreSQL) — Core Tables
- `users` — all users regardless of role
- `shops` — shop owner profiles, GST, subscription status
- `vehicles` — all listings with fetched API data and shop owner additions
- `enquiries` — chat thread metadata
- `messages` — chat messages (mirrored from Firebase for backup)
- `sales` — confirmed sales records
- `subscriptions` — subscription history and status
- `reviews` — customer reviews per shop
- `test_drives` — booking records
- `rc_transfers` — RC transfer stage tracking
- `notifications` — notification log
- `flags` — reported shops and listings
- `association_admins` — district admin accounts

### Real-Time Layer (Firebase)
- Firestore or Realtime Database for live chat messages.
- Firebase Cloud Messaging (FCM) for push notifications to Flutter mobile.
- Web push handled via FCM + Next.js service worker.

### Caching Layer (Redis)
- Vehicle API response cached per registration number.
- Cache TTL aligned with monthly refresh schedule.
- Session/token caching for performance.

### Media (Cloudinary)
- Direct upload from Flutter and Next.js to Cloudinary.
- Signed upload URLs generated by the backend.
- Optimised image delivery (auto WebP, responsive sizes).

### Scheduled Jobs (Backend)
- Monthly vehicle API refresh: background job checks all active listings and re-calls the vehicle API to update insurance expiry and other fields.
- Subscription expiry checks: daily job to flag expired subscriptions and send renewal reminders.
- RC transfer stuck check: daily job to find transfers with no stage update in 7 days and send reminders.
- Insurance expiry reminders: daily job to find vehicles expiring within 30 days and notify shop owners.

---

## 14. Key Business Rules

| Rule | Detail |
|------|--------|
| Free trial | 30 days full access. Subscription required after trial ends. |
| Listing limit | No limit on either plan. Differentiated by boost features. |
| Subscription expiry | Listings visible, enquiry button disabled, "Inactive Shop" label shown. |
| Sale confirmation | Both shop owner and customer must confirm. Only then does the count increase and RC tracker start. |
| Verified badge | Auto-awarded at 5 confirmed sales. Cannot be purchased. |
| Vehicle API | Called once at listing creation, then once per month automatically. Never on every page view. |
| Reviews | Only customers who have sent an enquiry to the shop can review it. |
| GST validation | Required to activate account. Auto-approved after passing. Association Admin notified in background. |
| Guest browsing | Vehicle photos and names visible. Price and full specs blurred. Login required to enquire. |
| Association Admin data access | Can see shop count and sale count only. No revenue, price, or financial data. |
| Revenue model | Subscription only for now. Commission per sale may be added in a future version. |
| Geography | Single state at launch. PAN India in v2. |
| Languages | English at launch. Regional languages (Tamil, Hindi, Telugu, Kannada) in v2. |
| Super admin role | Founder only. Not assignable to other staff. |

---

*Document last updated: June 2026*
*Version: 1.0 — Pre-development specification*
