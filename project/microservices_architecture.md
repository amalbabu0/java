# Microservices Architecture — Pre-Owned Vehicle Marketplace

> This document outlines every microservice the platform needs, what each one does, which tech it uses, what database/cache it owns, and how it communicates with other services.

---

## Table of Contents

1. [Architecture Philosophy](#1-architecture-philosophy)
2. [Service Map Overview](#2-service-map-overview)
3. [Microservices — Detailed Breakdown](#3-microservices--detailed-breakdown)
   - [API Gateway](#31-api-gateway)
   - [Auth Service](#32-auth-service)
   - [User Service](#33-user-service)
   - [Shop Service](#34-shop-service)
   - [Vehicle Service](#35-vehicle-service)
   - [Vehicle API Integration Service](#36-vehicle-api-integration-service)
   - [Search & Filter Service](#37-search--filter-service)
   - [Enquiry & Chat Service](#38-enquiry--chat-service)
   - [Notification Service](#39-notification-service)
   - [Subscription & Payment Service](#310-subscription--payment-service)
   - [Review Service](#311-review-service)
   - [Test Drive Service](#312-test-drive-service)
   - [Sale & RC Transfer Service](#313-sale--rc-transfer-service)
   - [Analytics Service](#314-analytics-service)
   - [Admin Service](#315-admin-service)
   - [Media Service](#316-media-service)
   - [Scheduler Service](#317-scheduler-service)
4. [Inter-Service Communication](#4-inter-service-communication)
5. [Shared Infrastructure](#5-shared-infrastructure)
6. [Database Ownership Per Service](#6-database-ownership-per-service)
7. [External Integrations](#7-external-integrations)
8. [MVP vs Full Microservices Strategy](#8-mvp-vs-full-microservices-strategy)

---

## 1. Architecture Philosophy

### Why Microservices for This Platform?

This platform has **distinct domains** that scale differently and change at different rates:

- Vehicle listings and search get the most traffic — they need to scale independently.
- Chat is real-time and has different infrastructure needs (Firebase) from the rest.
- The vehicle API integration has strict rate limits and needs its own caching logic.
- Payments and subscriptions are sensitive and should be isolated from other services.
- The scheduler runs background jobs independently of user-facing traffic.

### Core Principles

- **Each service owns its own data.** No service reads directly from another service's database. Data is shared through API calls or events.
- **Services communicate via REST (synchronous) or an event/message queue (asynchronous).**
- **The API Gateway is the single entry point** for all clients (Flutter mobile and Next.js web). Clients never call individual services directly.
- **Fail gracefully.** If the Vehicle API Integration Service is down, the rest of the platform keeps running using cached data.

### When to Start with a Monolith

If you are a small team (1–3 developers), **start with a modular monolith** — all services as separate modules inside one Node.js application, sharing one PostgreSQL database. Structure the code so each module can be extracted into its own service later. Move to full microservices as the team grows or when a specific service needs independent scaling.

---

## 2. Service Map Overview

```
Clients (Flutter App + Next.js Web)
           │
           ▼
    ┌─────────────────┐
    │   API Gateway   │  — Single entry point, routing, auth validation, rate limiting
    └────────┬────────┘
             │
    ┌────────▼────────────────────────────────────────────────────┐
    │                    Internal Services                         │
    │                                                              │
    │  Auth       User       Shop       Vehicle     Vehicle API   │
    │  Service    Service    Service    Service     Integration   │
    │                                               Service       │
    │  Search     Enquiry    Notif.     Subscription  Review      │
    │  Service    & Chat     Service    & Payment     Service     │
    │             Service               Service                   │
    │  Test       Sale &     Analytics  Admin      Media         │
    │  Drive      RC Xfer    Service    Service    Service       │
    │  Service    Service                                         │
    │                                                              │
    │  Scheduler Service  (background jobs — no HTTP exposure)    │
    └─────────────────────────────────────────────────────────────┘
             │
    ┌────────▼─────────────────────────────────────────┐
    │              Shared Infrastructure                │
    │  PostgreSQL   Redis   Firebase   Cloudinary       │
    │  (per-service schemas)           Razorpay         │
    │               RTO / Vehicle API                   │
    └──────────────────────────────────────────────────┘
```

---

## 3. Microservices — Detailed Breakdown

---

### 3.1 API Gateway

| Property | Detail |
|----------|--------|
| **Purpose** | Single entry point for all client requests. Routes to the correct internal service. |
| **Tech** | Node.js + Express Gateway, or Kong, or AWS API Gateway |
| **Port** | 443 (HTTPS, public-facing) |
| **Owns data** | No — stateless |

#### Responsibilities
- Route incoming requests to the correct microservice based on URL path.
- Validate JWT tokens on protected routes (delegates token verification to Auth Service or handles it inline with the public key).
- Rate limiting per IP and per user to prevent abuse.
- Request logging for monitoring and debugging.
- Handle CORS for the Next.js web app and Flutter mobile app.
- SSL termination.

#### Route Examples
```
POST   /auth/*              → Auth Service
GET    /users/*             → User Service
GET    /shops/*             → Shop Service
POST   /shops/*             → Shop Service
GET    /vehicles/*          → Vehicle Service
POST   /vehicles/*          → Vehicle Service
GET    /search/*            → Search & Filter Service
POST   /enquiries/*         → Enquiry & Chat Service
POST   /subscriptions/*     → Subscription & Payment Service
GET    /analytics/*         → Analytics Service
POST   /admin/*             → Admin Service
POST   /media/*             → Media Service
```

---

### 3.2 Auth Service

| Property | Detail |
|----------|--------|
| **Purpose** | Registration, login, token management, and GST verification |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `auth` schema (users table: id, email, phone, password hash, role, verified) |
| **Cache** | Redis — refresh token storage and blacklist |
| **External API** | GST verification API |

#### Responsibilities
- Register new users (customer, shop owner).
- Validate GST number via external API during shop owner registration.
- Issue JWT access tokens (short-lived, 15 min) and refresh tokens (long-lived, 30 days).
- Refresh access tokens using the refresh token.
- Logout (blacklist the refresh token in Redis).
- Password reset via OTP (SMS or email).
- Role assignment — customer, shop_owner, association_admin, super_admin.

#### Endpoints
```
POST /auth/register/customer
POST /auth/register/shop
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/forgot-password
POST /auth/reset-password
POST /auth/verify-gst          (internal — called during shop registration)
```

#### Events Published
- `user.registered` — consumed by User Service and Notification Service
- `shop.gst.verified` — consumed by Shop Service and Notification Service

---

### 3.3 User Service

| Property | Detail |
|----------|--------|
| **Purpose** | Manage customer and shop owner profiles, wishlist, and comparison list |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `users` schema |

#### Responsibilities
- Store and update user profile (name, phone, location, profile photo).
- Manage customer wishlist (add/remove vehicles).
- Send price drop alert triggers to Notification Service when a wishlisted vehicle's price changes.
- Store and manage vehicle comparison list (up to 3 vehicles).
- Manage notification preferences.

#### Endpoints
```
GET    /users/:id
PUT    /users/:id
GET    /users/:id/wishlist
POST   /users/:id/wishlist
DELETE /users/:id/wishlist/:vehicleId
GET    /users/:id/compare
POST   /users/:id/compare
DELETE /users/:id/compare/:vehicleId
PUT    /users/:id/notification-preferences
```

#### Events Consumed
- `vehicle.price.updated` — check if vehicle is in any wishlist, trigger price drop notification

---

### 3.4 Shop Service

| Property | Detail |
|----------|--------|
| **Purpose** | Shop profile management, subscription status checks, verified badge logic |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `shops` schema |

#### Responsibilities
- Create and manage shop profiles (name, location, district, GST number, logo, description).
- Generate and manage the unique shareable shop URL slug.
- Track subscription status (active, trial, expired) and plan type (basic, premium).
- Apply "Inactive Shop" label logic when subscription expires.
- Track confirmed sale count per shop.
- Award verified badge when confirmed sales reach 5.
- Expose shop profile data for the public shareable URL (with guest view rules — blurred price/specs).

#### Endpoints
```
GET    /shops/:id                     (public — respects guest view rules)
GET    /shops/slug/:slug              (shareable URL lookup)
PUT    /shops/:id
GET    /shops/:id/vehicles            (all vehicles for a shop)
GET    /shops/:id/subscription-status
POST   /shops/:id/report              (customer reports a shop)
GET    /shops                         (admin — list all shops)
```

#### Events Consumed
- `shop.gst.verified` — create shop record and start free trial
- `subscription.activated` — update shop subscription status
- `subscription.expired` — mark shop as inactive
- `sale.confirmed` — increment sale count, check for verified badge trigger

#### Events Published
- `shop.verified_badge.awarded` — consumed by Notification Service

---

### 3.5 Vehicle Service

| Property | Detail |
|----------|--------|
| **Purpose** | Vehicle listing CRUD, photo management, price updates |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `vehicles` schema |
| **Cache** | Redis — vehicle detail cache (keyed by registration number) |

#### Responsibilities
- Accept a vehicle registration number from the shop owner.
- Call the Vehicle API Integration Service to fetch vehicle details.
- Store fetched vehicle data + shop owner additions (price, photos, notes).
- Expose vehicle detail pages (respecting guest view blur rules).
- Mark vehicles as sold.
- Update vehicle price (triggers price drop event if wishlisted).
- Manage vehicle photos (Cloudinary URLs stored in DB).
- Track view count per vehicle (for analytics).

#### Endpoints
```
POST   /vehicles                      (create — shop owner enters reg number)
GET    /vehicles/:id                  (public vehicle detail page)
PUT    /vehicles/:id                  (update price, notes)
DELETE /vehicles/:id
POST   /vehicles/:id/sold             (mark as sold — initiates sale confirmation)
GET    /vehicles/:id/photos
POST   /vehicles/:id/photos
DELETE /vehicles/:id/photos/:photoId
GET    /vehicles/shop/:shopId         (all vehicles for a shop)
```

#### Events Published
- `vehicle.created` — consumed by Search Service (index new listing)
- `vehicle.price.updated` — consumed by User Service (check wishlists)
- `vehicle.sold` — consumed by Sale & RC Transfer Service
- `vehicle.viewed` — consumed by Analytics Service

---

### 3.6 Vehicle API Integration Service

| Property | Detail |
|----------|--------|
| **Purpose** | Fetch and cache vehicle data from the RTO/vehicle API by registration number |
| **Tech** | Node.js + Express |
| **Cache** | Redis — vehicle data cached per registration number, TTL 30 days |
| **External API** | RTO vehicle API (Vahan / vehicleinfo.in / similar) |

#### Responsibilities
- Accept a registration number and return vehicle details.
- Check Redis cache first — if data exists and is fresh, return cached data.
- If cache miss or cache expired, call the external RTO API.
- Store result in Redis with a 30-day TTL.
- Expose a refresh endpoint used by the Scheduler Service for monthly auto-refresh.
- Handle API errors gracefully (return last cached data if the external API is temporarily down).
- Log all API calls for billing and usage monitoring.

#### Endpoints (internal only — not exposed through API Gateway to public)
```
GET    /vehicle-api/lookup/:registrationNumber
POST   /vehicle-api/refresh/:registrationNumber   (called by Scheduler)
GET    /vehicle-api/logs                          (admin — API usage log)
```

#### Why This Is a Separate Service
- The external RTO API has rate limits and per-call costs.
- All caching logic is centralised here — no other service needs to know about it.
- Easy to swap the external API provider without touching any other service.
- Independent scaling and monitoring of API usage and costs.

---

### 3.7 Search & Filter Service

| Property | Detail |
|----------|--------|
| **Purpose** | Fast vehicle and shop search with filters |
| **Tech** | Node.js + Express |
| **Search Engine** | PostgreSQL full-text search (MVP) → Elasticsearch or Typesense (v2 for PAN India scale) |
| **Cache** | Redis — cache popular search results |

#### Responsibilities
- Index new vehicle listings when created or updated.
- Remove listings from the index when marked as sold or when the shop's subscription expires.
- Execute search queries with filters: vehicle type, location/district, price range, year, fuel type, brand.
- Apply boost logic for premium shop vehicles (appear above basic plan vehicles in results).
- Shop search by name or location.
- Support pagination and sorting (newest, price low-high, price high-low).
- Cache popular search results in Redis (short TTL, 5 minutes).

#### Endpoints
```
GET    /search/vehicles?type=&location=&priceMin=&priceMax=&year=&fuel=&brand=&sort=&page=
GET    /search/shops?name=&location=&district=
GET    /search/suggestions?q=          (autocomplete)
```

#### Events Consumed
- `vehicle.created` — add to search index
- `vehicle.price.updated` — update index
- `vehicle.sold` — remove from search index
- `subscription.expired` — remove shop's vehicles from search index
- `subscription.activated` — re-add shop's vehicles to search index

---

### 3.8 Enquiry & Chat Service

| Property | Detail |
|----------|--------|
| **Purpose** | Manage enquiry threads and chat metadata. Real-time messages handled by Firebase. |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `enquiries` schema (thread metadata, status tags) |
| **Real-Time** | Firebase Firestore (actual messages live here) |

#### Responsibilities
- Create a new enquiry thread when a customer clicks Enquire on a vehicle.
- Store thread metadata in PostgreSQL (customer ID, shop ID, vehicle ID, created date, status tag).
- Reveal the shop owner's phone number inside the chat thread.
- Allow shop owners to update the enquiry status tag (new, in discussion, test drive scheduled, sold).
- Track whether the customer has sent at least one enquiry to a shop (used by Review Service for eligibility check).
- Firebase Firestore stores the actual messages — this service only manages the thread metadata.

#### Endpoints
```
POST   /enquiries                     (start a new enquiry thread)
GET    /enquiries/:id
GET    /enquiries/shop/:shopId        (shop owner inbox)
GET    /enquiries/customer/:customerId
PUT    /enquiries/:id/status          (update status tag)
GET    /enquiries/:id/phone-reveal    (returns shop phone number)
```

#### Events Published
- `enquiry.created` — consumed by Notification Service (alert shop owner)
- `enquiry.created` — consumed by Analytics Service

---

### 3.9 Notification Service

| Property | Detail |
|----------|--------|
| **Purpose** | Send all push notifications and in-app notifications |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `notifications` schema (notification log) |
| **Push** | Firebase Cloud Messaging (FCM) for mobile push notifications |

#### Responsibilities
- Listen to events from other services and send the appropriate notification.
- Send push notifications via FCM to Flutter mobile app.
- Send web push via FCM + Next.js service worker.
- Log all sent notifications in the database.
- Respect user notification preferences (from User Service).
- Handle notification types:

| Notification | Trigger Event |
|-------------|---------------|
| New enquiry alert to shop owner | `enquiry.created` |
| Price drop alert to customer | `vehicle.price.updated` + wishlist check |
| Test drive reminder (day before) | Scheduled job from Scheduler Service |
| Insurance expiry reminder | Scheduled job from Scheduler Service |
| Subscription renewal reminder | Scheduled job from Scheduler Service |
| New vehicle nearby | `vehicle.created` + location matching |
| RC transfer stuck alert | Scheduled job from Scheduler Service |
| New shop notification to association admin | `shop.gst.verified` |
| Verified badge awarded | `shop.verified_badge.awarded` |

#### Endpoints
```
POST   /notifications/send            (internal — other services call this)
GET    /notifications/user/:userId    (in-app notification inbox)
PUT    /notifications/:id/read
GET    /notifications/logs            (admin)
```

---

### 3.10 Subscription & Payment Service

| Property | Detail |
|----------|--------|
| **Purpose** | Manage subscription plans, payment processing via Razorpay, and subscription lifecycle |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `subscriptions` schema |
| **External** | Razorpay API |

#### Responsibilities
- Create Razorpay payment orders for subscription purchase.
- Verify payment webhooks from Razorpay.
- Activate or renew subscription after successful payment.
- Store subscription history (plan, amount, start date, end date, payment status).
- Expose current subscription status to Shop Service.
- Handle free trial tracking (start date, end date, whether trial has been used).
- Super admin can manually override subscription status (extend or activate).

#### Endpoints
```
POST   /subscriptions/create-order        (create Razorpay order)
POST   /subscriptions/verify-payment      (Razorpay webhook)
GET    /subscriptions/shop/:shopId        (current subscription status)
GET    /subscriptions/shop/:shopId/history
POST   /subscriptions/admin/override      (super admin only)
```

#### Events Published
- `subscription.activated` — consumed by Shop Service and Search Service
- `subscription.expired` — consumed by Shop Service and Search Service
- `subscription.trial.started` — consumed by Shop Service

---

### 3.11 Review Service

| Property | Detail |
|----------|--------|
| **Purpose** | Manage customer reviews on shop profiles |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `reviews` schema |

#### Responsibilities
- Check eligibility before allowing a review: the customer must have at least one enquiry thread with the shop (verified via Enquiry Service).
- Accept and store the review (rating + written text).
- Calculate and update the shop's average rating.
- Expose reviews on the shop profile page.
- Flag reviews for Super Admin if reported as inappropriate.

#### Endpoints
```
POST   /reviews                       (submit a review)
GET    /reviews/shop/:shopId          (all reviews for a shop)
DELETE /reviews/:id                   (admin only)
POST   /reviews/:id/report
```

---

### 3.12 Test Drive Service

| Property | Detail |
|----------|--------|
| **Purpose** | Manage test drive booking, approval, and scheduling |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `test_drives` schema |

#### Responsibilities
- Customer submits a test drive request (vehicle ID, preferred date/time, at-shop or home delivery).
- Shop owner receives a notification and can approve, reject, or propose an alternative time.
- Store test drive records with status (pending, confirmed, rejected, completed, no-show).
- Trigger day-before reminder notifications via Notification Service.
- Expose test drive booking data to Analytics Service.

#### Endpoints
```
POST   /test-drives                   (customer books a test drive)
GET    /test-drives/:id
PUT    /test-drives/:id/approve
PUT    /test-drives/:id/reject
PUT    /test-drives/:id/reschedule
PUT    /test-drives/:id/complete
GET    /test-drives/shop/:shopId      (shop owner view)
GET    /test-drives/customer/:customerId
```

#### Events Published
- `test_drive.confirmed` — consumed by Notification Service (day-before reminder scheduling)

---

### 3.13 Sale & RC Transfer Service

| Property | Detail |
|----------|--------|
| **Purpose** | Handle the sale confirmation flow and RC transfer stage tracking |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `sales` and `rc_transfers` schemas |

#### Responsibilities

**Sale Confirmation:**
- Shop owner initiates a sale (marks vehicle as sold from inventory).
- Customer receives a notification to confirm the sale.
- When both parties confirm, the sale is recorded as confirmed.
- Notify Shop Service to increment sale count (for verified badge logic).
- Automatically create an RC Transfer record for the vehicle.

**RC Transfer Tracker:**
- 5-stage pipeline per sale: documents collected → Form 29/30 submitted → hypothecation cleared → RC copy received → transfer complete.
- Shop owner updates the current stage.
- Customer has read-only access to the current stage.
- The Scheduler Service checks daily for transfers stuck at the same stage for 7+ days and triggers a reminder notification.

#### Endpoints
```
POST   /sales                         (shop owner initiates sale)
POST   /sales/:id/customer-confirm    (customer confirms sale)
GET    /sales/:id
GET    /sales/shop/:shopId
GET    /sales/customer/:customerId
POST   /rc-transfers                  (auto-created after sale confirmed)
GET    /rc-transfers/:id
PUT    /rc-transfers/:id/stage        (shop owner updates stage)
GET    /rc-transfers/sale/:saleId
```

#### Events Consumed
- `vehicle.sold` — start the sale confirmation flow

#### Events Published
- `sale.confirmed` — consumed by Shop Service (increment sale count) and Notification Service

---

### 3.14 Analytics Service

| Property | Detail |
|----------|--------|
| **Purpose** | Collect and serve analytics data for shop owners, association admins, and super admin |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `analytics` schema (event log + aggregated metrics) |
| **Cache** | Redis — cache aggregated dashboard metrics (TTL 15 minutes) |

#### Responsibilities
- Consume events from other services and log them (vehicle views, enquiries, test drives, sales).
- Aggregate metrics per shop for the shop owner dashboard.
- Aggregate district-level metrics for association admin dashboards.
- Aggregate platform-wide metrics for the super admin dashboard.
- Cache aggregated results in Redis so dashboards load fast without expensive queries on every request.

#### Data Tracked
- Vehicle page views (per vehicle, per shop)
- Enquiries received (per vehicle, per shop)
- Wishlist saves (per vehicle)
- Profile views from the shareable URL (per shop)
- Test drives booked vs completed (per shop)
- Confirmed sales (per shop, per district, platform-wide)
- Subscription metrics (active, trial, expired — platform-wide)

#### Endpoints
```
GET    /analytics/shop/:shopId        (shop owner dashboard data)
GET    /analytics/district/:districtId (association admin dashboard)
GET    /analytics/platform            (super admin dashboard)
```

#### Events Consumed
- `vehicle.viewed`
- `enquiry.created`
- `test_drive.confirmed`
- `sale.confirmed`
- `subscription.activated`
- `subscription.expired`

---

### 3.15 Admin Service

| Property | Detail |
|----------|--------|
| **Purpose** | Super admin and association admin operations |
| **Tech** | Node.js + Express |
| **Database** | PostgreSQL — `admin` schema |

#### Responsibilities
- Manage association admin accounts (create, assign to district, deactivate).
- Super admin: view and manage all shops, subscriptions, flags, and badges.
- Handle flagged shops and listings (from customer reports and association admin flags).
- Subscription override — manually activate or extend a shop's subscription.
- Banner/announcement system — create and push announcements to all shops or all customers.
- GST verification log access.
- View platform-wide health metrics (delegates to Analytics Service).

#### Endpoints
```
GET    /admin/shops                   (all shops)
GET    /admin/shops/:id
PUT    /admin/shops/:id/suspend
PUT    /admin/shops/:id/activate
GET    /admin/flags
PUT    /admin/flags/:id/resolve
POST   /admin/announcements
GET    /admin/announcements
GET    /admin/gst-logs
POST   /admin/association-admins
GET    /admin/association-admins
DELETE /admin/association-admins/:id
```

---

### 3.16 Media Service

| Property | Detail |
|----------|--------|
| **Purpose** | Generate signed upload URLs for Cloudinary and manage media metadata |
| **Tech** | Node.js + Express |
| **External** | Cloudinary API |
| **Database** | PostgreSQL — stores Cloudinary URLs per vehicle/shop |

#### Responsibilities
- Generate signed upload URLs for the Flutter app and Next.js web to upload directly to Cloudinary.
- Enforce photo limits per subscription plan (basic vs premium photo count per vehicle).
- Store and return Cloudinary URLs for vehicles and shop logos.
- Delete media from Cloudinary when a vehicle is removed.
- Image optimisation settings (auto WebP, responsive sizes) configured via Cloudinary transformation URLs.

#### Endpoints
```
POST   /media/sign-upload             (returns signed Cloudinary upload URL)
DELETE /media/:publicId               (delete from Cloudinary)
GET    /media/vehicle/:vehicleId      (all photos for a vehicle)
```

---

### 3.17 Scheduler Service

| Property | Detail |
|----------|--------|
| **Purpose** | Run all background/scheduled jobs. No HTTP exposure — internal only. |
| **Tech** | Node.js + node-cron or BullMQ with Redis queue |
| **Database** | Reads from PostgreSQL via internal service calls |

#### Jobs

| Job | Schedule | What It Does |
|-----|----------|-------------|
| Monthly vehicle API refresh | 1st of every month, 2 AM | Loops through all active vehicle listings, calls Vehicle API Integration Service to refresh data |
| Subscription expiry check | Daily, 8 AM | Finds subscriptions expiring in 7 days → triggers renewal reminder notification |
| Insurance expiry reminder | Daily, 9 AM | Finds vehicles with insurance expiring in 30 days → triggers shop owner notification |
| RC transfer stuck check | Daily, 10 AM | Finds RC transfers unchanged for 7+ days → triggers reminder notification to both parties |
| Test drive day-before reminder | Daily, 6 PM | Finds test drives scheduled for tomorrow → triggers reminder to both parties |
| Search index sync | Every 10 minutes | Ensures Search Service index is in sync with Vehicle Service database |
| Analytics aggregation | Every hour | Pre-computes dashboard metrics, stores in Redis cache |

---

## 4. Inter-Service Communication

### Synchronous (REST API calls)
Used when the calling service needs an immediate response.

Examples:
- API Gateway → any service (all user-facing requests)
- Auth Service → GST API (external)
- Vehicle Service → Vehicle API Integration Service (fetch vehicle data)
- Review Service → Enquiry Service (check if customer has enquired before)
- Subscription Service → Razorpay (payment processing)

### Asynchronous (Event Queue)
Used when the calling service does not need to wait for a response, or when multiple services need to react to the same event.

**Recommended: Redis Streams (simple) or RabbitMQ (more robust)**

For MVP, use **Redis Streams** — you already have Redis in the stack. Migrate to RabbitMQ or AWS SQS when traffic grows.

#### Key Events

| Event | Published By | Consumed By |
|-------|-------------|-------------|
| `user.registered` | Auth Service | User Service, Notification Service |
| `shop.gst.verified` | Auth Service | Shop Service, Notification Service |
| `vehicle.created` | Vehicle Service | Search Service, Analytics Service |
| `vehicle.price.updated` | Vehicle Service | User Service, Search Service |
| `vehicle.viewed` | Vehicle Service | Analytics Service |
| `vehicle.sold` | Vehicle Service | Sale & RC Transfer Service |
| `enquiry.created` | Enquiry Service | Notification Service, Analytics Service |
| `test_drive.confirmed` | Test Drive Service | Notification Service |
| `sale.confirmed` | Sale & RC Transfer Service | Shop Service, Notification Service, Analytics Service |
| `shop.verified_badge.awarded` | Shop Service | Notification Service |
| `subscription.activated` | Subscription Service | Shop Service, Search Service |
| `subscription.expired` | Subscription Service | Shop Service, Search Service |

---

## 5. Shared Infrastructure

| Infrastructure | Used By | Purpose |
|---------------|---------|---------|
| **PostgreSQL** | All services (separate schemas per service) | Primary data store |
| **Redis** | Auth, Vehicle, Search, Analytics, Scheduler | Caching, token store, event queue |
| **Firebase Firestore** | Enquiry & Chat Service | Real-time chat messages |
| **Firebase Cloud Messaging** | Notification Service | Push notifications (mobile + web) |
| **Cloudinary** | Media Service | Vehicle and shop photo storage |
| **Razorpay** | Subscription & Payment Service | Payment processing |
| **RTO / Vehicle API** | Vehicle API Integration Service | Vehicle data lookup |

### Database Schema Strategy
Each microservice owns its own PostgreSQL schema (not a separate database instance in the beginning — same Postgres server, separate schemas). This gives logical isolation without the operational overhead of multiple database servers. As traffic grows, schemas can be moved to separate database instances.

```
PostgreSQL Server
├── schema: auth          (Auth Service)
├── schema: users         (User Service)
├── schema: shops         (Shop Service)
├── schema: vehicles      (Vehicle Service)
├── schema: search        (Search Service — or use Elasticsearch)
├── schema: enquiries     (Enquiry & Chat Service)
├── schema: notifications (Notification Service)
├── schema: subscriptions (Subscription & Payment Service)
├── schema: reviews       (Review Service)
├── schema: test_drives   (Test Drive Service)
├── schema: sales         (Sale & RC Transfer Service)
├── schema: analytics     (Analytics Service)
└── schema: admin         (Admin Service)
```

---

## 6. Database Ownership Per Service

| Service | PostgreSQL Schema | Redis Keys | Firebase Collection |
|---------|------------------|------------|---------------------|
| Auth Service | `auth` | `refresh_token:*`, `blacklist:*` | — |
| User Service | `users` | — | — |
| Shop Service | `shops` | — | — |
| Vehicle Service | `vehicles` | — | — |
| Vehicle API Integration | — | `vehicle_api:reg:*` | — |
| Search Service | `search_index` | `search_cache:*` | — |
| Enquiry & Chat Service | `enquiries` | — | `chats/{threadId}/messages` |
| Notification Service | `notifications` | — | — |
| Subscription & Payment | `subscriptions` | — | — |
| Review Service | `reviews` | — | — |
| Test Drive Service | `test_drives` | — | — |
| Sale & RC Transfer | `sales`, `rc_transfers` | — | — |
| Analytics Service | `analytics` | `analytics_cache:*` | — |
| Admin Service | `admin` | — | — |
| Media Service | — (URLs stored in vehicles/shops schemas) | — | — |
| Scheduler Service | Reads via service APIs | `scheduler:locks:*` | — |

---

## 7. External Integrations

| External Service | Used By | Purpose |
|-----------------|---------|---------|
| **RTO / Vehicle API** (Vahan, vehicleinfo.in, or similar) | Vehicle API Integration Service | Fetch vehicle details from registration number |
| **GST Verification API** (GST Suvidha Provider or similar) | Auth Service | Validate shop owner GST numbers |
| **Razorpay** | Subscription & Payment Service | Payment orders, webhook verification |
| **Firebase** | Enquiry & Chat Service, Notification Service | Real-time chat (Firestore), push notifications (FCM) |
| **Cloudinary** | Media Service | Photo upload, storage, optimised delivery |
| **SMS Gateway** (Twilio, MSG91, or similar) | Notification Service | OTP for phone number verification during registration |

---

## 8. MVP vs Full Microservices Strategy

### Phase 1 — MVP (Modular Monolith)
Run everything as a single Node.js application with a clear module structure. Each "service" is a module (folder) with its own routes, controllers, and database tables. One PostgreSQL database, one Redis instance.

```
/src
  /auth
  /users
  /shops
  /vehicles
  /vehicle-api
  /search
  /enquiries
  /notifications
  /subscriptions
  /reviews
  /test-drives
  /sales
  /analytics
  /admin
  /media
  /scheduler
```

This is simpler to build, deploy, and debug. The code is already structured for future extraction.

### Phase 2 — Extract High-Traffic Services (v1)
When traffic grows, extract these first because they scale differently:
1. **Search & Filter Service** — highest read traffic, benefits from independent scaling
2. **Vehicle API Integration Service** — has external rate limits, must be isolated
3. **Notification Service** — event-driven, can process asynchronously without slowing user requests
4. **Scheduler Service** — should never share resources with user-facing requests

### Phase 3 — Full Microservices (v2 / PAN India)
Extract all remaining services. At this point, introduce a proper message queue (RabbitMQ or AWS SQS) to replace Redis Streams for event handling. Consider Kubernetes (AWS EKS or GCP GKE) for orchestration.

---

*Document last updated: June 2026*
*Version: 1.0 — Pre-development microservices specification*
