# System Architecture — Pre-Owned Vehicle Marketplace

> Complete system architecture covering clients, API layer, microservices, data stores, external integrations, infrastructure, and data flows for every major user journey.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Client Layer](#2-client-layer)
3. [API Gateway](#3-api-gateway)
4. [Service Layer](#4-service-layer)
5. [Data Layer](#5-data-layer)
6. [External Integrations](#6-external-integrations)
7. [Infrastructure & Hosting](#7-infrastructure--hosting)
8. [Data Flow Diagrams — Key Journeys](#8-data-flow-diagrams--key-journeys)
   - [Shop Owner Onboarding](#81-shop-owner-onboarding)
   - [Vehicle Listing Creation](#82-vehicle-listing-creation)
   - [Customer Search & Enquiry](#83-customer-search--enquiry)
   - [Sale Confirmation & RC Transfer](#84-sale-confirmation--rc-transfer)
   - [Subscription Payment](#85-subscription-payment)
   - [Monthly Vehicle API Refresh](#86-monthly-vehicle-api-refresh)
9. [Security Architecture](#9-security-architecture)
10. [Scalability Strategy](#10-scalability-strategy)
11. [Monitoring & Observability](#11-monitoring--observability)
12. [Deployment Architecture](#12-deployment-architecture)
13. [Architecture Decision Log](#13-architecture-decision-log)

---

## 1. Architecture Overview

### High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            CLIENT LAYER                                  │
│                                                                          │
│   ┌─────────────────────┐          ┌──────────────────────────────────┐ │
│   │   Flutter Mobile    │          │       Next.js Web App            │ │
│   │   (iOS + Android)   │          │   (SSR — SEO for listings)       │ │
│   └──────────┬──────────┘          └────────────────┬─────────────────┘ │
└──────────────┼──────────────────────────────────────┼─────────────────--┘
               │  HTTPS / REST                        │  HTTPS / REST
               └──────────────────┬───────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────────┐
│                            API GATEWAY                                   │
│          Route · Auth Validation · Rate Limiting · Logging               │
└──────┬────────┬────────┬────────┬────────┬────────┬────────┬────────────┘
       │        │        │        │        │        │        │
┌──────▼──┐ ┌──▼──┐ ┌───▼──┐ ┌──▼───┐ ┌──▼──┐ ┌──▼──┐ ┌───▼──────────┐
│  Auth   │ │User │ │ Shop │ │Vehic-│ │Searc│ │Enqu-│ │Subscription  │
│ Service │ │Svc  │ │ Svc  │ │le    │ │h    │ │iry  │ │& Payment Svc │
└────┬────┘ └──┬──┘ └──┬───┘ │Svc   │ │Svc  │ │Svc  │ └──────┬───────┘
     │         │       │     └──┬───┘ └──┬──┘ └──┬──┘        │
┌────▼─────────▼───────▼────────▼────────▼────────▼───────────▼──────────┐
│                        ADDITIONAL SERVICES                               │
│  Notification  │  Test Drive  │  Sale & RC  │  Analytics  │  Admin      │
│  Service       │  Service     │  Transfer   │  Service    │  Service    │
│                │              │  Service    │             │             │
│  Vehicle API   │  Media       │  Review     │  Scheduler  │             │
│  Integration   │  Service     │  Service    │  Service    │             │
└────────────────┴──────────────┴─────────────┴─────────────┴─────────────┘
       │                │               │              │
┌──────▼────────────────▼───────────────▼──────────────▼──────────────────┐
│                           DATA LAYER                                     │
│  PostgreSQL    │  Redis           │  Firebase          │  Cloudinary     │
│  (13 schemas)  │  (cache + queue) │  (chat + push)     │  (photos)       │
└────────────────┴──────────────────┴────────────────────┴─────────────────┘
       │
┌──────▼──────────────────────────────────────────────────────────────────┐
│                       EXTERNAL SERVICES                                  │
│  RTO/Vehicle API  │  GST API  │  Razorpay  │  Firebase FCM  │  SMS GW   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Architecture Style

The platform uses a **modular monolith at MVP** that is structured for clean extraction into **microservices at v2**. All domain logic is separated into independent modules sharing one Node.js process and one PostgreSQL instance. Each module is independently testable and has no cross-module database access — communication happens only through service function calls or events.

At v2 (PAN India scale), high-traffic modules (Search, Vehicle API Integration, Notification, Scheduler) are extracted into their own deployable services with their own resources.

---

## 2. Client Layer

### 2.1 Flutter Mobile App (iOS + Android)

**Framework:** Flutter (Dart)

Flutter is chosen for mobile because it produces a single codebase for both iOS and Android, has excellent performance for list-heavy UIs (vehicle grids, chat), and has strong Firebase SDK support for real-time chat and push notifications.

**Key responsibilities:**
- All customer-facing screens and shop owner screens
- Real-time chat UI backed by Firebase Firestore
- Push notification handling via Firebase Cloud Messaging
- Cloudinary direct upload for vehicle photos (signed URL from backend)
- Razorpay Flutter SDK for in-app subscription payments
- Offline-tolerant browsing (vehicle list cache in local SQLite via Hive or Drift)
- Deep linking for shareable vehicle and shop URLs

**State management:** Riverpod or BLoC

**Local storage:** Hive (lightweight key-value for cache), Flutter Secure Storage (tokens)

**Packages of note:**
- `firebase_core`, `cloud_firestore`, `firebase_messaging` — chat and push
- `razorpay_flutter` — payments
- `cloudinary_flutter` — photo uploads
- `cached_network_image` — lazy image loading for vehicle grids
- `go_router` — navigation and deep links

---

### 2.2 Next.js Web App

**Framework:** Next.js 14+ (App Router, React Server Components)

Next.js is chosen over Flutter Web because vehicle listing pages and shop profile pages must be **server-side rendered for SEO**. Every shop's shareable URL and every vehicle listing must be fully indexed by Google — this is free organic discovery for shop owners and is a core value proposition of the platform.

**Rendering strategy per page type:**

| Page | Strategy | Reason |
|------|----------|--------|
| Vehicle listing page | SSR (Server-Side Rendering) | SEO — Google indexes price, make, model |
| Shop profile page | SSR | SEO — shop name and location indexed |
| Homepage / browse | ISR (Incremental Static Regeneration, 60s) | Fast load, frequent updates |
| Search results | Client-side fetch | Dynamic, user-specific filters |
| Customer dashboard | CSR (Client-Side Rendering) | Private, no SEO needed |
| Shop owner dashboard | CSR | Private, no SEO needed |
| Admin panels | CSR | Private, no SEO needed |

**Key responsibilities:**
- Public vehicle and shop pages with full SEO meta tags (Open Graph for WhatsApp sharing of shop URLs)
- Authentication (JWT stored in httpOnly cookies)
- Real-time chat via Firebase Firestore (same as mobile)
- Cloudinary upload widget for vehicle photos
- Razorpay payment integration
- Responsive design (shop owners often use mobile browsers even on web)

**Styling:** Tailwind CSS

**State management:** Zustand or React Query (TanStack Query)

---

## 3. API Gateway

**Options:** Express Gateway (Node.js, simple for MVP) → Kong or AWS API Gateway (at scale)

**For MVP:** A lightweight Express-based gateway in the same Node.js monolith that validates JWT, applies rate limits, and routes to the correct module handler.

**For v2 production:** Kong (self-hosted) or AWS API Gateway (managed) in front of the individual microservices.

### Responsibilities

| Responsibility | Detail |
|---------------|--------|
| **Routing** | Maps URL paths to the correct service or module |
| **Auth validation** | Validates JWT on every protected route. Extracts user ID and role, passes to downstream service in headers |
| **Rate limiting** | Per-IP: 100 requests/minute for unauthenticated. Per-user: 300 requests/minute for authenticated |
| **CORS** | Allows requests from the Next.js web domain and Razorpay webhook IPs |
| **Request logging** | Logs method, path, user ID, response time, status code |
| **SSL termination** | HTTPS at the gateway level; internal services communicate over HTTP |
| **Request ID** | Injects a unique `X-Request-ID` header for distributed tracing |

### Route Map

```
Public routes (no auth required):
  GET  /vehicles/:id                    → Vehicle Service
  GET  /vehicles/shop/:shopId           → Vehicle Service
  GET  /shops/:id                       → Shop Service
  GET  /shops/slug/:slug                → Shop Service
  GET  /search/vehicles                 → Search Service
  GET  /search/shops                    → Search Service
  POST /auth/register/*                 → Auth Service
  POST /auth/login                      → Auth Service
  POST /auth/refresh                    → Auth Service

Protected routes (JWT required):
  PUT  /vehicles/:id                    → Vehicle Service     [shop_owner]
  POST /vehicles                        → Vehicle Service     [shop_owner]
  POST /enquiries                       → Enquiry Service     [customer]
  GET  /enquiries/*                     → Enquiry Service     [any]
  POST /test-drives                     → Test Drive Service  [customer]
  GET  /analytics/shop/:id              → Analytics Service   [shop_owner]
  GET  /analytics/district/:id          → Analytics Service   [association_admin]
  GET  /analytics/platform              → Analytics Service   [super_admin]
  POST /subscriptions/create-order      → Subscription Svc    [shop_owner]
  POST /admin/*                         → Admin Service       [super_admin]

Webhook routes (IP-allowlisted):
  POST /webhooks/razorpay               → Subscription Service
```

---

## 4. Service Layer

### Service Inventory

| Service | Primary Job | Sync/Async |
|---------|------------|------------|
| Auth Service | Register, login, GST verify, JWT | Sync |
| User Service | Customer profiles, wishlist, comparison | Sync |
| Shop Service | Shop profiles, slugs, badge logic | Sync + Events |
| Vehicle Service | Listings CRUD, price updates, photos | Sync + Events |
| Vehicle API Integration | RTO API calls, Redis cache | Sync |
| Search & Filter Service | Index vehicles, execute filtered queries | Sync + Events |
| Enquiry & Chat Service | Thread management, phone reveal | Sync + Events |
| Notification Service | Push notifications via FCM | Event-driven |
| Subscription & Payment | Razorpay orders, webhook, plan lifecycle | Sync + Events |
| Review Service | Submit, display, flag reviews | Sync |
| Test Drive Service | Booking, approval, reminders | Sync + Events |
| Sale & RC Transfer Service | Sale confirmation, RC stage tracking | Sync + Events |
| Analytics Service | Event ingestion, metric aggregation | Event-driven |
| Admin Service | Flags, announcements, admin ops | Sync |
| Media Service | Cloudinary signed URLs, photo management | Sync |
| Scheduler Service | Background jobs, cron | Internal only |

### Inter-Service Communication

**Synchronous (REST):** Used when the caller needs an immediate response.

Examples:
- Vehicle Service → Vehicle API Integration Service (fetch RTO data when listing is created)
- Review Service → Enquiry Service (check if customer has enquired before allowing review)
- API Gateway → Auth Service (token validation)

**Asynchronous (Events via Redis Streams):** Used when the caller does not need to wait, or when multiple services react to one event.

```
Event                         Published by              Consumed by
─────────────────────────────────────────────────────────────────────
user.registered               Auth Service              User Svc, Notification Svc
shop.gst.verified             Auth Service              Shop Svc, Notification Svc
vehicle.created               Vehicle Service           Search Svc, Analytics Svc
vehicle.price.updated         Vehicle Service           User Svc, Search Svc
vehicle.viewed                Vehicle Service           Analytics Svc
vehicle.sold                  Vehicle Service           Sale & RC Transfer Svc
enquiry.created               Enquiry Service           Notification Svc, Analytics Svc
test_drive.confirmed          Test Drive Service        Notification Svc
sale.confirmed                Sale & RC Transfer Svc   Shop Svc, Notification Svc, Analytics Svc
shop.badge.awarded            Shop Service              Notification Svc
subscription.activated        Subscription Svc          Shop Svc, Search Svc
subscription.expired          Subscription Svc          Shop Svc, Search Svc
```

---

## 5. Data Layer

### 5.1 PostgreSQL — Primary Database

**Version:** PostgreSQL 15+

**Schema-per-service isolation:**

```
PostgreSQL Instance
├── auth           → users, refresh_tokens, otp_requests, gst_verification_log
├── shops          → shop_profiles
├── subscriptions  → plans, shop_subscriptions, payments
├── vehicles       → listings, photos, price_history, service_history
├── vehicle_api    → cache, call_log
├── users          → customer_profiles, wishlists, comparisons, notification_preferences
├── enquiries      → threads, phone_reveal_log
├── test_drives    → bookings
├── sales          → records, rc_transfers
├── reviews        → shop_reviews
├── notifications  → log, device_tokens
├── analytics      → events, shop_daily_metrics
└── admin          → association_admins, flags, announcements, referrals
```

**Connection pooling:** PgBouncer (transaction mode) sits between the application and PostgreSQL. Prevents connection exhaustion under load.

**Backup strategy:**
- Continuous WAL archiving to S3 (point-in-time recovery)
- Daily full backups retained for 30 days
- Weekly snapshots retained for 6 months

**Read replicas:** Added when analytics queries begin to affect write performance. Analytics Service and Search Service point to the read replica.

---

### 5.2 Redis

**Version:** Redis 7+

**Usage by service:**

| Usage | Key Pattern | TTL |
|-------|-------------|-----|
| Vehicle API cache | `vehicle_api:reg:{reg_number}` | 30 days |
| Refresh token store | `auth:refresh:{token_hash}` | 30 days |
| Token blacklist | `auth:blacklist:{token_hash}` | Until expiry |
| Search result cache | `search:cache:{query_hash}` | 5 minutes |
| Analytics dashboard cache | `analytics:shop:{shop_id}` | 15 minutes |
| Session data | `session:{user_id}` | 24 hours |
| Event queue (Redis Streams) | `events:{event_type}` | 7 days (unconsumed) |
| Scheduler locks | `scheduler:lock:{job_name}` | Per job duration |

**Redis Streams for events (MVP):**
Redis Streams is used as the event bus for inter-service communication. Consumer groups ensure each service only processes each event once. At v2 scale, this can be migrated to RabbitMQ or AWS SQS without changing service logic.

---

### 5.3 Firebase

**Firebase Firestore — Real-time chat**

```
Firestore Collection Structure:

chats/
  {threadId}/               ← thread ID matches enquiries.threads.firebase_thread_id
    metadata/
      shopId: string
      customerId: string
      listingId: string
      createdAt: timestamp
    messages/
      {messageId}/
        senderId: string
        text: string
        sentAt: timestamp
        isRead: boolean
```

- Security rules restrict read/write to participants of each thread only
- Real-time listeners in Flutter and Next.js update the UI instantly
- No server involvement for message delivery — purely client-to-Firestore

**Firebase Cloud Messaging (FCM) — Push notifications**

- Flutter uses `firebase_messaging` package for foreground and background notifications
- Next.js uses a Service Worker with the FCM Web SDK
- The Notification Service holds FCM device tokens in PostgreSQL (`notifications.device_tokens`) and sends push via the FCM HTTP v1 API
- Supports batch sends for announcements targeting all shop owners or all customers

---

### 5.4 Cloudinary — Media Storage

**Usage:**

- Vehicle listing photos (multiple per listing, primary photo flagged)
- Shop logo images
- Service history documents (PDF + images, v2)

**Upload flow:**

```
1. Client requests a signed upload URL from the Media Service
2. Media Service generates a signed Cloudinary upload URL (short-lived, single-use)
3. Client uploads the file directly to Cloudinary (bypasses the backend server)
4. Cloudinary returns the public_id and secure_url
5. Client sends the public_id and URL to the backend to save in the database
```

This pattern means large files never pass through the Node.js server — Cloudinary handles all bandwidth, processing, and CDN delivery.

**Transformations used:**
- Auto-format (WebP for supported browsers, JPEG fallback)
- Auto-quality compression
- Responsive width variants (thumbnail 300px, card 600px, detail 1200px)
- Primary photo eager transformation on upload

---

## 6. External Integrations

### 6.1 RTO / Vehicle API

**Purpose:** Fetch vehicle details by registration number

**Recommended providers (India):**
- Vahan (government, free but rate-limited and unreliable)
- vehicleinfo.in (paid, more reliable)
- APIIP.net or RapidAPI vehicle lookup aggregators

**Integration rules:**
- Called only once at listing creation
- Called once per month per vehicle by the Scheduler Service
- All calls go through the Vehicle API Integration Service — no other service calls it directly
- Response is cached in Redis (TTL 30 days) and persisted to `vehicle_api.cache` in PostgreSQL
- If the API is down, the last cached response is returned — listing creation proceeds with partial data and the shop owner is notified to verify details manually

**Fields fetched:**
- Make, model, variant
- Year of manufacture
- Engine CC, fuel type
- Colour, body type
- Insurance expiry date
- RC owner name, RC status
- Chassis number, engine number

---

### 6.2 GST Verification API

**Purpose:** Validate shop owner GST numbers at registration

**Provider options:**
- GST Suvidha Providers (GSPs) with API access
- Masters India GST API
- ClearTax GST Verification API

**Integration:**
- Called once during shop owner registration
- Validates the GSTIN format and checks it against the GST database
- Returns: legal name of business, GST status (active/cancelled), state of registration
- Result is logged to `auth.gst_verification_log` regardless of outcome

---

### 6.3 Razorpay

**Purpose:** Subscription payment processing

**Integration flow:**

```
1. Shop owner selects a plan → Subscription Service creates a Razorpay order
2. Frontend receives the order_id and opens the Razorpay payment sheet
3. Customer completes payment (UPI, card, netbanking)
4. Razorpay sends a webhook to POST /webhooks/razorpay
5. Subscription Service verifies the webhook signature using the Razorpay secret
6. On success: payment record updated, subscription activated, event published
7. Shop Service receives subscription.activated event and updates shop status
```

**Key Razorpay features used:**
- Standard payment orders (not subscriptions API — simpler for MVP)
- Webhook for async payment confirmation
- Webhook signature verification using HMAC-SHA256

---

### 6.4 SMS Gateway

**Purpose:** OTP delivery for phone verification and password reset

**Provider options (India):**
- MSG91 (popular, competitive pricing)
- Twilio
- Exotel

**Integration:**
- Auth Service calls the SMS gateway API to send OTP
- OTP hash is stored in `auth.otp_requests` with 10-minute TTL
- Maximum 3 OTP requests per phone number per hour (rate-limited)

---

## 7. Infrastructure & Hosting

### Environment Setup

Three environments:

| Environment | Purpose | Data |
|-------------|---------|------|
| **Development** | Local developer machines | Seeded test data |
| **Staging** | Pre-production testing, QA, client demos | Anonymised copy of production data |
| **Production** | Live platform | Real user data |

### Hosting Stack

```
┌────────────────────────────────────────────────────────────────┐
│                        PRODUCTION HOSTING                       │
│                                                                  │
│  Vercel (Next.js Web)                                           │
│    ├── Edge network for SSR pages (vehicle, shop pages)         │
│    └── Automatic preview deployments per branch                 │
│                                                                  │
│  Railway or AWS (Backend API + Scheduler)                       │
│    ├── Node.js API server (2 replicas minimum)                  │
│    ├── Scheduler Service (1 instance, cron jobs)                │
│    └── PostgreSQL (managed, with PgBouncer)                     │
│                                                                  │
│  Redis (Upstash or Railway Redis)                               │
│    └── Single instance (MVP), cluster at scale                  │
│                                                                  │
│  Firebase (Google-managed)                                      │
│    ├── Firestore (chat)                                         │
│    └── FCM (push notifications)                                 │
│                                                                  │
│  Cloudinary (SaaS)                                             │
│    └── Media storage + CDN delivery                             │
└────────────────────────────────────────────────────────────────┘
```

### Domain & DNS

```
platform.com             → Next.js web (Vercel)
api.platform.com         → Node.js backend API
app.platform.com         → Flutter web (if needed)
platform.com/shop/:slug  → SSR shop profile pages (Next.js)
```

### Container Strategy (MVP → Production)

**MVP:** Single Docker container for the Node.js API. Docker Compose for local development (API + PostgreSQL + Redis + pgAdmin).

**Production (v1):** Docker container deployed to Railway or AWS ECS. Separate container for the Scheduler Service. Environment variables managed via Railway secrets or AWS SSM Parameter Store.

**v2 (Microservices):** Kubernetes (AWS EKS or GCP GKE) with Helm charts per service. Horizontal Pod Autoscaler on the Search and Vehicle services.

```yaml
# docker-compose.yml (local development)
services:
  api:
    build: ./backend
    ports: ["3001:3001"]
    environment:
      DATABASE_URL: postgres://user:pass@postgres:5432/marketplace
      REDIS_URL: redis://redis:6379
    depends_on: [postgres, redis]

  scheduler:
    build: ./backend
    command: node src/scheduler/index.js
    depends_on: [postgres, redis]

  postgres:
    image: postgres:15
    volumes: [postgres_data:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine

  pgadmin:
    image: dpage/pgadmin4
    ports: ["5050:80"]
```

---

## 8. Data Flow Diagrams — Key Journeys

### 8.1 Shop Owner Onboarding

```
Shop Owner fills registration form
        │
        ▼
[POST /auth/register/shop]
        │
        ▼
Auth Service
    ├── Validate phone (unique check in auth.users)
    ├── Hash password (bcrypt, 12 rounds)
    ├── Call GST Verification API
    │       ├── FAILED → Return 400 error, log to gst_verification_log
    │       └── PASSED → Continue
    ├── Create auth.users row (role = shop_owner)
    ├── Create shops.shop_profiles row
    ├── Create subscriptions.shop_subscriptions row (status = trial, 30 days)
    ├── Publish event: shop.gst.verified
    └── Return JWT access token + refresh token

Events consumed:
    shop.gst.verified
        ├── Notification Service → Send push to district Association Admin
        └── (Shop is live immediately — no manual approval gate)

Shop owner is now logged in with full access for 30 days.
```

---

### 8.2 Vehicle Listing Creation

```
Shop Owner submits registration number
        │
        ▼
[POST /vehicles]
        │
        ▼
Vehicle Service
    ├── Validate auth (must be shop_owner)
    ├── Check registration number not already listed (unique)
    ├── Call Vehicle API Integration Service
    │       ├── Check Redis cache (key: vehicle_api:reg:{reg})
    │       │       ├── HIT → Return cached data (no external API call)
    │       │       └── MISS → Call RTO/Vehicle API
    │       │               ├── SUCCESS → Cache in Redis (TTL 30 days)
    │       │               │           Persist to vehicle_api.cache
    │       │               │           Log to vehicle_api.call_log
    │       │               │           Return vehicle data
    │       │               └── FAILURE → Return partial data + flag for manual review
    ├── Create vehicles.listings row (status = active)
    ├── Publish event: vehicle.created
    └── Return listing ID to client

Client (Flutter/Next.js):
    ├── Receives listing_id
    ├── Requests signed upload URL from Media Service
    │       [POST /media/sign-upload]
    │       Media Service → Cloudinary → Returns signed URL
    ├── Uploads photos directly to Cloudinary
    └── Sends photo URLs to Vehicle Service
            [POST /vehicles/:id/photos]
            Vehicle Service → Creates vehicles.photos rows

Events consumed:
    vehicle.created
        ├── Search Service → Adds listing to search index
        └── Analytics Service → Logs vehicle_created event
```

---

### 8.3 Customer Search & Enquiry

```
Customer types search query + applies filters
        │
        ▼
[GET /search/vehicles?type=bike&location=Chennai&priceMax=100000]
        │
        ▼
Search & Filter Service
    ├── Build query hash from params
    ├── Check Redis cache (key: search:cache:{query_hash}, TTL 5 min)
    │       ├── HIT → Return cached results immediately
    │       └── MISS → Query vehicles.active_listings_with_shop view
    │               ├── Apply filters (type, location, price, year, fuel)
    │               ├── ORDER BY: premium shops first (is_premium = true), then by created_at DESC
    │               ├── Paginate (20 per page)
    │               ├── Cache result in Redis
    │               └── Return listing cards
        │
        ▼
Customer taps on a listing
        │
        ▼
[GET /vehicles/:id]   (SSR on web, API call on mobile)
        │
        ▼
Vehicle Service
    ├── Fetch listing with photos, shop details
    ├── Publish event: vehicle.viewed (async, non-blocking)
    └── Return full listing data

        │
        ▼
Customer clicks Enquire (login required)
        │
        ▼
[POST /enquiries]
        │
        ▼
Enquiry & Chat Service
    ├── Check if thread already exists for this customer + listing
    │       └── EXISTS → Return existing thread ID
    ├── Create enquiries.threads row (status = new)
    ├── Create Firestore document under chats/{threadId}
    ├── Publish event: enquiry.created
    └── Return thread ID + Firebase thread ID to client

Client opens chat screen using Firebase thread ID
    ├── Flutter/Next.js attaches real-time listener to Firestore chats/{threadId}/messages
    └── Messages flow directly between client and Firestore (no backend involvement)

Events consumed:
    enquiry.created
        ├── Notification Service → Push notification to shop owner ("New enquiry on [Vehicle]")
        └── Analytics Service → Log enquiry_created event
    vehicle.viewed
        └── Analytics Service → Increment view_count
```

---

### 8.4 Sale Confirmation & RC Transfer

```
Shop owner marks vehicle as sold
        │
        ▼
[POST /sales]  { listing_id, customer_id, thread_id }
        │
        ▼
Sale & RC Transfer Service
    ├── Create sales.records row (shop_confirmed = true, customer_confirmed = false)
    ├── Update vehicles.listings.status = 'pending_confirmation'
    └── Notify customer to confirm

        │
Customer receives push notification: "Confirm your purchase of [Vehicle]"
        │
        ▼
[POST /sales/:id/customer-confirm]
        │
        ▼
Sale & RC Transfer Service
    ├── Set customer_confirmed = true, is_confirmed = true, confirmed_at = NOW()
    ├── Update vehicles.listings.status = 'sold', sold_at = NOW()
    ├── Create sales.rc_transfers row (stage = 1)
    ├── Remove listing from Search Index
    └── Publish event: sale.confirmed

Events consumed:
    sale.confirmed
        ├── Shop Service
        │       ├── INCREMENT confirmed_sale_count
        │       └── IF confirmed_sale_count >= 5 AND is_verified = false
        │               ├── Set is_verified = true, verified_at = NOW()
        │               └── Publish: shop.badge.awarded
        ├── Notification Service → "Sale confirmed for [Vehicle]" to both parties
        └── Analytics Service → Log sale_confirmed event

    shop.badge.awarded
        └── Notification Service → "Congratulations! You've earned the Verified Badge" to shop owner

RC Transfer in motion:
    Shop owner updates stage: [PUT /rc-transfers/:id/stage]  { stage: 2 }
        │
        ▼
    Sale & RC Transfer Service
        ├── Update stage, update stage_updated_at = NOW()
        └── Log stage timestamp (form_submitted_at, etc.)

    Scheduler Service (daily at 10 AM):
        ├── Query rc_transfers WHERE stage < 5 AND stage_updated_at < NOW() - 7 days
        └── For each stuck transfer:
                └── Notification Service → Reminder to both shop owner and customer
```

---

### 8.5 Subscription Payment

```
Shop owner selects Premium plan (₹599/month)
        │
        ▼
[POST /subscriptions/create-order]  { plan_id: 'premium' }
        │
        ▼
Subscription & Payment Service
    ├── Fetch plan details from subscriptions.plans
    ├── Create Razorpay order via Razorpay API
    │       → Returns: razorpay_order_id
    ├── Create subscriptions.payments row (status = created)
    └── Return order_id + Razorpay key to client

Client opens Razorpay payment sheet (Flutter SDK / Razorpay.js)
    ├── Customer completes payment (UPI / card / netbanking)
    └── Razorpay sends webhook to POST /webhooks/razorpay

        │
        ▼
Subscription & Payment Service (webhook handler)
    ├── Verify HMAC-SHA256 signature using Razorpay webhook secret
    ├── On payment.captured event:
    │       ├── Update payments row (status = paid, razorpay_payment_id, paid_at)
    │       ├── Create/update shop_subscriptions row
    │       │       status = active
    │       │       current_period_start = NOW()
    │       │       current_period_end = NOW() + 30 days
    │       └── Publish event: subscription.activated
    └── Return 200 OK to Razorpay

Events consumed:
    subscription.activated
        ├── Shop Service → Update shop as active (remove Inactive label)
        └── Search Service → Re-index shop's vehicles as visible

Scheduler (daily at 8 AM) — subscription expiry check:
    ├── Find subscriptions WHERE current_period_end < NOW() + 7 days
    │       └── Notification Service → "Your subscription expires in 7 days"
    └── Find subscriptions WHERE current_period_end < NOW() AND status = 'active'
            ├── Update status = expired
            └── Publish event: subscription.expired
                    ├── Shop Service → Add "Inactive Shop" label, disable enquiry button
                    └── Search Service → Remove shop's vehicles from search results
```

---

### 8.6 Monthly Vehicle API Refresh

```
Scheduler Service — 1st of every month at 2 AM
        │
        ▼
    Query vehicles.listings WHERE status = 'active'
    Batch into groups of 50 (to avoid rate limit spikes)
        │
        ▼
    For each batch:
        For each listing:
            ├── Call Vehicle API Integration Service
            │       [POST /vehicle-api/refresh/:registrationNumber]
            │       ├── Fetch from RTO API
            │       ├── Update Redis cache (reset TTL to 30 days)
            │       ├── Update vehicle_api.cache row
            │       └── Return updated fields
            │
            ├── Update vehicles.listings with new data
            │       (insurance_expiry, rc_status, api_last_fetched_at)
            │
            └── If insurance_expiry changed to within 30 days:
                    └── Notification Service → Insurance expiry reminder to shop owner

    Log total refresh count, success count, failure count
    Wait 1 second between batches (rate limit protection)
```

---

## 9. Security Architecture

### Authentication

- **JWT-based auth** — access token (15 min) + refresh token (30 days)
- Access tokens are stateless — validated by checking signature with the public key
- Refresh tokens are stored in Redis — can be instantly revoked on logout
- Tokens are stored in httpOnly cookies on web (prevents XSS token theft), in Flutter Secure Storage on mobile

### Authorisation

- Role-based access control enforced at the API Gateway and within each service
- Roles: `customer`, `shop_owner`, `association_admin`, `super_admin`
- Shop owners can only modify their own shop and vehicles (ownership check on every write operation)
- Association admins can only read data from their own district

### Data Security

- Passwords hashed with bcrypt (12 rounds)
- GST numbers stored as plaintext (required for verification and display)
- Phone numbers stored as plaintext (required for communication)
- Database credentials stored in environment variables, never in code
- All secrets managed via Railway Secrets or AWS SSM Parameter Store
- PostgreSQL connection encrypted with TLS

### API Security

- Rate limiting per IP (unauthenticated) and per user (authenticated)
- Razorpay webhook signature verification (HMAC-SHA256) — rejects any webhook without a valid signature
- Cloudinary signed upload URLs — short-lived (60 seconds), single-use, scoped to specific upload parameters
- GST API and RTO API credentials stored in environment variables only

### Firebase Security Rules (Firestore)

```javascript
// chats collection — only participants can read/write
match /chats/{threadId} {
  allow read, write: if request.auth != null
    && (request.auth.uid == resource.data.customerId
     || request.auth.uid == resource.data.shopOwnerId);

  match /messages/{messageId} {
    allow read, write: if request.auth != null
      && (request.auth.uid == get(/databases/$(database)/documents/chats/$(threadId)).data.customerId
       || request.auth.uid == get(/databases/$(database)/documents/chats/$(threadId)).data.shopOwnerId);
  }
}
```

### Input Validation

- All API inputs validated with Zod (TypeScript schema validation)
- SQL injection prevented by using parameterised queries (pg library with `$1, $2` placeholders)
- XSS prevented by React's default output encoding on the web and Flutter's text rendering
- File uploads validated for type (image/jpeg, image/png, image/webp, application/pdf) and size (max 10MB) before Cloudinary upload

---

## 10. Scalability Strategy

### Bottlenecks by Phase

**MVP (0–5,000 users):**
- Single Node.js process, single PostgreSQL instance
- Redis single instance
- No special scaling needed
- Expected: < 100 concurrent users

**v1 (5,000–50,000 users):**
- Add read replica to PostgreSQL (Analytics and Search queries hit replica)
- Add PgBouncer for connection pooling
- Extract Scheduler Service to separate process/container
- Add Redis cache warming for popular search queries
- Expected: 500–1,000 concurrent users

**v2 / PAN India (50,000+ users):**
- Extract Search Service (Elasticsearch or Typesense for full-text vehicle search at scale)
- Extract Vehicle API Integration Service (dedicated Redis cache, independent rate limit management)
- Extract Notification Service (message queue with worker processes)
- PostgreSQL → partition analytics.events table by month
- Add CDN for API responses (CloudFront or Cloudflare) on high-traffic vehicle listing endpoints
- Kubernetes for orchestration (horizontal scaling of Search and Vehicle services)
- Expected: 5,000–20,000 concurrent users

### Caching Strategy

```
Layer 1 — CDN (Cloudflare/CloudFront)
    └── Cache SSR vehicle and shop pages at edge (TTL 60 seconds)
        Instantly serves cached HTML worldwide

Layer 2 — Redis (Application cache)
    ├── Vehicle API responses (TTL 30 days)
    ├── Search results (TTL 5 minutes)
    ├── Analytics dashboards (TTL 15 minutes)
    └── Active subscription status per shop (TTL 5 minutes)

Layer 3 — PostgreSQL (Persistent data)
    ├── Read replica for analytics and search queries
    └── Primary for all writes
```

---

## 11. Monitoring & Observability

### Application Monitoring

| Tool | Purpose |
|------|---------|
| **Sentry** | Error tracking — captures unhandled exceptions with full stack traces and user context |
| **Datadog or Grafana Cloud** | Metrics dashboard — request rate, error rate, latency percentiles (p50, p95, p99) |
| **UptimeRobot** | Uptime monitoring — alerts if the API or web goes down |

### Key Metrics to Monitor

**API health:**
- Request rate (req/sec) per endpoint
- Error rate (4xx and 5xx) per endpoint
- Response time p95 (target < 300ms for most endpoints)

**Business metrics (via Analytics Service):**
- New shops registered per day
- New vehicle listings per day
- Enquiries per day
- Subscription activations per day
- API call count to RTO API (cost management)

**Infrastructure:**
- PostgreSQL: connection count, slow queries (pg_stat_statements), disk usage
- Redis: memory usage, eviction rate, cache hit rate
- Cloudinary: bandwidth usage (billing)
- Firebase Firestore: read/write operations (billing)

### Logging

- All API requests logged: timestamp, method, path, user_id, response_time_ms, status_code, request_id
- All errors logged with stack trace and request context
- All external API calls logged: service name, endpoint, response_time_ms, success/failure
- Logs shipped to **Logtail** or **Papertrail** for search and retention

### Alerts

| Alert | Condition | Channel |
|-------|----------|---------|
| High error rate | 5xx errors > 1% of requests for 5 min | Slack + SMS |
| API down | Health check fails for 2 min | SMS |
| Slow response | p95 latency > 1s for 5 min | Slack |
| RTO API failures | > 5 consecutive failures | Slack |
| Razorpay webhook failures | Any failed webhook | Slack |
| Database disk > 80% | PostgreSQL disk usage > 80% | Slack |

---

## 12. Deployment Architecture

### CI/CD Pipeline

```
Developer pushes to feature branch
        │
        ▼
GitHub Actions runs:
    ├── ESLint + TypeScript type check
    ├── Unit tests (Jest)
    ├── Integration tests (against test database)
    └── Build Docker image

PR merged to main branch
        │
        ▼
GitHub Actions runs:
    ├── All tests pass
    ├── Build production Docker image
    ├── Push image to Docker Hub or AWS ECR
    ├── Deploy to staging environment
    ├── Run smoke tests against staging
    └── (Manual approval gate) → Deploy to production

Production deploy:
    ├── Run database migrations (node-pg-migrate or Flyway)
    ├── Rolling restart of API containers (zero downtime)
    └── Notify team in Slack
```

### Database Migrations

- Migration files stored in `/migrations` folder, version-numbered
- `node-pg-migrate` or `Flyway` manages migration history
- Migrations run automatically before each deployment
- All migrations are backwards-compatible (additive changes only — no column renames or deletes without a transition period)

### Environment Variables

```bash
# Core
NODE_ENV=production
PORT=3001
DATABASE_URL=postgres://...
REDIS_URL=redis://...

# Auth
JWT_SECRET=...
JWT_REFRESH_SECRET=...

# Firebase
FIREBASE_PROJECT_ID=...
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...

# Cloudinary
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...

# Razorpay
RAZORPAY_KEY_ID=...
RAZORPAY_KEY_SECRET=...
RAZORPAY_WEBHOOK_SECRET=...

# External APIs
RTO_API_KEY=...
RTO_API_BASE_URL=...
GST_API_KEY=...
GST_API_BASE_URL=...

# SMS Gateway
SMS_API_KEY=...
SMS_SENDER_ID=...

# Monitoring
SENTRY_DSN=...
```

---

## 13. Architecture Decision Log

| Decision | Choice | Why | Trade-off |
|----------|--------|-----|-----------|
| Mobile framework | Flutter | Single codebase for iOS + Android, excellent Firebase support | Dart learning curve for JS developers |
| Web framework | Next.js | SSR for SEO on listing and shop pages — critical for organic discovery | More complex than a pure SPA |
| Backend language | Node.js + TypeScript | Same language as Next.js, large ecosystem, strong Firebase/Razorpay SDKs | Not ideal for CPU-heavy tasks |
| Database | PostgreSQL | Relational data with complex queries (search filters, analytics), mature, schema-per-service isolation | More complex than Firebase Firestore for simple CRUD |
| Chat infrastructure | Firebase Firestore | Real-time, managed, scales automatically, excellent Flutter SDK | Additional cost, data lives outside main DB |
| Event bus | Redis Streams (MVP) | Already have Redis in stack, simple to implement | Not as robust as RabbitMQ for high-volume events |
| Architecture pattern | Modular monolith → microservices | Ship fast at MVP, extract when proven bottlenecks appear | Discipline required to keep modules isolated |
| File storage | Cloudinary | Managed CDN + image transformation + signed uploads, no server bandwidth cost | Ongoing cost scales with storage and bandwidth |
| Payment gateway | Razorpay | Best UPI support in India, easy Flutter/JS SDK, webhooks | India-only (fine for current scope) |
| Search (MVP) | PostgreSQL full-text + GIN index | No extra infrastructure, sufficient for single-state scale | Will need Elasticsearch or Typesense at PAN India scale |
| Auth strategy | JWT + Refresh tokens | Stateless access tokens scale well, refresh tokens in Redis can be instantly revoked | More complex than session cookies |
| OTP delivery | SMS via MSG91/Twilio | Phone-first users in India, no email required | Per-SMS cost, depends on carrier delivery |

---

*Document last updated: June 2026*
*Version: 1.0 — Pre-development system architecture*
