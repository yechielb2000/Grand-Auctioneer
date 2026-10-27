Product Requirements Document (PRD) & Technical Spec

Project Title: Auction Empire (Working Title)

Target Platforms: Cross-Platform Mobile (iOS & Android) — Initial Release: Google Play Store
Tech Stack: Flutter / React Native + Google Firebase (Strictly 100% Free Spark Plan) + Google AdMob.

1. Executive Summary & Core Game Concept

Auction Empire is a competitive multi-player economy and auction simulation mobile game. Players start from scratch with a modest starter property and a few randomized inventory items. Through strategic bidding, trading, flipping assets, and customizing properties, players build a high-net-worth real estate and luxury goods empire.

Key Highlights:

Player-Driven Economy: Players own properties, vehicles, furniture, and collectibles, which they can list for auction or bid on in real-time.

4 Auction Types: English, Dutch, First-Price Sealed Bid, and Second-Price (Vickrey) Auctions.

Interactive Map & Property Management: Interactive spatial map showcasing owned properties (houses, garages, warehouses, docks) with interior design and item-placement features.

Ethical Monetization: No intrusive forced pop-up ads. Monetization is solely via Rewarded Video Ads (Google AdMob) where players explicitly choose to watch ads for in-game currency, diamonds, or rare mystery boxes.

Zero Backend Costs (Google Free Tier Optimized): Built entirely on Google Firebase Spark Plan (Free) utilizing client-side validation, Firestore atomic transactions, and Firebase Cloud Messaging (FCM).

2. Technical Stack & Google Free Tier Architecture

To run the app with $0 infrastructure costs, the app uses Google Cloud / Firebase Free Tier (Spark Plan) with strict optimization patterns to stay well within daily free quotas:

2.1 Google Firebase Infrastructure (Free Spark Plan)

Firebase Authentication: Unlimited Google Sign-In & Anonymous Auth.

Cloud Firestore (NoSQL Database):

Free Quota: 50,000 Reads/day, 20,000 Writes/day, 20,000 Deletes/day, 1 GiB total storage.

Optimization Strategy: Extensive local caching using local persistence (enablePersistence()). State changes (e.g., bid increments) write only on final actions using Firestore Transaction to avoid redundant write operations.

Firebase Cloud Messaging (FCM): 100% Free unlimited push notifications. Used for outbid alerts, auction victory notifications, and state sync triggers instead of paid WebSocket servers.

Firebase Cloud Storage:

Free Quota: 5 GB total storage, 20,000 Download operations/day.

Optimization Strategy: Asset graphics (furniture, cars, UI elements) are bundled locally within the app binary (SVG/Rive/PNG). Cloud storage is only used for user avatars and custom asset uploads.

Firebase Remote Config & Analytics: 100% Free. Used for game balancing (adjusting auction starting prices, event frequencies, item drops) on the fly without updating the app binary.

3. Account Management & Onboarding Flow

3.1 Authentication (Google Sign-In)

Primary Auth: Native Google Sign-In via Firebase Auth (google_sign_in package).

Data Stored On Account Creation (Firestore Document /users/{uid}):

uid: String (Google User Identifier)

email: String

displayName: String & avatarUrl: String

fcmToken: String (For free push notifications)

virtualCash: Double (Initial Balance: $10,000)

diamonds: Int (Initial Premium Balance: 50 Diamonds)

netWorth: Double (Calculated dynamically)

createdAt: Timestamp & lastLoginAt: Timestamp

3.2 Onboarding & Starter Kit

Upon first login, the user experiences an interactive starter flow:

Welcome Bonus: User receives a starter pack consisting of:

Property: "Small Studio Apartment" (Base tier property on the map).

3 Starter Items (Randomized Draw): e.g., 1x Vintage Sofa, 1x Used Scooter, 1x Retro Arcade Cabinet.

Guided Tutorial: A 4-step interactive walkthrough demonstrating how to place an item in a house and how to list an item on the Auction House.

4. Game World & Economy System

4.1 Currency & Resource System

Soft Currency (In-game Cash - $): Used for standard auctions, property maintenance, and local trades. Earned through flipping items, renting out properties, and watching Rewarded Ads.

