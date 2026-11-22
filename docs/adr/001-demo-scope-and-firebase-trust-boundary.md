# ADR 001: Demo scope and Firebase trust boundary

- **Status:** Proposed for the first Firebase-connected milestone
- **Date:** 2026-11-22
- **Decision owner:** Project owner

## Decision

The first Firebase-connected milestone is a **read-only demo/data preview**, not a competitive multiplayer economy. Auction bidding, listing, settlement, inventory transfers, rent grants, and rewarded-ad currency remain local demo interactions and reset with the local game session. Firebase data is not authoritative for balances, ownership, auction outcomes, or rewards.

This is a proposed implementation default, not evidence that the product owner has approved a permanent product direction. The owner must explicitly accept this scope before connecting a real Firebase project. If competitive multiplayer is the intended first release, stop before Firebase integration and approve a trusted server execution path and its operating budget first.

## Trust boundary and writers

| Data | Visibility | Authoritative writer | First-milestone client access |
| --- | --- | --- | --- |
| Public auction preview | Signed-in users | Project operator / trusted import process | Read only; excludes bids, bidder IDs, seller-private data, and settlement fields |
| Player profile | Owner only | Trusted provisioning process | Read own projection only; no client writes |
| Balance, reserved funds, inventory ownership, property ownership, bids, results, reward ledger | Private | No Firebase writer in demo scope; trusted backend required for competitive scope | No client reads or writes in this milestone |
| Avatar objects | Owner only | Not in this slice | Denied until separately specified |

Authentication proves account identity; it does not make client-provided values trustworthy. Firestore rules cannot calculate or secure competitive economic invariants from modified clients. Firebase Auth, Analytics, Remote Config, FCM delivery, or App Check do not change that boundary.

## Minimal read-only contract v1

All timestamps are Firestore timestamps. IDs are document IDs and must match the `id` field if one is included. Unknown fields are rejected by validation at ingestion; clients treat unknown fields as forward-compatible and never infer authority from them.

### `publicAuctions/{auctionId}`

```json
{
  "schemaVersion": 1,
  "status": "active",
  "auctionType": "english",
  "item": {
    "name": "Vintage Chair",
    "category": "furniture",
    "rarity": "common",
    "iconPath": "builtin:game-item/vintage-chair"
  },
  "startingPrice": 100,
  "displayPrice": 100,
  "startTime": "Firestore Timestamp",
  "endTime": "Firestore Timestamp"
}
```

The public projection intentionally omits seller identity, bidder identity, bid amounts/history, reserve price, private item metadata, balances, and outcome/settlement fields. Add fields only after a product/privacy review. The preview is informational and is not a place to submit bids.

### `users/{uid}/profile/summary`

```json
{
  "schemaVersion": 1,
  "displayName": "TraderJoe",
  "avatarUrl": "https://example.invalid/avatar",
  "createdAt": "Firestore Timestamp"
}
```

This document is readable only by its owner. It has no email, FCM token, cash, diamonds, net worth, inventory, or ownership fields. First-milestone rules deny client writes; seed it through a trusted/admin process. If client profile creation is later needed, define a separate allowlist and threat review.

## Firebase setup gate

Do not connect credentials or deploy rules until all are true:

1. The owner accepts the demo/read-only product promise, or separately approves competitive scope with trusted execution and budget.
2. A non-production Firebase project is selected and separated from any production project.
3. The public/private projections and allowed query patterns above are reviewed against actual screens.
4. Firestore rules tests prove public reads expose only the public projection, owners can read only their profile, and every client write is denied.
5. The Firebase plan, expected reads/storage/egress, App Check needs, retention, and operations ownership are checked against current provider terms and the project budget.

## Go/no-go

- **GO for the read-only slice:** only after gates 1-5 pass. Integrate a dedicated repository for `publicAuctions` and the owner profile projection; do not reuse local `GameState` balances or mutation methods as Firebase data.
- **NO-GO for competitive economy:** while the only mutation authority is a client. Reopen this ADR when an approved trusted command API supports authenticated, idempotent bids/listings/settlement/rewards and private sealed bids, with tested authorization and operational budget.
- **NO-GO for production deployment:** this ADR and the current repository rules are not a deployment approval. Select and verify the target project explicitly.

## Consequences and migration notes

- The current app's Firebase repositories use `/users`, `/properties`, `/assets`, and `/auctions`; their model documents do not match this projection contract. Do not connect those repositories under the rules below. Implement an explicit read-only adapter and UI state before integration.
- Existing fixed starter content and initial profile balances are not part of this contract. Current `firestore.rules` had client create exceptions for these records; this ADR removes those exceptions in favor of an entirely read-only first Firebase milestone.
- The existing PRD still promises competitive auctions, four auction types, rewards, and Spark-only client-side validation. That promise remains unresolved and conflicts with this ADR. Owner approval or a PRD revision is required before release planning.
- A migration to competitive play requires new server-owned write models and a migration plan. Do not silently promote demo values into authoritative state.
