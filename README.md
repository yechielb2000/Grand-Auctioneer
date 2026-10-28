# Auction Empire

A Flutter mobile game prototype for the Auction Empire app spec. It includes a dark-luxury interface and interactive demo flows for the world map, auctions, inventory, rewards, and player profile.

## Run locally

Install the Flutter SDK. Generate the native Android and iOS runner projects once, then run:

```sh
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

The default build uses seeded in-memory demo data, so it can be explored without accounts, network access, or platform-specific credentials. Restarting the app resets the demo state.

Run the game-state and model tests with `flutter test`.

## Firebase and Google integration

Firebase adapters are in place for Google Authentication, Firestore, FCM, Storage, Remote Config, Analytics, and Google Mobile Ads. Firebase remains opt-in so the demo works without project credentials. When enabled, Google sign-in creates a starter Firestore profile transactionally, FCM permission is requested after sign-in, Remote Config controls the auction anti-sniping extension and reward limit, and Analytics records screen views. Core models and repository interfaces live under `lib/core/` and `lib/features/`; Firebase adapters are under `lib/services/firebase/`.

To connect a Firebase project:

1. Create a Firebase project and register the Android/iOS applications.
2. Generate native projects if needed with `flutter create --platforms=android,ios .`; add the platform configuration files and required Google Sign-In SHA fingerprints.
3. Enable Google Authentication and configure Firestore, Messaging, Storage, Analytics, and Remote Config in Firebase.
4. Run `flutter pub get`, then start with `flutter run --dart-define=FIREBASE_ENABLED=true`.

The app initializes Firebase from the native Android/iOS configuration. Firestore offline persistence is enabled. Collections used by the adapters are `users`, `properties`, `assets`, and `auctions`. Remote Config keys are `auction_extension_seconds` (1–120, default 15) and `daily_reward_limit` (0–20, default 5).

To enable rewarded ads, configure the Google Mobile Ads app ID in the Android/iOS runner projects and provide a platform-specific rewarded ad unit ID:

```sh
flutter run \
  --dart-define=FIREBASE_ENABLED=true \
  --dart-define=ADS_ENABLED=true \
  --dart-define=REWARDED_AD_UNIT_ID=your-platform-rewarded-ad-unit
```

Use Google test ad units during development. Do not put credentials or production ad IDs in source control.

## Important limitations

- The map now opens an interactive starter-shed grid with separate furniture and vehicle slots. Demo bids, listings, balances, inventory, and reward counts remain local state; they are not hydrated from Firestore. The seeded opposing sealed bids are demo data, not other connected players.
- Firestore transaction checks reduce accidental races, but client code cannot secure balances or ownership against a modified client. A strictly Spark-only design cannot provide cheat-resistant competitive settlement. Do not use this client-only economy for valuable purchases or real-money rewards.
- The remote repository deliberately rejects Blind and Vickrey bids; publishing highest-bid fields for sealed auctions would reveal private bids, and correct winner settlement needs a trusted design.
- Foreground FCM messages with `data.type=outbid` are shown in the app. Sending outbid messages to other users still requires a trusted sender, which is not included. Do not send FCM credentials from the client.
- Rewarded ad callbacks are checked before changing the demo balance, but the balance change is still in memory and client-controlled. This is not a production reward-verification mechanism.
- `daily_reward_limit` caps demo-session ad claims; claims are not persisted across restarts or enforced by a trusted server.
- Set restrictive Firestore and Storage Security Rules before connecting a Firebase project. Never allow clients to freely update `cashBalance`, `gems`, ownership, auction results, or reward claims. Firebase quotas and Spark-plan availability can change; verify current Firebase terms and usage limits for the project.

The repository intentionally contains no Firebase credentials, native runner configuration, Firestore/Storage rules, or production AdMob identifiers.

## UI assets and design tokens

The dark-luxury palette is centralized in `lib/app/theme/app_colors.dart`. Original SVG currency, auction, category, and navigation icons are bundled under `assets/icons/`, registered in `lib/app/assets/app_assets.dart`, and rendered with `flutter_svg`.

The map uses original in-app isometric property illustrations, and inventory/auction cards reuse the bundled category SVGs. Item placement and Dutch price changes animate; auction wins use an animated gavel/confetti celebration, with haptic feedback for wins, bids, sales, and rewards. Dedicated item sprites, audio effects, and font files are not included yet; add licensed or original files in their corresponding `assets/images/`, `assets/sounds/`, and `assets/fonts/` directories before referencing them in the app.