Hard Currency (Diamonds - 💎): Used for speeding up auctions, acquiring exclusive blueprint properties, expanding storage space, and purchasing premium cosmetics. Earned via daily streaks, achievements, or Rewarded Ads.

4.2 Property Types & Map Mechanics

The world is presented via an interactive, zoomable 2D Isometric Map divided into districts (e.g., Suburbs, Downtown, Marina District, Industrial Zone).

Property Classes:

Residential (Apartments, Villas, Penthouses): Displays placed furniture and decor. Generates passive "Rent Income" over time based on total interior value.

Storage Warehouses: Increases total inventory slot capacity for flipping goods.

Car Lots & Garages: Exclusive slots for land vehicles (cars, motorcycles).

Docks & Marinas: Exclusive slots for marine assets (boats, yachts).

Placement System:

Each property has a fixed number of grid slots/hotspots where owned items can be assigned/displayed.

Placing higher-rarity items inside a property increases its total Prestige Rating and rent yields.

5. Live Auction House Engine (Core Gameplay)

The seller chooses an item to list, sets the duration (e.g., 1 hour, 6 hours, 24 hours), and selects one of 4 Real-Time Auction Modes:

      +-----------------------------------------------------------+
      |                   AUCTION ENGINE MODES                    |
      +-------------------+-------------------+-------------------+
      | 1. English        | Open, ascending bids; highest wins|
      | 2. Dutch          | Price drops until first bid clicks|
      | 3. Sealed-Bid     | Hidden single bids; highest pays  |
      | 4. Vickrey        | Hidden bids; highest wins, pays 2nd|
      +-------------------+-------------------+-------------------+


5.1 English Auction (Ascending Bids)

Standard public bidding. Highest bidder when timer expires wins.

Minimum Bid Increment enforced (e.g., 5% over current bid).

Anti-Sniping Rule: If a bid is placed in the last 15 seconds, the timer extends by +15 seconds.

5.2 Dutch Auction (Descending Price)

Starts at a high "Buy Now" price and decreases by X% every Y seconds automatically (calculated client-side based on startTime and priceDropRate to save server calls).

The first player to click "Buy Now" executes a Firestore Atomic Transaction to instantly claim the item at the current price.

5.3 First-Price Sealed-Bid (Blind Auction)

Players submit a hidden bid before the countdown ends (written to a encrypted /auctions/{id}/bids/{uid} subcollection).

When time expires, client-side logic reveals bids. The highest bidder wins and pays their exact bid amount.

5.4 Second-Price Sealed-Bid (Vickrey Auction)

Players submit a hidden bid.

Highest bidder wins the item, but pays the price of the second-highest bid (+1 unit).

5.5 Serverless Auction Resolution (Free Tier Friendly)

Without Cloud Functions (which require paid GCP billing), auctions are resolved safely using Client-Triggered Firestore Transactions:

When a player opens an expired auction or receives an FCM push notification that an auction ended, the client calls a deterministic Firestore Transaction:

Verifies timer endTime < currentTime.

Transfers item ownership to winner's inventory.

Transfers cash from winner to seller.

Marks auction status as COMPLETED.

6. Ad Integration & Ethical Monetization (Google AdMob)

Strict Rule: NO forced interstitials or banner ads during gameplay. All ad touchpoints are Rewarded Video Ads initiated voluntarily by the player.

6.1 Rewarded Ad Touchpoints

Trigger Location

Reward

Daily Limit

Cooldown

Bank / Store Screen

+$2,500 Cash or 5 Diamonds

5 times/day

None

Auction Extension

+1 Free Auction Listing Fee waiver

3 times/day

1 Hour

Daily Mystery Box

Watch 1 ad to open a "Loot Container" (Random Item)

2 times/day

12 Hours

Instant Property Rent

Instantly collect 4 hours of passive property rent

3 times/day

4 Hours

6.2 Ad Engine Implementation

Integrates google_mobile_ads SDK.

Handles graceful fallbacks when ads are offline or fill rate is low.

Grants rewards immediately via client-side state after receiving successful onUserEarnedReward callback.

7. UI / UX & Visual Style Guide

7.1 Visual Theme: Modern Dark Luxury Glassmorphism

