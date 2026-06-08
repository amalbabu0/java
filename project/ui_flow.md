# UI Screen Flow — Pre-Owned Vehicle Marketplace

> Complete screen-by-screen flow for all four user roles: Customer, Shop Owner, Association Admin, and Super Admin. Covers every screen, what it contains, user actions, navigation paths, and edge cases.

---

## Table of Contents

1. [Flow Overview](#1-flow-overview)
2. [Shared Screens](#2-shared-screens)
3. [Customer Flow](#3-customer-flow)
4. [Shop Owner Flow](#4-shop-owner-flow)
5. [Association Admin Flow](#5-association-admin-flow)
6. [Super Admin Flow](#6-super-admin-flow)
7. [Cross-Role Flows](#7-cross-role-flows)
8. [Screen Inventory](#8-screen-inventory)

---

## 1. Flow Overview

### Entry Points

```
App Launch
    │
    ├── Returning user (valid token stored)
    │       └── → Home screen for their role
    │
    └── New / logged-out user
            └── → Landing / Onboarding screen
                    ├── Browse as guest (partial access)
                    ├── Login
                    └── Register
                            ├── As Customer
                            └── As Shop Owner
```

### Role → Home Screen Mapping

| Role | Home Screen After Login |
|------|------------------------|
| Customer (guest) | Browse screen (blurred prices) |
| Customer (logged in) | Browse screen (full access) |
| Shop Owner | Shop Dashboard |
| Association Admin | District Dashboard |
| Super Admin | Super Admin Dashboard |

### Navigation Patterns

- Mobile (Flutter): Bottom navigation bar for primary sections. Stack navigation within each section.
- Web (Next.js): Top navigation bar for customers. Sidebar navigation for shop owner and admin panels.
- Deep links: `platform.com/shop/:slug` and `platform.com/vehicles/:id` open directly to the shop profile or vehicle detail screen.

---

## 2. Shared Screens

These screens are used across multiple roles.

---

### S1 — Splash Screen

**Shown to:** All users on app launch

**Contents:**
- Platform logo and name (centred)
- Tagline (e.g. "Find your next ride")
- Loading indicator while auth token is checked

**Logic:**
- Check for stored JWT refresh token
- Valid token → auto-login → route to role's home screen
- No token / expired → route to S2 Onboarding

---

### S2 — Onboarding / Landing Screen

**Shown to:** New and logged-out users

**Contents:**
- Hero illustration or vehicle imagery
- Platform name and tagline
- Three action buttons:
  - Browse vehicles (guest mode)
  - Log in
  - Register

**Actions:**
- Browse vehicles → C1 Browse Screen (guest mode, prices blurred)
- Log in → S3 Login Screen
- Register → S4 Role Selection Screen

---

### S3 — Login Screen

**Shown to:** All users

**Contents:**
- Phone number input
- Password input
- "Log in" button
- "Forgot password?" link
- "Don't have an account? Register" link

**Validation:**
- Phone: 10-digit Indian mobile number
- Password: minimum 8 characters
- Wrong credentials → inline error message

**Actions:**
- Successful login → route to role's home screen
- Forgot password → S5 Forgot Password Screen
- Register link → S4 Role Selection Screen

---

### S4 — Role Selection Screen

**Shown to:** New users (during registration)

**Contents:**
- Two large option cards:
  - "I'm looking to buy" (customer icon)
  - "I own a vehicle showroom" (shop icon)
- Brief description under each card

**Actions:**
- Customer card → S6 Customer Registration
- Shop Owner card → S7 Shop Owner Registration

---

### S5 — Forgot Password Screen

**Contents:**
- Phone number input
- "Send OTP" button

**Flow:**
- Enter phone → OTP sent → S5a OTP Verification Screen
- Enter new password → S5b New Password Screen
- Success → S3 Login Screen with success toast

---

### S5a — OTP Verification Screen

**Contents:**
- 6-digit OTP input (auto-focus, numeric keyboard)
- Timer showing time remaining (60 seconds)
- "Resend OTP" link (active after timer expires)
- "Verify" button

**Actions:**
- Correct OTP → S5b New Password Screen
- Wrong OTP → inline error, allow retry
- Resend → new OTP sent, timer resets

---

### S6 — Customer Registration Screen

**Contents:**
- Full name input
- Phone number input
- Password input
- Confirm password input
- District / city selector (dropdown)
- "Create account" button
- "Already have an account? Log in" link

**Validation:**
- All fields required except district (optional but recommended)
- Passwords must match
- Phone must be unique

**Flow:**
- Submit → OTP verification (S5a)
- Verified → C1 Browse Screen (first time = brief welcome modal)

---

### S7 — Shop Owner Registration Screen

**Contents:**
- Personal details section:
  - Full name
  - Phone number
  - Password / Confirm password
- Shop details section:
  - Shop name
  - District selector
  - State selector
  - Shop address
  - GST number input
- "Verify GST & Create Account" button

**Validation:**
- GST number: 15-character format validated on client before API call
- All shop fields required
- Phone must be unique

**Flow:**
- Submit → GST API called (loading state shown)
  - GST passed → Account created → 30-day trial banner → SH1 Shop Dashboard
  - GST failed → Inline error "GST number not valid or not active. Please check and try again."
  - GST API error → "Unable to verify GST right now. Try again in a few minutes."

---

### S8 — Notification Centre Screen

**Shown to:** All logged-in users

**Contents:**
- List of all notifications in reverse chronological order
- Each notification shows:
  - Icon (type-specific: bell for enquiry, heart for price drop, car for new listing, etc.)
  - Title and short body text
  - Timestamp (relative: "2 hours ago")
  - Unread dot indicator
- "Mark all as read" button at top
- Empty state: "No notifications yet"

**Actions:**
- Tap notification → navigate to relevant screen
  - New enquiry → chat thread
  - Price drop → vehicle detail screen
  - RC transfer update → RC tracker screen
  - Subscription reminder → subscription screen

---

### S9 — Settings Screen

**Shown to:** All logged-in users

**Contents:**
- Profile section: name, phone, edit profile link
- Notification preferences toggles:
  - Price drop alerts
  - New vehicles nearby
  - Test drive reminders
  - Platform announcements
- Language selector (English only at MVP; v2 adds Tamil, Hindi, Telugu, Kannada)
- Change password
- Log out button
- App version number
- Privacy policy / Terms of service links

---

## 3. Customer Flow

---

### C1 — Browse / Home Screen

**Entry:** After login or guest browse

**Layout:** Top search bar + filter chips row + vehicle card grid (2 columns on mobile, 3–4 on web)

**Contents:**

Top bar:
- Platform logo / name
- Search icon (expands to full search bar)
- Notification bell (with unread count badge)
- Profile avatar

Filter chips row (horizontal scroll):
- All · Bikes · Scooters · Cars · Autos · Commercial
- Location chip (shows current district)
- Price chip (opens range picker)

Vehicle card grid:
Each card shows:
- Primary vehicle photo
- Make + model + year
- Engine CC · Fuel type
- Price (blurred with "Login to see price" overlay for guests)
- Shop name + verified badge (if applicable)
- Premium shop badge (if applicable)
- Heart icon (wishlist toggle, login required)

Bottom navigation bar (mobile):
- Home (active)
- Search
- Wishlist
- Compare
- Profile

**Actions:**
- Tap vehicle card → C2 Vehicle Detail Screen
- Tap search icon → C3 Search & Filter Screen
- Tap location chip → location picker modal
- Tap price chip → price range modal (slider)
- Tap heart → add to wishlist (login required if guest)
- Tap notification bell → S8 Notification Centre
- Tap profile avatar → C9 Customer Profile Screen
- Guest taps blurred price → login prompt modal

**Featured section (premium boost):**
- Horizontal scroll row above the main grid labelled "Featured near you"
- Shows vehicles from premium shops in the customer's district
- Only visible to logged-in customers who have opted into notifications

---

### C2 — Vehicle Detail Screen

**Entry:** Tap from browse grid, search results, wishlist, or deep link

**Layout:** Full-screen scroll. Photo gallery at top, details below.

**Contents:**

Photo gallery:
- Horizontal swipeable photo gallery
- Photo count indicator (e.g. "3 / 8")
- Primary photo shown first

Vehicle header:
- Make + Model + Variant
- Year · CC · Fuel type · Colour
- Condition grade badge (A / B / C) — v2
- Asking price (blurred for guests with "Login to view price" button)

Vehicle details section:
- Engine CC, BHP, transmission
- Insurance expiry date (with alert icon if < 30 days)
- Body type, colour
- Odometer reading (if entered by shop)
- RC status

Shop info strip:
- Shop logo thumbnail
- Shop name + verified badge + rating (e.g. 4.2 ★)
- District, state
- "View shop" link

Action buttons:
- Primary: "Enquire" button (login required; opens chat)
- Secondary: "Book test drive" button (if enabled by shop)
- Icon buttons: Heart (wishlist) · Share · Add to compare

EMI Calculator (collapsible section):
- Vehicle price (pre-filled, editable)
- Down payment input
- Tenure selector (12 / 24 / 36 / 48 / 60 months)
- Interest rate input (%)
- Calculated EMI shown live
- Total interest and total amount payable shown below

Service history section (v2):
- List of uploaded service records with date and description
- Tap to view document

Similar vehicles section (v2):
- Horizontal scroll row of comparable vehicles (same type, similar CC and price)

**Actions:**
- Swipe photos → change photo
- Tap "Enquire" → C6 Chat Screen (login required)
- Tap "Book test drive" → C5 Test Drive Booking Screen
- Tap heart → toggle wishlist
- Tap share → share sheet with shareable URL
- Tap "Add to compare" → add to comparison list (max 3)
  - If 3 already in list → "Compare now?" prompt
- Tap "View shop" → C4 Shop Profile Screen
- Tap "Login to view price" (guest) → S3 Login Screen

**Edge cases:**
- Vehicle is sold → "This vehicle has been sold" banner, enquire button hidden, similar vehicles shown
- Shop inactive (subscription expired) → "This shop is currently inactive" banner, enquire button disabled
- Insurance expired → Red alert badge on insurance expiry field

---

### C3 — Search & Filter Screen

**Entry:** Tap search icon from any screen

**Layout:** Search bar at top, active filters row, results grid below

**Contents:**

Search bar:
- Auto-focus on open
- Placeholder: "Search by make, model, or location"
- Real-time suggestions as user types (make/model names, districts)
- Clear button

Filter panel (accessible via "Filters" button or filter icon):
- Vehicle type: multi-select chips (All / Bike / Scooter / Car / Auto / Commercial)
- Location: district multi-select
- Price range: dual-handle slider (₹0 to ₹20,00,000)
- Year of manufacture: range selector
- Fuel type: multi-select chips
- Condition grade: A / B / C chips — v2
- Sort by: Newest / Price: Low to High / Price: High to Low / Most Enquired

Active filters:
- Horizontal scroll row of applied filter pills with × to remove each
- "Clear all" button

Results:
- Count of results shown ("124 vehicles found")
- Same vehicle card format as C1
- Infinite scroll or pagination

**Actions:**
- Type in search → live results update
- Apply filter → results update
- Remove filter chip → results update
- Tap vehicle → C2 Vehicle Detail Screen
- Tap shop name on card → C4 Shop Profile Screen
- No results → "No vehicles found. Try adjusting your filters."

---

### C4 — Shop Profile Screen

**Entry:** Tap shop name/link from vehicle card, vehicle detail screen, or direct shareable URL

**Layout:** Shop header at top, vehicle grid below (Instagram-style)

**Contents:**

Shop header:
- Shop logo (circle, large)
- Shop name
- Verified badge (if earned) — blue tick with "Verified" label
- Premium badge (if premium plan) — small "Featured" pill
- District, state
- Average rating + review count (e.g. "4.3 ★  ·  28 reviews")
- Total active listings count
- "View reviews" link
- Share button (copies shareable URL)

Stats row (3 columns):
- Vehicles listed
- Confirmed sales
- Member since (month/year)

Vehicle grid:
- Instagram-style square photo grid (3 columns)
- Each tile: primary photo + make/model overlay + price (blurred for guests)
- Sold vehicles shown with a grey "Sold" overlay

Inactive shop banner (shown only if subscription expired):
- "This shop is currently inactive. Enquiries are not available."
- Orange/amber background banner at top

**Guest view (shareable URL, not logged in):**
- Photos visible
- Make/model visible
- Price blurred: "Login to see price"
- Enquire button shows "Login to enquire"
- Banner: "Sign up to see prices and contact this shop"

**Actions:**
- Tap vehicle tile → C2 Vehicle Detail Screen
- Tap "View reviews" → C10 Shop Reviews Screen
- Tap share → share sheet / copy URL
- Tap verified badge → tooltip: "This shop has completed 5+ confirmed sales"
- Guest tap on blurred price → login prompt modal

---

### C5 — Test Drive Booking Screen

**Entry:** Tap "Book test drive" from C2 Vehicle Detail Screen

**Contents:**
- Vehicle summary card at top (photo, make/model, price)
- Shop name and mode label:
  - "At showroom" or "Home delivery" or "Choose mode" (if shop offers both)
- Mode selector (if both available):
  - At showroom card
  - Home delivery card (requires address)
- Date picker: calendar showing available dates (next 30 days)
- Time slot selector: morning / afternoon / evening chips
- Address input (shown only for home delivery mode)
- Notes input (optional: "Any specific requests?")
- "Submit booking request" button

**Validation:**
- Date: must be a future date
- Time: required
- Address: required for home delivery

**Flow:**
- Submit → "Booking request sent" success screen
  - Shows: "The shop owner will confirm or suggest a new time. You'll get a notification."
  - Back to vehicle detail

**Edge cases:**
- Shop has test drives disabled → this screen is not reachable
- Customer already has a pending booking for this vehicle → "You already have a pending booking. View it here."

---

### C6 — Chat Screen

**Entry:** Tap "Enquire" on vehicle detail, or tap thread in C7 Enquiry Inbox

**Layout:** Chat interface (messages top, input bottom)

**Contents:**

Header:
- Back button
- Vehicle thumbnail + make/model (tappable → C2)
- Shop name (tappable → C4)
- Phone icon button (visible after phone is revealed)

Message area:
- Chronological message bubbles
- Customer messages: right-aligned, accent colour
- Shop messages: left-aligned, surface colour
- Timestamps on each message
- "Seen" indicator on sent messages

Phone reveal section (sticky card above input):
- Shown once, at the start of the first session
- "Tap to reveal shop phone number"
- After tap: phone number shown with a "Call" button
- Logged permanently — revealed number persists across sessions

Input area:
- Text input field ("Type a message...")
- Send button

**Actions:**
- Type and send message → message appears in real-time (Firebase)
- Tap phone reveal → phone number shown, call button appears
- Tap call button → opens device dialler with shop number pre-filled
- Tap vehicle header → C2 Vehicle Detail Screen
- Tap shop name → C4 Shop Profile Screen

**Edge cases:**
- Shop subscription expired → "This shop is currently inactive. You cannot send new messages." (input disabled)
- Vehicle already sold → banner: "This vehicle has been sold."

---

### C7 — Enquiry Inbox Screen

**Entry:** Bottom nav "Profile" → "My enquiries" or notification tap

**Contents:**
- List of all enquiry threads, sorted by last message time (most recent first)
- Each thread item shows:
  - Vehicle primary photo (small, square)
  - Make + model
  - Shop name
  - Last message preview (truncated)
  - Timestamp of last message
  - Unread message count badge
  - Thread status tag: New / In discussion / Test drive scheduled / Sold (set by shop owner)

**Actions:**
- Tap thread → C6 Chat Screen

---

### C8 — Wishlist Screen

**Entry:** Bottom nav "Wishlist"

**Contents:**
- Grid of wishlisted vehicles (same card format as C1)
- Empty state: "No vehicles saved yet. Tap the heart on any vehicle to save it here."
- "Price dropped" badge on cards where price has dropped since saving

**Actions:**
- Tap card → C2 Vehicle Detail Screen
- Tap heart icon on card → remove from wishlist (confirm prompt)

---

### C9 — Vehicle Comparison Screen

**Entry:** Bottom nav "Compare" or "Add to compare" from vehicle detail

**Contents:**

When fewer than 2 vehicles added:
- Placeholder cards: "Add a vehicle to compare"
- Prompt to browse and add vehicles

When 2–3 vehicles added:
- Side-by-side columns (one per vehicle)
- Vehicle photo + make/model at top of each column
- Rows for each spec:
  - Price
  - Engine CC
  - BHP
  - Fuel type
  - Transmission
  - Colour
  - Year of manufacture
  - Insurance expiry date
  - Condition grade (v2)
  - Shop name + verified status
- Differences highlighted: cells where values differ have a subtle amber background
- "Remove" button under each vehicle

**Actions:**
- Tap vehicle photo/name → C2 Vehicle Detail Screen
- Tap "Remove" → remove from comparison
- Tap "Add another vehicle" (when < 3) → browse mode to add
- Tap "Enquire" under a vehicle column → C6 Chat Screen

---

### C10 — Shop Reviews Screen

**Entry:** "View reviews" link on C4 Shop Profile Screen

**Contents:**
- Shop name and overall rating (large, e.g. "4.3 ★")
- Rating breakdown bar chart (5★ / 4★ / 3★ / 2★ / 1★ counts)
- "Write a review" button (only shown if customer has an enquiry with this shop)
- List of reviews:
  - Customer name (first name + last initial)
  - Star rating
  - Review text
  - Date posted
- Empty state: "No reviews yet. Be the first."

**Write a review flow (modal):**
- Star rating selector (tap stars)
- Text area: "Share your experience"
- Submit button
- Success: "Review posted" toast

**Edge cases:**
- Customer has no enquiry with this shop → "Write a review" button hidden
- Customer already reviewed → "Edit your review" instead

---

### C11 — Customer Profile Screen

**Entry:** Bottom nav "Profile" or tap avatar

**Contents:**
- Profile photo (initials avatar if none uploaded)
- Full name and phone number
- Edit profile button
- Sections:
  - My enquiries → C7 Enquiry Inbox
  - My wishlist → C8 Wishlist Screen
  - Compare vehicles → C9 Comparison Screen
  - Test drive bookings → list of bookings with status
  - RC transfer status → list of active RC transfers (read-only)
- Settings → S9 Settings Screen
- Log out

---

### C12 — RC Transfer Status Screen (Customer)

**Entry:** C11 Profile → RC transfer status, or notification tap

**Contents:**
- Vehicle details at top (make, model, registration number)
- Shop name
- 5-stage progress stepper:
  - Step 1: Documents collected
  - Step 2: Form 29/30 submitted
  - Step 3: Hypothecation cleared
  - Step 4: RC copy received
  - Step 5: Transfer complete
- Current stage highlighted
- Completed stages shown with a green check
- Date completed shown for each finished stage
- "Stuck" notice if stage unchanged for 7+ days: "This step has been pending for 7 days. The shop has been reminded."

**Note:** Read-only for customers. No edit capability.

---

## 4. Shop Owner Flow

---

### SH1 — Shop Dashboard (Home)

**Entry:** After login for shop owner role

**Layout:** Summary cards at top, quick actions row, recent activity feed

**Contents:**

Trial / subscription banner (top):
- Trial active: "Free trial — X days remaining. Subscribe to keep your listings active."
- Subscription active: "Premium plan · Renews on [date]" (or "Basic plan")
- Expired: "Your subscription has expired. Renew now to re-enable enquiries."

Summary metric cards (2×2 grid):
- Total vehicles listed
- New enquiries this week
- Profile views this month
- Confirmed sales (all time)

Quick action buttons:
- Add vehicle
- View enquiries
- View analytics
- Manage subscription

Recent activity feed:
- "New enquiry on [Vehicle] from [Customer first name]" — 2 hours ago
- "[Vehicle] added to 3 wishlists today"
- "Insurance expiring in 14 days: [Vehicle reg]"
- "Test drive booked for [Vehicle] on [date]"

Bottom navigation (mobile):
- Dashboard
- Inventory
- Enquiries
- Analytics
- Profile

**Actions:**
- Tap "Add vehicle" → SH3 Add Vehicle Screen
- Tap enquiry activity → SH6 Chat Screen
- Tap metric card → relevant screen (e.g. enquiries card → SH5 Enquiry Inbox)
- Tap subscription banner → SH10 Subscription Screen

---

### SH2 — Inventory Screen

**Entry:** Bottom nav "Inventory"

**Layout:** Filter tabs at top, vehicle list below

**Contents:**

Tabs:
- Active (count)
- Sold (count)
- Archived (count)
- All (count)

Sort options: Newest / Oldest / Price high / Price low / Most enquiries / Insurance expiry

Each vehicle item in list:
- Primary photo (small, left-aligned)
- Make + model + year + registration number
- Price
- Status badge: Active / Sold / Archived
- Enquiry count (e.g. "3 enquiries")
- Wishlist save count
- Insurance expiry date (amber if < 30 days, red if expired)
- Quick action icons: Edit · Mark sold · Archive

FAB (Floating Action Button):
- "+" button → SH3 Add Vehicle Screen

**Actions:**
- Tap vehicle row → SH4 Vehicle Management Screen
- Tap "+" FAB → SH3 Add Vehicle Screen
- Tap "Edit" icon → SH4 Vehicle Management Screen
- Tap "Mark sold" → sale initiation modal (enter customer phone to notify)
- Tap "Archive" → confirm prompt → vehicle archived

---

### SH3 — Add Vehicle Screen

**Entry:** "Add vehicle" from SH1 or SH2

**Layout:** Step-by-step form (3 steps)

**Step 1 — Registration number**

Contents:
- Large registration number input field
- Indian number plate format hint (e.g. TN 09 AB 1234)
- "Fetch vehicle details" button

Flow:
- Tap "Fetch vehicle details":
  - Loading state: "Fetching vehicle details from RTO..."
  - Success → Step 2 with pre-filled data
  - Failure → "Unable to fetch details. You can enter details manually." → Step 2 with empty form

**Step 2 — Review & complete details**

Contents:
- Vehicle details fetched from API (read-only, greyed out):
  - Make, model, variant
  - Year of manufacture
  - Engine CC, BHP, fuel type, colour
  - Insurance expiry date
  - RC status
- Fields to fill in by shop owner (editable):
  - Asking price (mandatory)
  - Odometer reading (km)
  - Condition grade selector: A / B / C (v2)
  - Test drive enabled toggle
  - Test drive mode selector (at shop / home delivery / both) — shown if toggle on
  - Notes / description (text area)
- "Next: Add photos" button

**Step 3 — Add photos**

Contents:
- Photo upload grid (tap + to add)
- Primary photo selector (tap to set any photo as primary)
- Photo count indicator (e.g. "3 / 5 photos" for basic, "3 / 15" for premium)
- Tip: "Add at least 3 photos. Listings with more photos get 2× more enquiries."
- "Publish listing" button

Flow:
- Tap + → device camera/gallery picker
- Upload progress indicator per photo
- Tap "Publish listing" → success screen
  - "Your vehicle is now live!"
  - "Share your shop profile:" + shareable URL with copy button
  - "View listing" and "Add another vehicle" buttons

**Edge cases:**
- Subscription expired → blocked from adding vehicles, redirect to SH10 Subscription Screen
- Registration number already listed → "This vehicle is already listed. View listing?"
- Premium photo limit not reached (basic plan) → nudge: "Upgrade to Premium to add up to 15 photos"

---

### SH4 — Vehicle Management Screen

**Entry:** Tap vehicle from SH2 Inventory

**Layout:** Vehicle detail view with edit capability

**Contents:**

Top section:
- Photo gallery (swipeable, with option to add/remove/reorder photos)
- Make, model, registration number

Editable fields:
- Asking price (inline edit, tap to edit)
- Odometer reading
- Condition grade (v2)
- Notes/description
- Test drive enabled toggle + mode

Stats strip (read-only):
- Total enquiries
- Wishlist saves
- Profile views
- Days listed

Insurance alert (if expiry within 30 days):
- Amber banner: "Insurance expires on [date]. Renew soon to maintain buyer trust."

Action buttons:
- Save changes
- Mark as sold
- Archive listing
- Delete listing (with confirmation modal)

**Mark as sold flow:**
- Modal: "Who bought this vehicle?"
  - Customer phone number input (to send confirmation request)
  - Or: "Select from existing enquiries" (list of customers who enquired)
- Confirm → sale record created, customer notified → SH11 RC Transfer Screen

---

### SH5 — Enquiry Inbox Screen

**Entry:** Bottom nav "Enquiries"

**Layout:** Filter tabs, thread list

**Contents:**

Tabs / filter:
- All
- New (unread)
- In discussion
- Test drive scheduled
- Sold

Each thread item:
- Vehicle thumbnail
- Make + model
- Customer name (first name + last initial)
- Last message preview
- Timestamp
- Status tag (colour-coded pill)
- Unread badge

**Actions:**
- Tap thread → SH6 Chat Screen
- Swipe left on thread → quick status update options

---

### SH6 — Chat Screen (Shop Owner)

**Entry:** Tap thread in SH5 Enquiry Inbox or notification tap

**Layout:** Chat interface with vehicle and customer context

**Contents:**

Header:
- Back button
- Vehicle thumbnail + make/model (tappable → SH4)
- Customer name

Status tag selector (visible to shop owner only):
- Pill showing current status (tappable)
- Dropdown: New → In discussion → Test drive scheduled → Sold

Message area:
- Same as C6 Chat Screen (real-time Firebase messages)

Customer's phone (shown in header or info strip):
- Customer phone number shown after first message (visible to shop owner)
- Call button

Input area:
- Text input + send button

Quick reply chips (optional):
- "I'll check availability"
- "Please share your preferred test drive time"
- "This vehicle is available"

**Actions:**
- Send message → real-time delivery
- Tap status tag → update enquiry status
- Tap call button → opens dialler
- Tap "Mark as sold" shortcut → SH4 Vehicle Management → mark sold flow

---

### SH7 — Analytics Screen

**Entry:** Bottom nav "Analytics" or tap from SH1 Dashboard

**Layout:** Date range picker at top, metric cards, charts below

**Contents:**

Date range selector: This week / This month / Last 3 months / Custom

Metric cards row (scroll horizontally):
- Total enquiries
- Total profile views
- Total vehicle views
- Wishlist saves
- Test drives booked
- Test drives completed
- Confirmed sales

Charts section:
- Enquiries over time (line chart, per day)
- Top 5 most viewed vehicles (bar chart, horizontal)
- Top 5 most enquired vehicles (bar chart, horizontal)

Vehicle-level breakdown table:
- Each active vehicle with its: views, enquiries, wishlist saves, test drives booked
- Sortable by each column

Subscription info card:
- Plan name, renewal date, days remaining
- "Upgrade to Premium" CTA (if on basic plan)

---

### SH8 — Shop Profile Settings Screen

**Entry:** Bottom nav "Profile" → Edit shop profile

**Contents:**
- Shop logo upload (tap to change)
- Shop name
- Description (text area)
- Phone number
- Address
- District and state (read-only after registration — contact support to change)
- GST number (read-only, shown for reference)
- Verified badge status:
  - Not verified: "X / 5 sales completed. Complete 5 sales to earn the Verified Badge."
  - Verified: "Verified Badge earned ✓"
- Shareable URL:
  - URL display: `platform.com/shop/your-shop-slug`
  - Copy button
  - Share button (opens share sheet for WhatsApp, etc.)
- Save button

---

### SH9 — Test Drive Management Screen

**Entry:** SH1 Dashboard → recent activity, or from SH5 Enquiry Inbox thread

**Contents:**
- List of all test drive bookings with status
- Tabs: Pending / Confirmed / Completed / Rejected

Each booking item:
- Vehicle thumbnail + make/model
- Customer name
- Requested date/time
- Mode: At shop / Home delivery
- Customer address (for home delivery)
- Status badge

**Actions:**
- Tap "Approve" → booking confirmed, both parties notified
- Tap "Reject" → rejection reason input (optional) → customer notified
- Tap "Reschedule" → new date/time picker → sent to customer for re-confirmation
- Tap "Mark completed" → booking marked complete

---

### SH10 — Subscription Screen

**Entry:** Dashboard banner, bottom nav Profile → Subscription, or expired prompt

**Contents:**

Current status card:
- Plan name (Basic / Premium / Trial / Expired)
- Status badge (green Active / amber Trial / red Expired)
- Valid until date (or trial end date)
- Days remaining

Plan comparison cards:

Basic — ₹299/month:
- Unlimited vehicle listings
- 5 photos per vehicle
- Standard search placement
- Text chat with customers
- Phone number reveal

Premium — ₹599/month (recommended badge):
- Unlimited vehicle listings
- 15 photos per vehicle
- Top of search results
- Push notification to nearby customers
- Text chat with customers
- Phone number reveal
- "Featured" badge on listings

Payment history table:
- Date, plan, amount, status (paid / failed)
- Download invoice link per row

**Actions:**
- Tap "Subscribe" or "Upgrade" → Razorpay payment sheet opens
- Payment success → subscription activated, success toast, page refreshes
- Payment failure → error toast with retry option

---

### SH11 — RC Transfer Tracker Screen (Shop Owner)

**Entry:** SH1 Dashboard activity, SH5 Enquiry Inbox, or C12 customer view link

**Contents:**
- Vehicle details (make, model, registration number)
- Buyer name (customer who confirmed the sale)
- 5-stage stepper (vertical, with current stage highlighted):

  Stage 1: Documents collected
  - Status: Done / Pending
  - "Mark done" button (if pending and this is current stage)
  - Date completed (if done)

  Stage 2: Form 29/30 submitted at RTO
  - Same structure

  Stage 3: Hypothecation cleared
  - Same structure
  - Note: "Skip this step if no loan was taken on this vehicle" checkbox

  Stage 4: RC copy received
  - Same structure

  Stage 5: Transfer complete
  - "Mark complete" button → triggers completion notification to buyer

- Notes field: free text for the shop owner to add context

**Actions:**
- Tap "Mark done" on current stage → stage advances, customer notified, timestamp recorded
- Add notes → saved to RC transfer record

---

## 5. Association Admin Flow

---

### AA1 — District Dashboard Screen

**Entry:** After login for association admin role

**Layout:** Summary at top, shop list below

**Contents:**

District header:
- Admin name and district name
- "Serving [District] district"

Summary metric cards:
- Total shops in district (count)
- Active subscriptions (count)
- Shops in trial (count)
- Total confirmed sales in district (count only — no revenue)

New shop alerts section:
- List of shops registered in the last 7 days pending genuinity review
- Each item: shop name, GST number, registered date, "Review" button
- Tap "Review" → AA2 Shop Detail Screen

All shops section:
- Searchable list of all shops in the district
- Each item:
  - Shop name
  - Verified badge (if applicable)
  - Subscription status (active / trial / expired)
  - Confirmed sales count
  - Member since date

**Actions:**
- Tap shop → AA2 Shop Detail Screen
- Tap "Review" on new shop → AA2 Shop Detail Screen
- Tap metric card → filtered shop list

---

### AA2 — Shop Detail Screen (Association Admin View)

**Entry:** Tap shop from AA1 Dashboard

**Contents:**
- Shop name + logo
- GST number
- District, address
- Phone number
- Member since date
- Subscription status + plan name
- Verified badge status
- Confirmed sales count
- Active vehicle listings count

Vehicle grid (view only):
- Same grid as C4 Shop Profile Screen
- Prices visible to association admin

Actions available to Association Admin:
- "Flag this shop" button → AA3 Flag Shop Screen
- View public shop profile → opens C4 Shop Profile Screen

**Not visible to Association Admin:**
- Subscription amount paid
- Revenue or sales amounts
- Enquiry details

---

### AA3 — Flag Shop Screen

**Entry:** "Flag this shop" from AA2

**Contents:**
- Shop name (pre-filled, read-only)
- Reason selector:
  - Suspected fake business
  - GST mismatch
  - Fraudulent listings
  - Customer complaints
  - Other
- Details text area (required)
- "Submit flag to super admin" button

**Flow:**
- Submit → flag created in `admin.flags`, super admin notified
- Success: "Flag submitted. The super admin team will review this shop."
- Back to AA1 Dashboard

---

## 6. Super Admin Flow

---

### SA1 — Super Admin Dashboard

**Entry:** After login for super_admin role

**Layout:** Platform-wide metrics grid, alert sections below

**Contents:**

Platform health cards (2×4 grid):
- Total active shops
- Shops in trial
- Total vehicles listed
- Total enquiries (all time)
- Total confirmed sales
- Subscriptions active
- Subscriptions expired
- Verified badges awarded

Alert sections:
- Open flags (count): "3 shops flagged — Review"
- Expiring subscriptions (count): "12 shops expiring in 7 days"
- Stuck RC transfers (count): "4 transfers stuck for 7+ days"
- New shops today (count)

Recent activity log:
- "Shop [Name] registered in [District]" — 1 hour ago
- "Subscription expired: [Shop Name]" — 3 hours ago
- "Flag submitted by [Association Admin] for [Shop Name]" — 5 hours ago

Sidebar navigation (web):
- Dashboard
- Shops
- Subscriptions
- Flags & Reports
- Association Admins
- Announcements
- GST Log
- Settings

---

### SA2 — All Shops Screen

**Entry:** Sidebar "Shops"

**Contents:**
- Search bar (search by shop name, GST, district)
- Filter bar: Status (active / trial / expired / suspended) · District · State · Plan (basic / premium) · Verified
- Shops table / list:
  - Shop name + logo
  - GST number
  - District, state
  - Plan (Basic / Premium / Trial)
  - Status badge
  - Verified badge
  - Sales count
  - Registered date
  - Actions: View · Suspend · Extend subscription

**Actions:**
- Tap shop → SA3 Shop Detail Screen (Admin)
- Tap "Suspend" → confirm modal → shop suspended
- Tap "Extend subscription" → SA5 Subscription Override Screen

---

### SA3 — Shop Detail Screen (Super Admin View)

**Entry:** Tap shop from SA2

**Contents:**
Everything from AA2 (Association Admin view) plus:

- Full subscription history (plan, amount, dates, payment status)
- Payment history (Razorpay order IDs, amounts)
- All flags on this shop (with flag reason and reporter)
- GST verification log entry for this shop
- Enquiry count (total)

Actions available to Super Admin:
- Suspend / Activate shop
- Override subscription (extend or change plan) → SA5
- Resolve open flags on this shop
- Remove verified badge (exceptional cases)
- View as public shop profile → C4

---

### SA4 — Flags & Reports Screen

**Entry:** Sidebar "Flags & Reports"

**Contents:**
- Tabs: Open / Under review / Resolved / Dismissed
- Each flag item:
  - Target shop/listing name
  - Flagged by (customer or association admin name)
  - Reason
  - Date flagged
  - Status badge
  - "Review" button

**Actions:**
- Tap "Review" → flag detail modal:
  - Full flag details
  - Link to view the flagged shop/listing
  - Status update: Mark under review / Resolve / Dismiss
  - Resolution note input
  - Submit

---

### SA5 — Subscription Override Screen

**Entry:** SA2 "Extend subscription" or SA3 Shop Detail

**Contents:**
- Shop name (pre-filled)
- Current subscription status and expiry date
- Override action selector:
  - Extend by N days (numeric input)
  - Change plan: Basic / Premium
  - Grant free month
- Override reason (required text input)
- "Apply override" button

**Flow:**
- Apply → subscription updated, shop owner notified with "Your subscription has been extended" notification
- Change logged to subscriptions table with `override_by_admin = true`

---

### SA6 — Association Admins Screen

**Entry:** Sidebar "Association Admins"

**Contents:**
- List of all association admin accounts:
  - Name, district, state, phone, status (active / inactive), created date
- "Add association admin" button → SA7 Add Association Admin Screen

**Actions:**
- Tap admin → view/edit details
- Toggle active/inactive

---

### SA7 — Add Association Admin Screen

**Entry:** SA6 "Add association admin"

**Contents:**
- Full name input
- Phone number input (becomes their login)
- Temporary password input
- District selector
- State selector
- Organisation name input
- "Create account" button

**Flow:**
- Submit → auth.users row created (role = association_admin), admin.association_admins row created
- SMS sent to new admin with login details
- Success: "Association admin created for [District]"

---

### SA8 — Announcements Screen

**Entry:** Sidebar "Announcements"

**Contents:**
- List of past announcements (title, audience, date, active status)
- "Create announcement" button → SA9 Create Announcement Screen

---

### SA9 — Create Announcement Screen

**Entry:** SA8 "Create announcement"

**Contents:**
- Title input
- Body text area
- Target audience selector:
  - All users
  - Shop owners only
  - Customers only
  - Specific district (district selector appears)
- Send as push notification toggle
- Publish immediately toggle (or schedule date/time picker)
- Preview button (shows how it will look in the app)
- "Publish" button

---

### SA10 — GST Verification Log Screen

**Entry:** Sidebar "GST Log"

**Contents:**
- Date range filter
- Status filter: All / Passed / Failed / API error
- Log table:
  - Date/time
  - Shop name (linked)
  - GST number
  - Status (passed / failed / api_error)
  - API response summary
- Export to CSV button

---

## 7. Cross-Role Flows

### Flow A — Full Vehicle Sale Journey

```
Shop Owner (SH4)
    Mark vehicle as sold → enter customer phone
        │
        ▼
Sale record created (status: awaiting customer confirmation)
        │
        ▼
Customer receives push notification:
    "Confirm your purchase of [Make Model]"
        │
        ▼
Customer (C12) taps notification → Confirmation screen
    "Did you purchase this vehicle from [Shop]?"
    [Confirm] [Not me]
        │
        ▼
Both confirmed → sale counted
    ├── Shop: confirmed_sale_count + 1
    ├── If count reaches 5 → Verified Badge awarded
    ├── RC Transfer Tracker auto-created
    └── Both parties notified: "Sale confirmed!"
        │
        ▼
RC Transfer in progress
    Shop Owner (SH11) updates stages
    Customer (C12) watches read-only progress
    Scheduler checks for stuck stages daily
```

---

### Flow B — Premium Boost Discovery

```
Shop Owner subscribes to Premium (SH10)
        │
        ▼
Subscription activated
        │
        ▼
Next vehicle added (SH3) or existing vehicles re-indexed
        │
        ▼
Search Service re-orders results: Premium vehicles first
        │
        ▼
Customer (C1) browses "Featured near you" section
    → Sees premium shop vehicles in featured row
        │
        ▼
Notification Service sends push to customers in same district:
    "New [Make Model] listed near you — ₹[Price]"
        │
        ▼
Customer taps notification → C2 Vehicle Detail Screen
```

---

### Flow C — Review Eligibility Check

```
Customer viewed a vehicle (C2) → clicked Enquire (C6)
    → Enquiry thread created in enquiries.threads
        │
        ▼
Customer navigates to Shop Profile (C4)
    → "Write a review" button visible
        │
        ▼
Customer taps "Write a review" (C10)
    → Review Service checks: does enquiries.threads row
      exist for this customer + shop? YES → allow
        │
        ▼
Customer submits review → visible on shop profile
```

---

### Flow D — Subscription Expiry Impact

```
Scheduler (daily 8 AM):
    Finds subscription with current_period_end < NOW()
        │
        ▼
subscription.expired event published
        │
        ├── Shop Service:
        │       → Add "Inactive Shop" label to shop profile
        │       → Disable enquiry button on all listings
        │
        └── Search Service:
                → Remove shop's vehicles from search results
        │
        ▼
Customer views shop profile (C4):
    → Sees amber "This shop is currently inactive" banner
    → Enquire button is greyed out and disabled
        │
        ▼
Shop owner (SH10):
    → Dashboard shows red "Subscription expired" banner
    → Renews subscription → Razorpay payment
    → subscription.activated event
        │
        ├── Shop Service: Remove inactive label
        └── Search Service: Re-index vehicles
```

---

## 8. Screen Inventory

### Customer Screens

| Screen ID | Screen Name | Entry Point |
|-----------|-------------|-------------|
| C1 | Browse / Home | Login, guest browse |
| C2 | Vehicle Detail | C1 grid, C3 results, C8 wishlist, deep link |
| C3 | Search & Filter | Search icon from any screen |
| C4 | Shop Profile | Vehicle card, vehicle detail, shareable URL |
| C5 | Test Drive Booking | C2 "Book test drive" button |
| C6 | Chat | C2 "Enquire", C7 inbox |
| C7 | Enquiry Inbox | Bottom nav, notification tap |
| C8 | Wishlist | Bottom nav |
| C9 | Vehicle Comparison | Bottom nav, "Add to compare" |
| C10 | Shop Reviews | C4 "View reviews" |
| C11 | Customer Profile | Bottom nav "Profile" |
| C12 | RC Transfer Status | C11 profile, notification |

### Shop Owner Screens

| Screen ID | Screen Name | Entry Point |
|-----------|-------------|-------------|
| SH1 | Shop Dashboard | Login |
| SH2 | Inventory | Bottom nav "Inventory" |
| SH3 | Add Vehicle | SH1, SH2 FAB |
| SH4 | Vehicle Management | SH2 vehicle row |
| SH5 | Enquiry Inbox | Bottom nav "Enquiries" |
| SH6 | Chat (shop side) | SH5 thread, notification |
| SH7 | Analytics | Bottom nav "Analytics" |
| SH8 | Shop Profile Settings | Bottom nav "Profile" |
| SH9 | Test Drive Management | SH1 activity, SH5 thread |
| SH10 | Subscription | Dashboard banner, profile |
| SH11 | RC Transfer Tracker | SH1 activity, SH5 |

### Shared Screens

| Screen ID | Screen Name | Users |
|-----------|-------------|-------|
| S1 | Splash | All |
| S2 | Onboarding / Landing | New, logged-out |
| S3 | Login | All |
| S4 | Role Selection | New users |
| S5 | Forgot Password | All |
| S5a | OTP Verification | All |
| S6 | Customer Registration | New customers |
| S7 | Shop Owner Registration | New shop owners |
| S8 | Notification Centre | All logged-in |
| S9 | Settings | All logged-in |

### Association Admin Screens

| Screen ID | Screen Name | Entry Point |
|-----------|-------------|-------------|
| AA1 | District Dashboard | Login |
| AA2 | Shop Detail (admin view) | AA1 shop list |
| AA3 | Flag Shop | AA2 |

### Super Admin Screens

| Screen ID | Screen Name | Entry Point |
|-----------|-------------|-------------|
| SA1 | Super Admin Dashboard | Login |
| SA2 | All Shops | Sidebar |
| SA3 | Shop Detail (super admin view) | SA2 |
| SA4 | Flags & Reports | Sidebar, SA1 alert |
| SA5 | Subscription Override | SA2, SA3 |
| SA6 | Association Admins | Sidebar |
| SA7 | Add Association Admin | SA6 |
| SA8 | Announcements | Sidebar |
| SA9 | Create Announcement | SA8 |
| SA10 | GST Verification Log | Sidebar |

**Total screens: 45**
(12 customer + 11 shop owner + 10 shared + 3 association admin + 9 super admin)

---

*Document last updated: June 2026*
*Version: 1.0 — Pre-development UI screen flow*
