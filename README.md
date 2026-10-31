# Souq Akimi · سوق أكيمي

The campus marketplace for Akimi hostel: buy and sell items, offer services, and
get everything delivered to your room. Flutter (iOS + Android) on Firebase
(Auth + Firestore). **Cash on delivery only** — the app never touches a card, a
wallet or a payment provider.

---

## What a student can do

| Area | What works |
| --- | --- |
| **Browse** | Newest active listings, search with synonyms + typo tolerance, category/condition/price filters, sort |
| **Buy** | Cartless *Buy now* → checkout → cash on delivery, delivered to your hostel room |
| **Hand-over** | A 6-digit code proves delivery. The seller types it in when the item is in the buyer's hands; only then is the order complete |
| **Sell** | Choose a product or service; attach up to 6 photos; edit and deactivate listings |
| **Notifications** | A purchase writes an in-app notification into the seller's inbox and raises a badge on the Orders tab — no push service, no server |
| **Remembered details** | Name, phone, building and room are saved after the first order and prefilled next time |
| **Services** | Campus services with requests (accept / decline / cancel), saved building/room/mobile details and provider inbox notifications |
| **Account** | Email/password and Google sign-in, profile, delivery defaults, completed-sales tally, order + sale history, sign out |
| **Languages** | Persisted English/Arabic switch, Arabic RTL layout and Cairo typography |
| **AI helpers** | Groq drafts product/service descriptions, search tags, service briefs and admin announcements |
| **Admin** | Verified-email administrator dashboard, listing moderation and in-app broadcasts |

Every screen inside the app keeps the bottom navigation bar visible, and every
screen has a working back control — including tab roots, where it falls back to
Browse.

---

## How an order works

1. **Buyer taps Buy now.** Checkout prefills whatever the profile remembers.
2. **One transaction creates everything** (`OrderRepository.placeOrder`):
   - the `orders/{SQ-XXXXXX}` document,
   - one delivery leg per seller,
   - the buyer-only hand-over secret for each leg,
   - a `new_sale` notification in each seller's inbox,
   - the stock decrement on every product.
   If any part is refused, nothing is written — there is no half-order.
3. **The seller sees the badge** on the Orders tab (and in Profile → Notifications).
4. **The seller delivers to the room on the order**, collects the cash, asks the
   buyer for their 6-digit code and types it into *My sales*.
5. **Delivery complete.** The rules compare the typed code with
   `deliverySecrets`, a document **the seller cannot read**. Five wrong guesses
   lock the seller out; the buyer can mint a new code.
6. **Cancelling.** Before delivery the buyer can cancel: every leg is cancelled
   and the stock goes back on sale. After delivery there is nothing to refund —
   cash already changed hands in person.

No money is held by the app, so there is no escrow, no refunds and no automatic
release timers.

---

## Security model (Spark plan, no Cloud Functions)

This project runs on Firebase's **Spark (free)** plan, which cannot deploy Cloud
Functions. The client therefore performs each transition as a Firestore
transaction, and `firestore.rules` is the trust layer. The rules enforce:

- **Order integrity** — order, deliveries, secrets, seller notifications and
  stock must all move in the *same* transaction (`getAfter()` on siblings).
- **Proof of delivery** — a seller may only flip a delivery to `delivered` by
  sending the code that matches the unreadable `deliverySecrets` document.
- **Attempt limit** — a failed guess commits nothing; the counter may only
  increase by one, to a maximum of five.
- **Ownership** — only the buyer cancels or rotates codes; only participants can
  read an order; inboxes are private to their owner.
- **Stock counters** — a stranger may only move `stock` + `soldCount` together
  (bounded to 999), so they can never reprice, deactivate or delete a listing.
- **Image budget** — listing photos stored in Firestore are capped at 640 KB.

`rules-tests/` exercises the security rules against the Firestore emulator (36 tests).

Known limitation: Firestore rules cannot see *which* order a stock write belongs
to, so any signed-in user can nudge a listing's `stock`/`soldCount` within the
bounded rule. Closing that completely needs server-side writes (Blaze) or App
Check. See `docs/firestore_schema.md` for the full threat model.

---

## Project layout

```
lib/
├── main.dart                 # boot, error guards, Firebase init
├── app.dart                  # MaterialApp, theme, root messenger
├── router.dart               # every route lives inside the AppShell
├── core/                     # config, theme, motion, formatting, feedback
├── models/                   # Firestore documents
├── data/
│   ├── order_math.dart       # money, ids, OTP, status derivation (unit-tested)
│   ├── collections.dart
│   ├── search/               # query parsing, synonyms, typo tolerance
│   └── repositories/         # auth, user, product, service, order, notification, images
├── providers/                # Riverpod wiring
├── features/
│   ├── shell/                # bottom navigation
│   ├── browse/ product/ services/ checkout/ orders/ notifications/ profile/
│   └── auth/
└── widgets/                  # shared cards, chips, images, empty/error states
firestore.rules               # the trust layer
firestore.indexes.json
rules-tests/                  # emulator tests for the rules
test/                         # Dart unit + widget tests
docs/firestore_schema.md      # data model + threat model
```

---

## Running it

```bash
flutter pub get
cp dart_defines.example.json dart_defines.json
# Edit dart_defines.json locally with your Groq key; never commit it.
flutter run --dart-define-from-file=dart_defines.json
```