Background: Dark slate Navy/Charcoal (#0B0E14, #131722).

Cards & Surfaces: Semi-transparent frosted glass with light borders (rgba(255, 255, 255, 0.05) background, 1px solid rgba(255, 255, 255, 0.1) border, backdrop-filter: blur(16px)).

Accent Colors:

Electric Gold / Amber: #FFD700 / #FFAB00 (Used for Money, Bids, Winner Highlights).

Emerald Green: #00E676 (Used for Buy Buttons, Profit Indicators).

Neon Crimson: #FF1744 (Used for Timers, Live Dutch Auction drops, Outbid alerts).

Diamond Cyan: #00E5FF (Used for Premium Diamond Currency & Legendary items).

7.2 Typography & Monospace Numerals

Headings: Bold, punchy sans-serif (Montserrat / Plus Jakarta Sans).

Monospace Numerals: All cash displays, counters, and timers must use a tabular/monospace font (JetBrains Mono / Roboto Mono) to prevent text jitter during updates.

8. App Screen Navigation & Structure

                             +-----------------------+
                             |   Main Navigation     |
                             +-----------+-----------+
                                         |
     +-----------------+-----------------+-----------------+-----------------+
     |                 |                 |                 |                 |
+----+----+       +----+----+       +----+----+       +----+----+       +----+----+
|   MAP   |       | AUCTIONS|       |  INVENTORY |    | BANK /  |       |SETTINGS |
| SCREEN  |       |   HOUSE |       | & ASSETS   |    | REWARDS |       | & PROFILE|
+---------+       +---------+       +------------+    +---------+       +---------+


Screen 1: Interactive World Map (/map)

Pan-and-zoom 2D grid featuring owned vs. available real estate.

Property detail drawer: item placement and rent collection.

Screen 2: Auction House (/auctions)

Tabs: Live Auctions, My Listings, Create Auction.

Live bids, filters by auction type, real-time countdowns using FCM/Firestore snapshot listeners.

Screen 3: My Assets & Warehouse (/inventory)

Grid layout showing owned items.

Options: Place in property, auction item, or quick-sell to pawn shop (instant cash).

Screen 4: Bank & Ads Rewarded Hub (/rewards)

Currency overview & Rewarded Ad triggers.

Screen 5: Profile & Settings (/settings)

User stats, Google Auth account management, language selector (Hebrew RTL / English LTR), audio/haptic toggles.

9. Data Schemas (Firestore JSON Structure)

/users/{uid}

{
  "uid": "goog_102938484920",
  "displayName": "TraderJoe",
  "email": "joe@example.com",
  "fcmToken": "eXamPle_Fcm_ToKen_String",
  "cashBalance": 45200.00,
  "diamondBalance": 120,
  "netWorth": 185000.00,
  "ownedPropertyIds": ["prop_studio_01", "prop_garage_04"]
}


/auctions/{auctionId}

{
  "auctionId": "auc_99823",
  "sellerUid": "goog_102938484920",
  "item": {
    "itemId": "item_speedboat_02",
    "name": "Supermarine Speedboat",
    "category": "Boats",
    "rarity": "Epic",
    "condition": 95
  },
  "auctionType": "DUTCH", // "ENGLISH", "DUTCH", "SEALED", "VICKREY"
  "startingPrice": 50000.00,
  "currentPrice": 38000.00,
  "reservePrice": 20000.00,
  "highestBidderUid": "goog_77665544332",
  "bidsCount": 12,
  "startTime": "2026-10-27T10:00:00Z",
  "endTime": "2026-10-27T18:00:00Z",
  "status": "ACTIVE" // "ACTIVE", "COMPLETED", "EXPIRED"
}


10. Implementation Roadmap for AI Coding Agent

Phase 1: Setup Flutter/React Native, Firebase App Initialization (Auth + Firestore + FCM) within Free Tier rules.

Phase 2: Implement Google Auth flow and persistent local cache for Firestore.

Phase 3: Build Auction Engine UI & Atomic Firestore Transaction logic for all 4 auction modes.

Phase 4: Build Map & Asset Inventory systems.

Phase 5: Integrate Google Mobile Ads SDK for Rewarded Video Ads.

Phase 6: Configure Firebase Cloud Messaging (FCM) for instant free outbid notifications and polish UI.