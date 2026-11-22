# Firebase read-only rules baseline

The current milestone contract is documented in [ADR 001](adr/001-demo-scope-and-firebase-trust-boundary.md). Firestore rules allow signed-in reads only from the public auction preview projection and owner-only reads from a minimal profile summary. Every client write is denied, including profile creation, starter grants, inventory changes, bids, balances, rewards, and auction settlement. Other collections and paths are denied by default. Storage access is also denied for this milestone.

These rules are intentionally incompatible with the existing Firebase adapters. Those adapters read and write `/users`, `/properties`, `/assets`, and `/auctions`, and some expose balances or attempt client-side mutations. Do not enable `FIREBASE_ENABLED=true` against a project using this rules baseline until a dedicated read-only adapter uses only `/publicAuctions` and `/users/{uid}/profile/summary`. The demo game state remains local.

The `publicAuctions` path must contain only the public projection fields defined in ADR 001. Firestore rules cannot remove private fields from a document, so never place private or economic fields in a document readable by all signed-in users. Populate documents only through trusted/admin tooling. User profile summaries are also provisioned outside the client.

## Validation and deployment

No Firebase project is selected or deployed. This checkout has no `firebase.json` emulator configuration. Before any connection or deployment, add Emulator Suite configuration and tests proving:

- unauthenticated reads fail;
- signed-in users can query public auction previews;
- signed-in users can read their own summary but not another user's summary;
- all client writes fail, including writes under legacy `/auctions`, `/users`, `/properties`, and `/assets` paths;
- all Storage reads and writes fail.

Rules have not been emulator-validated, and deployment is not authorized by this document. Select a non-production project explicitly, run the rules tests against the Firebase Emulator Suite, review the contract and expected queries, then obtain project-owner approval before deployment. Do not deploy this baseline to production based only on its presence in source control.

References: [Firestore rules and queries](https://firebase.google.com/docs/firestore/security/rules-query), [Firestore rules unit testing](https://firebase.google.com/docs/rules/unit-tests), [Storage security rules](https://firebase.google.com/docs/storage/security).