Firebase is already wired for project **souqakimi**:
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`,
`lib/firebase_options.dart`, and `firebase.json`.

Deploy rules and indexes after changing them:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

The app targets the Spark plan: **no Cloud Storage and no Cloud Functions**.
Photos are resized on-device and stored as base64 in the `images` collection.

### AI configuration

The app calls Groq's OpenAI-compatible API using `qwen/qwen3.8-27b`.
`GROQ_API_KEY` is read only from a build-time define. A checkout without a key
still runs, but AI actions report that they are not configured.

The previous `gpt-oss-120b` configuration used a 180–280 token budget, which
could be exhausted by reasoning before any visible answer was returned. The
current model was tested with Arabic/English text and JSON responses and uses
a 512-token output budget. Empty, malformed and truncated responses are rejected
without replacing the student's existing text. Network failures, timeouts,
credentials and rate limits have user-facing errors.

**Security:** keys compiled into an APK are extractable, even when supplied with
`--dart-define`. Do not commit `dart_defines.json` or publish keyed APKs as public
GitHub release assets. Use a restricted, monitored key and move requests behind
an authenticated proxy before broader deployment. No API key, admin password,
OAuth client secret or signing keystore belongs in this repository. Firebase
client configuration and OAuth client IDs are public identifiers; deployed
Firestore rules enforce access.

The Android/iOS launcher name remains **Souq Akimi**. Inside the UI the name is
localized to **سوق أكيمي** in Arabic. The old app-name subtitles were removed.

---

## Testing

```bash
flutter analyze                                # static analysis
flutter test                                   # unit + widget tests
dart format --set-exit-if-changed lib test     # formatting gate

cd rules-tests && npm test                     # Firestore rules on the emulator
```

Build and install a release APK:

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Use JDK 17 for the Android build. Release currently uses debug signing; configure
a private upload keystore and register its SHA-1 in Firebase/Google OAuth before
publishing to an app store. This repository does not include a signing key.

### Manual check-list

- Sign up → profile appears; sign out → sign in again.
- Browse → search a typo (`lmp`) → result corrects itself.
- Open a listing → Buy now → checkout prefilled after the first order.
- Place an order → confirmation → order shows **cash on delivery** and the
  **hand-over code**.
- On the seller account: Orders badge → notification → sale → wrong code →
  correct code.
- Cancel another order before delivery → stock is back.
- Every tab and every detail screen keeps the bottom bar; back works.

---

## Free-tier reality (important)

Spark gives **50,000 reads and 20,000 writes per day**.

The app is deliberately frugal:

| Action | Approx. cost |
| --- | --- |
| Cold start on Browse | ~120 reads (60 products + 60 services, cached offline afterwards) |
| Opening Search | up to 600 reads, only on demand |
| Placing an order | ~3 reads + 5 writes (order, delivery, secret, notification, stock) |
| Completing a delivery | ~5 reads + 2 writes |
| Seller inbox | up to 50 reads, only when opened |

**1,000 registered users is fine. 1,000 daily active users will not fit on
Spark.** At ~120 reads per cold session, the 50k daily read allowance covers
roughly **400 fresh sessions/day** (far more with Firestore's offline cache on
repeat opens), and that ignores search and orders. If the app is going to be
used by hundreds of students every day, plan to move to the Blaze plan (or a
backend such as Supabase) for real headroom. The free plan is a good fit for a
campus launch, not for a high-traffic marketplace.

There is no push notification service: sellers see new orders when they open the
app. That is a deliberate Spark-plan choice.

---

## Data model

Full detail in [`docs/firestore_schema.md`](docs/firestore_schema.md).

```
users/{uid}
  ├── notifications/{id}          # private inbox (sales, service requests, broadcasts)
products/{id}
services/{id}
serviceRequests/{id}
orders/{SQ-XXXXXX}
  ├── deliveries/{id}             # one leg per seller
  └── deliverySecrets/{id}        # buyer-only 6-digit code
images/{id}                       # base64 listing photos
```

Every order is cash on delivery and always delivered to the buyer's hostel room;
there is no pickup option and no payment-method field.

---

## Resetting the marketplace

For a clean launch (or after testing), remove test listings, orders, requests,
images, notifications and test accounts. Preserve the administrator Auth account
and profile if the admin dashboard needs to remain available. This is
**destructive** — there is no undo. Never run cleanup against a live project
without explicitly confirming the target and scope.

```bash
# Example FULL wipe, including the admin profile: do not run for an admin-only reset.
firebase firestore:delete --all-collections --recursive --force --project souqakimi
```

Test Auth users can be removed from the Firebase console (Authentication → Users)
or through the Identity Toolkit Admin API. Keep the administrator unless a full
account reset was explicitly requested. Restart the app afterwards to refresh
cached lists.

---

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `The query requires an index` | Deploy `firestore.indexes.json`; the console link builds it too |
| `permission-denied` on checkout | Rules out of date — deploy them, then retry |
| Rules test fails with a missing module | `cd rules-tests && npm install` first |
| Photos fail to upload | Check the image is under 640 KB after resizing; the rules cap it |
| Product details scroll but nav bar vanished | A route was added outside the shell — put it inside `ShellRoute` in `router.dart` |
| Nothing happens on Sign out | Sign out clears the session and routes to `/login`; check `sessionProvider` |
| AI is not configured | Supply `GROQ_API_KEY` via the ignored build file and rebuild; check that the key is still valid |
| AI is busy | Groq returned a rate limit; wait and retry, or check the project's Groq quota |
| AI could not write that | Empty/truncated/upstream response; retry and check the configured model and debug diagnostics |
