# Souq Akimi · سوق أكيمي

The campus marketplace for Akimi hostel: buy and sell items, offer services, and
get everything delivered to your room. Flutter (iOS + Android) on Firebase
(Auth + Firestore). **Cash on delivery only** — the app never touches a card, a
wallet or a payment provider.

## Download

**[Download the Android APK from GitHub Releases](https://github.com/abdullashahzan/souq_akimi/releases/latest)**

Install only `Souq-Akimi-Android.apk` from this repository. Compare its SHA-256
with `SHA256SUMS.txt`, open it and approve Android's per-browser install permission.
Updates are downloaded manually from the same Releases page. No store submission.

The public package is `com.souqakimi.app`, signed with a dedicated release key.
Development installs (`com.example.souq_akimi`) are separate apps: install the
public app and sign in again; your Firebase account and real data remain the same.

**iPhone/iPad:** no installable iOS binary is included. The attempted macOS build
found a native dependency conflict; Apple signing would also be required.
GitHub downloads cannot bypass that. See [iOS limits](docs/releases.md#ios).

The live demo catalogue and developer seeders are removed. An empty catalogue is
intentional until users publish real listings. Automated tests stay in git, not
in the APK. See [design notes](docs/design.md).

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
| **Services** | Requests (accept / decline / cancel / complete), saved building/room/mobile details, live inbox alerts and two-way status notifications |
| **Account** | Email/password and Google sign-in, profile, delivery defaults, completed-sales tally, order + sale history, sign out |
| **Languages** | Persisted English/Arabic switch, Arabic RTL layout and Cairo typography |
| **Motion & photos** | Springy press feedback, fluid page/tab transitions, bouncy scrolling, full-screen photo previews with pinch/double-tap zoom and six-photo paging; reduced-motion support |
| **Owner controls & welcome** | User suspension/removal, content editing/moderation, maintenance controls, activity/audit inspection, first-run onboarding and full launch announcements; see [admin guide](docs/admin-controls.md) for the Auth-deletion boundary |
| **Drafting** | Manual forms; shared-key AI is intentionally disabled/hidden in public releases |
| **Admin** | Verified-email dashboard, inspect/pause/resume/remove listings, and confirmed in-app broadcasts |

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
5. **Delivery complete.** Each guess consumes an attempt before comparison with
   buyer-only `deliverySecrets`. A modified client cannot bypass the five-guess
   limit; the buyer can rotate the code and reset attempts.
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
- **Attempt limit** — a stored guess consumes an attempt before comparison;
  changing a guess without incrementing the counter is rejected.
- **Ownership** — only the buyer cancels or rotates codes; only participants can
  operate a delivery. The administrator can inspect order/request records;
  inboxes are private to their owner and administrator.
- **Stock counters** — buyer movements require `lastOrderId` proving a new order
  or one-time cancellation in the same transaction. Prices, quantities,
  delivery/secret/notification siblings and summary status are checked.
- **Profile privacy** — contact profiles are owner/admin-only; `publicProfiles`
  contains only usernames and completed-sale counts. Tally increments require a
  newly completed delivery, rather than trusting client increments.
- **Image budget** — listing photos stored in Firestore are capped at 640 KB.
- **Owner moderation** — verified-admin-only restrictions, protected admin UID,
  immutable audit/history entries, public startup announcements and maintenance
  controls. Restricted accounts cannot recreate removed profiles or bypass the
  cartless checkout's seller/demo/active-listing checks.

`rules-tests/` exercises the security rules against the Firestore emulator.

### Request notifications

- Creating a service request also writes the provider's private inbox entry in
  the same transaction. New entries trigger an immediate tappable in-app alert
  while the app is open, an unread Services badge, and a bell badge.
- Accepting, declining, completing, or cancelling a request atomically notifies
  the other student. Alert taps open the right Sent/Received tab and put that
  specific request first. Read state is separate from dismissing an alert.
- Opening the inbox no longer marks everything read. Open an entry or use
  **Mark all read** explicitly. Alerts are locally deduplicated per account.
- Providers can finish accepted requests using **Mark completed**, allowing a
  later request for the same service. Terminal requests cannot be replayed or
  changed; rules reject forged actors/recipients and unavailable services.
- **Delivery limit:** this Spark-only architecture has no trusted push sender.
  These are foreground alerts and a persistent inbox, not Android/iOS push when
  the app is closed. Reopening loads unread updates. Reliable background push
  requires FCM/APNs plus an authenticated server/worker; never embed service
  account credentials in the client.

See [buyer/seller/admin verification](docs/QA.md) for the latest exercised flows.

The release closes the old standalone stock/tally and profile-access boundaries.
This is still a Spark-only community app: no guaranteed background push,
server-side abuse throttling or automatic updates. Public availability does not
mean store certification or unlimited Firebase quotas.

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
# Optional debug-only AI key. Never publish a keyed development build.
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
`GROQ_API_KEY` is accepted in debug builds only. Releases hard-disable shared-key
AI and hide its controls, even if a define is supplied accidentally. Public AI
needs a separately approved authenticated/rate-limited backend; GitHub Releases
cannot keep an API key secret or serve as that backend.

The previous `gpt-oss-120b` configuration used a 180–280 token budget, which
could be exhausted by reasoning before any visible answer was returned. The
current model was tested with Arabic/English text and JSON responses and uses
a 512-token output budget. Empty, malformed and truncated responses are rejected
without replacing the student's existing text. Network failures, timeouts,
credentials and rate limits have user-facing errors.

Generated drafts can still contain inaccurate claims or awkward wording. Always
review descriptions, tags and announcements before publishing them.

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
python3 scripts/build_release.py
adb -s YOUR_ANDROID_SERIAL install -r build/app/outputs/flutter-apk/app-release.apk
```

Use JDK 17. Release builds require external signing credentials and never fall
back to debug signing. The release SHA-1 is registered in Firebase/Google OAuth.
No signing key or Groq credential is included. See [release guide](docs/releases.md).

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
