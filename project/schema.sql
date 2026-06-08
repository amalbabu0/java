-- =============================================================================
-- Pre-Owned Vehicle Marketplace — PostgreSQL Schema
-- Version: 1.0
-- =============================================================================
-- Schema layout (one schema per microservice domain):
--   auth          → users, roles, OTP, refresh tokens
--   shops         → shop profiles, slugs, verified badge
--   vehicles      → listings, photos, views
--   vehicle_api   → RTO API cache and refresh log
--   subscriptions → plans, payments, trial tracking
--   enquiries     → chat threads, phone reveal log
--   search        → boost config (actual index in Redis/Elasticsearch)
--   test_drives   → booking, approval, status
--   sales         → confirmed sales, RC transfer stages
--   reviews       → customer reviews per shop
--   notifications → notification log and preferences
--   analytics     → event log and aggregated metrics
--   admin         → flags, announcements, association admins
-- =============================================================================

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";       -- for fuzzy name search
CREATE EXTENSION IF NOT EXISTS "unaccent";       -- for multilingual search (v2)

-- =============================================================================
-- SCHEMA: auth
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS auth;

-- ----------------------------------------------------------------------------
-- auth.users
-- Central user table. All roles (customer, shop_owner, association_admin,
-- super_admin) live here. Role-specific data is in separate tables.
-- ----------------------------------------------------------------------------
CREATE TABLE auth.users (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone               VARCHAR(15) NOT NULL UNIQUE,
    email               VARCHAR(255) UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    role                VARCHAR(30) NOT NULL CHECK (role IN (
                            'customer',
                            'shop_owner',
                            'association_admin',
                            'super_admin'
                        )),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_phone_verified   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auth_users_phone  ON auth.users (phone);
CREATE INDEX idx_auth_users_role   ON auth.users (role);

-- ----------------------------------------------------------------------------
-- auth.refresh_tokens
-- Refresh token store. Blacklisted on logout.
-- ----------------------------------------------------------------------------
CREATE TABLE auth.refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,
    is_revoked  BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user_id    ON auth.refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_token_hash ON auth.refresh_tokens (token_hash);

-- ----------------------------------------------------------------------------
-- auth.otp_requests
-- OTP for phone verification and password reset.
-- ----------------------------------------------------------------------------
CREATE TABLE auth.otp_requests (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone       VARCHAR(15) NOT NULL,
    otp_hash    VARCHAR(255) NOT NULL,
    purpose     VARCHAR(30) NOT NULL CHECK (purpose IN ('phone_verify', 'password_reset')),
    is_used     BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_requests_phone ON auth.otp_requests (phone);

-- ----------------------------------------------------------------------------
-- auth.gst_verification_log
-- Every GST validation attempt is logged for Super Admin audit.
-- ----------------------------------------------------------------------------
CREATE TABLE auth.gst_verification_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    gst_number      VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL CHECK (status IN ('passed', 'failed', 'api_error')),
    api_response    JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gst_log_user_id    ON auth.gst_verification_log (user_id);
CREATE INDEX idx_gst_log_gst_number ON auth.gst_verification_log (gst_number);


-- =============================================================================
-- SCHEMA: shops
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS shops;

-- ----------------------------------------------------------------------------
-- shops.shop_profiles
-- One row per shop owner. Linked to auth.users via owner_id.
-- ----------------------------------------------------------------------------
CREATE TABLE shops.shop_profiles (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id                UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
    shop_name               VARCHAR(150) NOT NULL,
    slug                    VARCHAR(180) NOT NULL UNIQUE,   -- used in shareable URL
    gst_number              VARCHAR(20) NOT NULL UNIQUE,
    district                VARCHAR(100) NOT NULL,
    state                   VARCHAR(100) NOT NULL,
    address                 TEXT,
    phone                   VARCHAR(15) NOT NULL,
    logo_url                VARCHAR(500),
    description             TEXT,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,  -- false = suspended by admin
    is_verified             BOOLEAN NOT NULL DEFAULT FALSE, -- verified badge
    verified_at             TIMESTAMPTZ,
    confirmed_sale_count    INT NOT NULL DEFAULT 0,
    average_rating          NUMERIC(3,2) DEFAULT NULL,      -- updated by Review Service
    review_count            INT NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shop_profiles_owner_id  ON shops.shop_profiles (owner_id);
CREATE INDEX idx_shop_profiles_district  ON shops.shop_profiles (district);
CREATE INDEX idx_shop_profiles_state     ON shops.shop_profiles (state);
CREATE INDEX idx_shop_profiles_slug      ON shops.shop_profiles (slug);
CREATE INDEX idx_shop_profiles_verified  ON shops.shop_profiles (is_verified);

-- Full-text search on shop name and district for the shop search feature
CREATE INDEX idx_shop_profiles_fts ON shops.shop_profiles
    USING GIN (to_tsvector('english', shop_name || ' ' || district));


-- =============================================================================
-- SCHEMA: subscriptions
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS subscriptions;

-- ----------------------------------------------------------------------------
-- subscriptions.plans
-- Seed data: basic and premium plans.
-- ----------------------------------------------------------------------------
CREATE TABLE subscriptions.plans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(50) NOT NULL UNIQUE,  -- 'basic', 'premium'
    price_paise     INT NOT NULL,                 -- amount in paise (₹299 = 29900)
    max_photos      INT NOT NULL DEFAULT 5,       -- photos allowed per vehicle
    has_boost       BOOLEAN NOT NULL DEFAULT FALSE,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed plans
INSERT INTO subscriptions.plans (name, price_paise, max_photos, has_boost, description) VALUES
    ('basic',   29900, 5,  FALSE, '₹299/month — unlimited listings, basic visibility'),
    ('premium', 59900, 15, TRUE,  '₹599/month — unlimited listings, top search placement, push boost, 15 photos per vehicle');

-- ----------------------------------------------------------------------------
-- subscriptions.shop_subscriptions
-- One active subscription per shop at a time.
-- ----------------------------------------------------------------------------
CREATE TABLE subscriptions.shop_subscriptions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id             UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    plan_id             UUID NOT NULL REFERENCES subscriptions.plans (id),
    status              VARCHAR(30) NOT NULL CHECK (status IN (
                            'trial',
                            'active',
                            'expired',
                            'cancelled'
                        )),
    trial_start_at      TIMESTAMPTZ,
    trial_end_at        TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ,
    current_period_end   TIMESTAMPTZ,
    override_by_admin   BOOLEAN NOT NULL DEFAULT FALSE,   -- true if admin manually extended
    override_note       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shop_subscriptions_shop_id ON subscriptions.shop_subscriptions (shop_id);
CREATE INDEX idx_shop_subscriptions_status  ON subscriptions.shop_subscriptions (status);
CREATE INDEX idx_shop_subscriptions_end     ON subscriptions.shop_subscriptions (current_period_end);

-- ----------------------------------------------------------------------------
-- subscriptions.payments
-- Every Razorpay payment attempt is recorded here.
-- ----------------------------------------------------------------------------
CREATE TABLE subscriptions.payments (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id                 UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    subscription_id         UUID REFERENCES subscriptions.shop_subscriptions (id),
    plan_id                 UUID NOT NULL REFERENCES subscriptions.plans (id),
    razorpay_order_id       VARCHAR(100) UNIQUE,
    razorpay_payment_id     VARCHAR(100) UNIQUE,
    razorpay_signature      VARCHAR(255),
    amount_paise            INT NOT NULL,
    status                  VARCHAR(30) NOT NULL CHECK (status IN (
                                'created',
                                'paid',
                                'failed',
                                'refunded'
                            )),
    paid_at                 TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_shop_id            ON subscriptions.payments (shop_id);
CREATE INDEX idx_payments_razorpay_order_id  ON subscriptions.payments (razorpay_order_id);
CREATE INDEX idx_payments_status             ON subscriptions.payments (status);


-- =============================================================================
-- SCHEMA: vehicles
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS vehicles;

-- ----------------------------------------------------------------------------
-- vehicles.listings
-- Core vehicle listing. Data from RTO API + shop owner additions.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicles.listings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id             UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    registration_number VARCHAR(20) NOT NULL UNIQUE,

    -- Data fetched from RTO/vehicle API
    make                VARCHAR(100),
    model               VARCHAR(100),
    variant             VARCHAR(100),
    year_of_manufacture INT,
    engine_cc           INT,
    bhp                 NUMERIC(6,2),
    fuel_type           VARCHAR(30) CHECK (fuel_type IN ('petrol', 'diesel', 'electric', 'cng', 'hybrid')),
    colour              VARCHAR(50),
    body_type           VARCHAR(50),
    transmission        VARCHAR(20) CHECK (transmission IN ('manual', 'automatic')),
    insurance_expiry    DATE,
    rc_owner_name       VARCHAR(150),
    rc_status           VARCHAR(50),
    chassis_number      VARCHAR(50),
    engine_number       VARCHAR(50),
    api_raw_data        JSONB,                              -- full raw API response stored for reference
    api_last_fetched_at TIMESTAMPTZ,

    -- Data added by shop owner
    asking_price        NUMERIC(12,2) NOT NULL,
    odometer_km         INT,
    condition_grade     VARCHAR(5) CHECK (condition_grade IN ('A', 'B', 'C')),  -- v2
    notes               TEXT,
    is_test_drive_available BOOLEAN NOT NULL DEFAULT FALSE,
    test_drive_mode     VARCHAR(20) CHECK (test_drive_mode IN ('at_shop', 'home_delivery', 'both')),

    -- Status
    status              VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status IN (
                            'active',
                            'sold',
                            'archived',
                            'pending_confirmation'  -- awaiting both-party sale confirmation
                        )),
    sold_at             TIMESTAMPTZ,

    -- Analytics counters (updated by Analytics Service)
    view_count          INT NOT NULL DEFAULT 0,
    wishlist_count      INT NOT NULL DEFAULT 0,
    enquiry_count       INT NOT NULL DEFAULT 0,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_listings_shop_id       ON vehicles.listings (shop_id);
CREATE INDEX idx_listings_status        ON vehicles.listings (status);
CREATE INDEX idx_listings_fuel_type     ON vehicles.listings (fuel_type);
CREATE INDEX idx_listings_year          ON vehicles.listings (year_of_manufacture);
CREATE INDEX idx_listings_price         ON vehicles.listings (asking_price);
CREATE INDEX idx_listings_engine_cc     ON vehicles.listings (engine_cc);
CREATE INDEX idx_listings_insurance     ON vehicles.listings (insurance_expiry);
CREATE INDEX idx_listings_reg_number    ON vehicles.listings (registration_number);
CREATE INDEX idx_listings_condition     ON vehicles.listings (condition_grade);

-- Full-text search on make, model, colour for search service
CREATE INDEX idx_listings_fts ON vehicles.listings
    USING GIN (to_tsvector('english',
        COALESCE(make, '') || ' ' ||
        COALESCE(model, '') || ' ' ||
        COALESCE(variant, '') || ' ' ||
        COALESCE(colour, '')
    ));

-- ----------------------------------------------------------------------------
-- vehicles.photos
-- Multiple photos per listing. Stored in Cloudinary, URL saved here.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicles.photos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id      UUID NOT NULL REFERENCES vehicles.listings (id) ON DELETE CASCADE,
    cloudinary_url  VARCHAR(500) NOT NULL,
    public_id       VARCHAR(255) NOT NULL UNIQUE,  -- Cloudinary public_id for deletion
    is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_photos_listing_id ON vehicles.photos (listing_id);

-- ----------------------------------------------------------------------------
-- vehicles.price_history
-- Every price change is logged. Used for price drop alerts and analytics.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicles.price_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id      UUID NOT NULL REFERENCES vehicles.listings (id) ON DELETE CASCADE,
    old_price       NUMERIC(12,2) NOT NULL,
    new_price       NUMERIC(12,2) NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_price_history_listing_id ON vehicles.price_history (listing_id);

-- ----------------------------------------------------------------------------
-- vehicles.service_history    [v2]
-- PDF or image attachments of past service records per vehicle.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicles.service_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id      UUID NOT NULL REFERENCES vehicles.listings (id) ON DELETE CASCADE,
    cloudinary_url  VARCHAR(500) NOT NULL,
    public_id       VARCHAR(255) NOT NULL UNIQUE,
    description     VARCHAR(255),
    service_date    DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_service_history_listing_id ON vehicles.service_history (listing_id);


-- =============================================================================
-- SCHEMA: vehicle_api
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS vehicle_api;

-- ----------------------------------------------------------------------------
-- vehicle_api.cache
-- Persisted cache of RTO API responses per registration number.
-- Redis is the primary cache; this table is the durable backup.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicle_api.cache (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_number VARCHAR(20) NOT NULL UNIQUE,
    raw_response        JSONB NOT NULL,
    fetched_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    next_refresh_at     TIMESTAMPTZ NOT NULL,   -- scheduled monthly refresh date
    fetch_count         INT NOT NULL DEFAULT 1  -- total API calls made for this reg number
);

CREATE INDEX idx_vehicle_api_cache_reg   ON vehicle_api.cache (registration_number);
CREATE INDEX idx_vehicle_api_cache_refresh ON vehicle_api.cache (next_refresh_at);

-- ----------------------------------------------------------------------------
-- vehicle_api.call_log
-- Every individual API call to the RTO API is logged for billing and auditing.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicle_api.call_log (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_number VARCHAR(20) NOT NULL,
    triggered_by        VARCHAR(30) NOT NULL CHECK (triggered_by IN ('listing_creation', 'monthly_refresh', 'manual')),
    http_status         INT,
    success             BOOLEAN NOT NULL,
    error_message       TEXT,
    response_time_ms    INT,
    called_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_api_call_log_reg_number ON vehicle_api.call_log (registration_number);
CREATE INDEX idx_api_call_log_called_at  ON vehicle_api.call_log (called_at);


-- =============================================================================
-- SCHEMA: users (customer profiles and preferences)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS users;

-- ----------------------------------------------------------------------------
-- users.customer_profiles
-- Extended profile for customers (separate from auth.users).
-- ----------------------------------------------------------------------------
CREATE TABLE users.customer_profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name       VARCHAR(150) NOT NULL,
    district        VARCHAR(100),
    state           VARCHAR(100),
    profile_photo   VARCHAR(500),
    language_pref   VARCHAR(20) NOT NULL DEFAULT 'en',  -- v2: 'en', 'ta', 'hi', 'te', 'kn'
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customer_profiles_user_id ON users.customer_profiles (user_id);

-- ----------------------------------------------------------------------------
-- users.wishlists
-- Saved vehicles per customer. Unique per customer + listing pair.
-- ----------------------------------------------------------------------------
CREATE TABLE users.wishlists (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    listing_id  UUID NOT NULL REFERENCES vehicles.listings (id) ON DELETE CASCADE,
    saved_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, listing_id)
);

CREATE INDEX idx_wishlists_user_id    ON users.wishlists (user_id);
CREATE INDEX idx_wishlists_listing_id ON users.wishlists (listing_id);

-- ----------------------------------------------------------------------------
-- users.comparisons
-- Up to 3 vehicles in a customer's active comparison list.
-- ----------------------------------------------------------------------------
CREATE TABLE users.comparisons (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    listing_id  UUID NOT NULL REFERENCES vehicles.listings (id) ON DELETE CASCADE,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, listing_id)
);

CREATE INDEX idx_comparisons_user_id ON users.comparisons (user_id);

-- Enforce the 3-vehicle limit with a constraint (enforced in application layer too)
-- Application layer should check count < 3 before insert.

-- ----------------------------------------------------------------------------
-- users.notification_preferences
-- Per-user opt-in/out for each notification type.
-- ----------------------------------------------------------------------------
CREATE TABLE users.notification_preferences (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                     UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
    price_drop_alerts           BOOLEAN NOT NULL DEFAULT TRUE,
    new_vehicle_nearby          BOOLEAN NOT NULL DEFAULT TRUE,
    test_drive_reminders        BOOLEAN NOT NULL DEFAULT TRUE,
    rc_transfer_updates         BOOLEAN NOT NULL DEFAULT TRUE,
    subscription_reminders      BOOLEAN NOT NULL DEFAULT TRUE,
    insurance_reminders         BOOLEAN NOT NULL DEFAULT TRUE,
    platform_announcements      BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notif_prefs_user_id ON users.notification_preferences (user_id);


-- =============================================================================
-- SCHEMA: enquiries
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS enquiries;

-- ----------------------------------------------------------------------------
-- enquiries.threads
-- One thread per customer+vehicle pair. Actual messages live in Firebase.
-- phone_revealed tracks whether the shop phone number has been shown in this thread.
-- ----------------------------------------------------------------------------
CREATE TABLE enquiries.threads (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id         UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    shop_id             UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    listing_id          UUID NOT NULL REFERENCES vehicles.listings (id) ON DELETE CASCADE,
    firebase_thread_id  VARCHAR(255) UNIQUE,        -- Firestore document ID
    status              VARCHAR(30) NOT NULL DEFAULT 'new' CHECK (status IN (
                            'new',
                            'in_discussion',
                            'test_drive_scheduled',
                            'sold',
                            'closed'
                        )),
    phone_revealed      BOOLEAN NOT NULL DEFAULT FALSE,
    last_message_at     TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (customer_id, listing_id)    -- one thread per customer per vehicle
);

CREATE INDEX idx_threads_customer_id    ON enquiries.threads (customer_id);
CREATE INDEX idx_threads_shop_id        ON enquiries.threads (shop_id);
CREATE INDEX idx_threads_listing_id     ON enquiries.threads (listing_id);
CREATE INDEX idx_threads_status         ON enquiries.threads (status);
CREATE INDEX idx_threads_last_message   ON enquiries.threads (last_message_at DESC);

-- ----------------------------------------------------------------------------
-- enquiries.phone_reveal_log
-- Audit trail for every phone number reveal event.
-- ----------------------------------------------------------------------------
CREATE TABLE enquiries.phone_reveal_log (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id   UUID NOT NULL REFERENCES enquiries.threads (id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES auth.users (id),
    revealed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_phone_reveal_thread_id ON enquiries.phone_reveal_log (thread_id);


-- =============================================================================
-- SCHEMA: test_drives
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS test_drives;

-- ----------------------------------------------------------------------------
-- test_drives.bookings
-- One booking per enquiry thread. Mode is set by shop owner per listing.
-- ----------------------------------------------------------------------------
CREATE TABLE test_drives.bookings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id           UUID NOT NULL REFERENCES enquiries.threads (id) ON DELETE CASCADE,
    customer_id         UUID NOT NULL REFERENCES auth.users (id),
    shop_id             UUID NOT NULL REFERENCES shops.shop_profiles (id),
    listing_id          UUID NOT NULL REFERENCES vehicles.listings (id),
    mode                VARCHAR(20) NOT NULL CHECK (mode IN ('at_shop', 'home_delivery')),
    preferred_at        TIMESTAMPTZ NOT NULL,           -- customer's preferred slot
    confirmed_at        TIMESTAMPTZ,                    -- agreed slot after shop approval
    customer_address    TEXT,                           -- required for home_delivery mode
    status              VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN (
                            'pending',
                            'confirmed',
                            'rejected',
                            'rescheduled',
                            'completed',
                            'no_show'
                        )),
    rejection_reason    TEXT,
    reminder_sent       BOOLEAN NOT NULL DEFAULT FALSE, -- day-before reminder flag
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_td_bookings_customer_id  ON test_drives.bookings (customer_id);
CREATE INDEX idx_td_bookings_shop_id      ON test_drives.bookings (shop_id);
CREATE INDEX idx_td_bookings_listing_id   ON test_drives.bookings (listing_id);
CREATE INDEX idx_td_bookings_status       ON test_drives.bookings (status);
CREATE INDEX idx_td_bookings_confirmed_at ON test_drives.bookings (confirmed_at);


-- =============================================================================
-- SCHEMA: sales
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sales;

-- ----------------------------------------------------------------------------
-- sales.records
-- A sale record is created when a shop owner marks a vehicle as sold.
-- Becomes confirmed when both parties confirm.
-- ----------------------------------------------------------------------------
CREATE TABLE sales.records (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id              UUID NOT NULL UNIQUE REFERENCES vehicles.listings (id),
    shop_id                 UUID NOT NULL REFERENCES shops.shop_profiles (id),
    customer_id             UUID NOT NULL REFERENCES auth.users (id),
    thread_id               UUID REFERENCES enquiries.threads (id),
    shop_confirmed          BOOLEAN NOT NULL DEFAULT FALSE,
    shop_confirmed_at       TIMESTAMPTZ,
    customer_confirmed      BOOLEAN NOT NULL DEFAULT FALSE,
    customer_confirmed_at   TIMESTAMPTZ,
    is_confirmed            BOOLEAN NOT NULL DEFAULT FALSE,  -- true only when both confirm
    confirmed_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sales_listing_id   ON sales.records (listing_id);
CREATE INDEX idx_sales_shop_id      ON sales.records (shop_id);
CREATE INDEX idx_sales_customer_id  ON sales.records (customer_id);
CREATE INDEX idx_sales_confirmed    ON sales.records (is_confirmed);

-- ----------------------------------------------------------------------------
-- sales.rc_transfers
-- Auto-created after a sale is confirmed by both parties.
-- Shop owner updates the stage, customer has read-only view.
-- ----------------------------------------------------------------------------
CREATE TABLE sales.rc_transfers (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id                     UUID NOT NULL UNIQUE REFERENCES sales.records (id) ON DELETE CASCADE,
    listing_id                  UUID NOT NULL REFERENCES vehicles.listings (id),
    shop_id                     UUID NOT NULL REFERENCES shops.shop_profiles (id),
    customer_id                 UUID NOT NULL REFERENCES auth.users (id),

    -- Stage flags (checked off sequentially)
    stage                       INT NOT NULL DEFAULT 1 CHECK (stage BETWEEN 1 AND 5),
    -- 1 = documents_collected
    -- 2 = form_29_30_submitted
    -- 3 = hypothecation_cleared
    -- 4 = rc_copy_received
    -- 5 = transfer_complete

    documents_collected_at      TIMESTAMPTZ,
    form_submitted_at           TIMESTAMPTZ,
    hypothecation_cleared_at    TIMESTAMPTZ,
    rc_copy_received_at         TIMESTAMPTZ,
    transfer_complete_at        TIMESTAMPTZ,

    stage_updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- used to detect stuck transfers
    stuck_reminder_sent_at      TIMESTAMPTZ,                         -- last stuck reminder sent
    notes                       TEXT,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rc_transfers_sale_id       ON sales.rc_transfers (sale_id);
CREATE INDEX idx_rc_transfers_shop_id       ON sales.rc_transfers (shop_id);
CREATE INDEX idx_rc_transfers_customer_id   ON sales.rc_transfers (customer_id);
CREATE INDEX idx_rc_transfers_stage         ON sales.rc_transfers (stage);
CREATE INDEX idx_rc_transfers_stage_updated ON sales.rc_transfers (stage_updated_at);  -- for stuck detection


-- =============================================================================
-- SCHEMA: reviews
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS reviews;

-- ----------------------------------------------------------------------------
-- reviews.shop_reviews
-- A customer can review a shop only if they have an enquiry thread with it.
-- One review per customer per shop.
-- ----------------------------------------------------------------------------
CREATE TABLE reviews.shop_reviews (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id         UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    customer_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    thread_id       UUID NOT NULL REFERENCES enquiries.threads (id),  -- proof of enquiry
    rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text     TEXT,
    is_flagged      BOOLEAN NOT NULL DEFAULT FALSE,
    flagged_reason  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (customer_id, shop_id)   -- one review per customer per shop
);

CREATE INDEX idx_shop_reviews_shop_id     ON reviews.shop_reviews (shop_id);
CREATE INDEX idx_shop_reviews_customer_id ON reviews.shop_reviews (customer_id);
CREATE INDEX idx_shop_reviews_rating      ON reviews.shop_reviews (rating);
CREATE INDEX idx_shop_reviews_flagged     ON reviews.shop_reviews (is_flagged);


-- =============================================================================
-- SCHEMA: notifications
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS notifications;

-- ----------------------------------------------------------------------------
-- notifications.log
-- Every notification sent is recorded here.
-- ----------------------------------------------------------------------------
CREATE TABLE notifications.log (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id        UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    type                VARCHAR(60) NOT NULL CHECK (type IN (
                            'new_enquiry',
                            'price_drop',
                            'test_drive_reminder',
                            'insurance_expiry',
                            'subscription_renewal',
                            'new_vehicle_nearby',
                            'rc_transfer_stuck',
                            'sale_confirmed',
                            'verified_badge_awarded',
                            'shop_registered',          -- to association admin
                            'shop_flagged',             -- to super admin
                            'platform_announcement'
                        )),
    title               VARCHAR(255) NOT NULL,
    body                TEXT NOT NULL,
    data                JSONB,                          -- extra payload (listing_id, shop_id, etc.)
    is_read             BOOLEAN NOT NULL DEFAULT FALSE,
    fcm_message_id      VARCHAR(255),                   -- Firebase message ID for delivery tracking
    sent_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notif_log_recipient_id ON notifications.log (recipient_id);
CREATE INDEX idx_notif_log_type         ON notifications.log (type);
CREATE INDEX idx_notif_log_is_read      ON notifications.log (is_read);
CREATE INDEX idx_notif_log_sent_at      ON notifications.log (sent_at DESC);

-- ----------------------------------------------------------------------------
-- notifications.device_tokens
-- FCM device tokens per user (a user can have multiple devices).
-- ----------------------------------------------------------------------------
CREATE TABLE notifications.device_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    fcm_token   VARCHAR(500) NOT NULL UNIQUE,
    platform    VARCHAR(20) NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_tokens_user_id ON notifications.device_tokens (user_id);
CREATE INDEX idx_device_tokens_token   ON notifications.device_tokens (fcm_token);


-- =============================================================================
-- SCHEMA: analytics
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- ----------------------------------------------------------------------------
-- analytics.events
-- Raw event log. Every meaningful user action is logged here.
-- The Analytics Service aggregates these for dashboards.
-- ----------------------------------------------------------------------------
CREATE TABLE analytics.events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type      VARCHAR(60) NOT NULL CHECK (event_type IN (
                        'vehicle_viewed',
                        'shop_profile_viewed',
                        'shareable_url_visited',
                        'enquiry_created',
                        'wishlist_saved',
                        'wishlist_removed',
                        'test_drive_booked',
                        'test_drive_completed',
                        'sale_confirmed',
                        'subscription_activated',
                        'subscription_expired',
                        'search_performed'
                    )),
    actor_id        UUID REFERENCES auth.users (id) ON DELETE SET NULL,  -- who did the action
    shop_id         UUID REFERENCES shops.shop_profiles (id) ON DELETE SET NULL,
    listing_id      UUID REFERENCES vehicles.listings (id) ON DELETE SET NULL,
    metadata        JSONB,   -- extra context (search query, filter used, etc.)
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analytics_events_type       ON analytics.events (event_type);
CREATE INDEX idx_analytics_events_shop_id    ON analytics.events (shop_id);
CREATE INDEX idx_analytics_events_listing_id ON analytics.events (listing_id);
CREATE INDEX idx_analytics_events_occurred   ON analytics.events (occurred_at DESC);

-- Partition by month in production for query performance at scale
-- (For MVP, a single table is fine)

-- ----------------------------------------------------------------------------
-- analytics.shop_daily_metrics
-- Pre-aggregated daily rollups per shop. Written by the Scheduler Service.
-- Powers the shop owner dashboard without scanning the raw events table.
-- ----------------------------------------------------------------------------
CREATE TABLE analytics.shop_daily_metrics (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id                 UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    metric_date             DATE NOT NULL,
    vehicle_views           INT NOT NULL DEFAULT 0,
    profile_views           INT NOT NULL DEFAULT 0,
    shareable_url_visits    INT NOT NULL DEFAULT 0,
    enquiries_received      INT NOT NULL DEFAULT 0,
    wishlist_saves          INT NOT NULL DEFAULT 0,
    test_drives_booked      INT NOT NULL DEFAULT 0,
    test_drives_completed   INT NOT NULL DEFAULT 0,
    sales_confirmed         INT NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, metric_date)
);

CREATE INDEX idx_shop_daily_metrics_shop_id ON analytics.shop_daily_metrics (shop_id);
CREATE INDEX idx_shop_daily_metrics_date    ON analytics.shop_daily_metrics (metric_date DESC);


-- =============================================================================
-- SCHEMA: admin
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS admin;

-- ----------------------------------------------------------------------------
-- admin.association_admins
-- One row per Association Admin account. Linked to auth.users.
-- One admin per district.
-- ----------------------------------------------------------------------------
CREATE TABLE admin.association_admins (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name       VARCHAR(150) NOT NULL,
    district        VARCHAR(100) NOT NULL UNIQUE,
    state           VARCHAR(100) NOT NULL,
    organisation    VARCHAR(200),
    phone           VARCHAR(15),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_assoc_admins_district ON admin.association_admins (district);

-- ----------------------------------------------------------------------------
-- admin.flags
-- Reports from customers or association admins about shops or listings.
-- ----------------------------------------------------------------------------
CREATE TABLE admin.flags (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reported_by     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    reporter_role   VARCHAR(30) NOT NULL CHECK (reporter_role IN ('customer', 'association_admin')),
    target_type     VARCHAR(20) NOT NULL CHECK (target_type IN ('shop', 'listing', 'review')),
    target_id       UUID NOT NULL,           -- shop_id, listing_id, or review_id
    reason          VARCHAR(255) NOT NULL,
    details         TEXT,
    status          VARCHAR(30) NOT NULL DEFAULT 'open' CHECK (status IN (
                        'open',
                        'under_review',
                        'resolved',
                        'dismissed'
                    )),
    resolved_by     UUID REFERENCES auth.users (id) ON DELETE SET NULL,  -- super admin
    resolution_note TEXT,
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_flags_target_id    ON admin.flags (target_id);
CREATE INDEX idx_flags_status       ON admin.flags (status);
CREATE INDEX idx_flags_reported_by  ON admin.flags (reported_by);

-- ----------------------------------------------------------------------------
-- admin.announcements
-- Platform-wide banners/messages pushed by the Super Admin.
-- ----------------------------------------------------------------------------
CREATE TABLE admin.announcements (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_by      UUID NOT NULL REFERENCES auth.users (id),
    title           VARCHAR(255) NOT NULL,
    body            TEXT NOT NULL,
    target_audience VARCHAR(30) NOT NULL CHECK (target_audience IN (
                        'all',
                        'shop_owners',
                        'customers',
                        'district'
                    )),
    target_district VARCHAR(100),   -- only set when target_audience = 'district'
    send_push       BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    published_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_announcements_audience ON admin.announcements (target_audience);
CREATE INDEX idx_announcements_active   ON admin.announcements (is_active);

-- ----------------------------------------------------------------------------
-- admin.referrals   [v2]
-- Shop owner referral tracking for the referral program.
-- ----------------------------------------------------------------------------
CREATE TABLE admin.referrals (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_shop_id    UUID NOT NULL REFERENCES shops.shop_profiles (id) ON DELETE CASCADE,
    referred_shop_id    UUID REFERENCES shops.shop_profiles (id) ON DELETE SET NULL,
    referral_code       VARCHAR(30) NOT NULL UNIQUE,
    status              VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN (
                            'pending',      -- code shared, referred shop not yet registered
                            'registered',   -- referred shop registered but not yet paid
                            'rewarded'      -- referred shop made first payment, credit issued
                        )),
    credit_months       INT NOT NULL DEFAULT 0,  -- subscription months credited to referrer
    rewarded_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_referrals_referrer  ON admin.referrals (referrer_shop_id);
CREATE INDEX idx_referrals_code      ON admin.referrals (referral_code);


-- =============================================================================
-- TRIGGERS — auto-update updated_at timestamps
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN
        SELECT table_schema, table_name
        FROM information_schema.columns
        WHERE column_name = 'updated_at'
          AND table_schema IN (
              'auth', 'shops', 'subscriptions', 'vehicles',
              'users', 'enquiries', 'test_drives', 'sales',
              'reviews', 'notifications', 'admin'
          )
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_updated_at
             BEFORE UPDATE ON %I.%I
             FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()',
            t.table_schema, t.table_name
        );
    END LOOP;
END;
$$;


-- =============================================================================
-- VIEWS — convenience views for common queries
-- =============================================================================

-- Active listings with shop details (used by Search Service and listing pages)
CREATE OR REPLACE VIEW vehicles.active_listings_with_shop AS
SELECT
    vl.id                   AS listing_id,
    vl.registration_number,
    vl.make,
    vl.model,
    vl.variant,
    vl.year_of_manufacture,
    vl.engine_cc,
    vl.bhp,
    vl.fuel_type,
    vl.colour,
    vl.body_type,
    vl.transmission,
    vl.insurance_expiry,
    vl.asking_price,
    vl.odometer_km,
    vl.condition_grade,
    vl.is_test_drive_available,
    vl.test_drive_mode,
    vl.view_count,
    vl.wishlist_count,
    vl.enquiry_count,
    vl.created_at           AS listed_at,
    sp.id                   AS shop_id,
    sp.shop_name,
    sp.slug                 AS shop_slug,
    sp.district,
    sp.state,
    sp.is_verified          AS shop_verified,
    sp.average_rating       AS shop_rating,
    ss.status               AS subscription_status,
    ss.plan_id,
    pl.has_boost            AS is_premium,
    (SELECT cloudinary_url FROM vehicles.photos
     WHERE listing_id = vl.id AND is_primary = TRUE LIMIT 1) AS primary_photo_url
FROM vehicles.listings vl
JOIN shops.shop_profiles sp ON vl.shop_id = sp.id
LEFT JOIN subscriptions.shop_subscriptions ss ON sp.id = ss.shop_id
    AND ss.status IN ('active', 'trial')
LEFT JOIN subscriptions.plans pl ON ss.plan_id = pl.id
WHERE vl.status = 'active'
  AND sp.is_active = TRUE;

-- Shop subscription status summary (used by Shop Service)
CREATE OR REPLACE VIEW subscriptions.active_shop_status AS
SELECT
    sp.id           AS shop_id,
    sp.shop_name,
    sp.district,
    ss.status       AS subscription_status,
    ss.plan_id,
    pl.name         AS plan_name,
    pl.has_boost,
    pl.max_photos,
    ss.trial_end_at,
    ss.current_period_end,
    CASE
        WHEN ss.status = 'trial' THEN ss.trial_end_at
        WHEN ss.status = 'active' THEN ss.current_period_end
        ELSE NULL
    END             AS valid_until
FROM shops.shop_profiles sp
LEFT JOIN subscriptions.shop_subscriptions ss ON sp.id = ss.shop_id
    AND ss.status IN ('trial', 'active')
LEFT JOIN subscriptions.plans pl ON ss.plan_id = pl.id;

-- RC transfers with stage description (used by Sale & RC Transfer Service)
CREATE OR REPLACE VIEW sales.rc_transfer_status AS
SELECT
    rt.id,
    rt.sale_id,
    rt.listing_id,
    rt.shop_id,
    rt.customer_id,
    rt.stage,
    CASE rt.stage
        WHEN 1 THEN 'Documents collected'
        WHEN 2 THEN 'Form 29/30 submitted'
        WHEN 3 THEN 'Hypothecation cleared'
        WHEN 4 THEN 'RC copy received'
        WHEN 5 THEN 'Transfer complete'
    END                             AS stage_label,
    rt.stage_updated_at,
    NOW() - rt.stage_updated_at    AS stage_age,
    (NOW() - rt.stage_updated_at) > INTERVAL '7 days' AS is_stuck,
    rt.notes,
    rt.created_at
FROM sales.rc_transfers rt;


-- =============================================================================
-- SEED DATA
-- =============================================================================

-- Super Admin user (password must be set via application, this is a placeholder hash)
INSERT INTO auth.users (phone, email, password_hash, role, is_active, is_phone_verified)
VALUES (
    '9999999999',
    'admin@platform.com',
    '$2b$12$placeholder_hash_replace_on_first_deploy',
    'super_admin',
    TRUE,
    TRUE
);


-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
