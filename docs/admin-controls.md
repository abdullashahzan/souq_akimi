# Administrator controls, welcome flow and launch messages

Open **Profile → Admin dashboard** using the verified administrator account.
The account remains `shahzan` / `abdullashahzan@gmail.com`; no new administrator
credentials or service-account keys are embedded in the app.

## Dashboard

- **Overview**: marketplace counts.
- **Content**: search loaded products/services, inspect photos/details, edit the
  title, description, SAR price and product stock, pause/resume, or delete.
  Deleting a listing cleans its photos without erasing transaction history.
- **Broadcast**: publish the complete message users see before entering the app.
  The live message can be loaded for editing, replaced or withdrawn. Publication
  creates a new revision and immutable announcement-history entry.
- **Users**: search by username, email or UID. Suspension requires a reason and
  blocks marketplace writes immediately through Firestore rules, then pauses
  their content. Restore access does **not** automatically republish content.
  Removal requires a reason and typing `DELETE`. It first writes a permanent
  restriction, then removes owned products, services, images, inbox and profile.
  Order/request history is retained. Interrupted cleanup can be retried from
  the removed user's retained restriction row; removal is not one large atomic
  deletion and is not described as such.
- **Controls**: maintenance pauses new listings, photo uploads, purchases and
  service requests. Existing orders/requests can still be managed. Users see a
  maintenance notice and may continue browsing. Admin controls remain available.
- **Activity**: inspect order and service-request records. Totals, delivery codes
  and historical transactions are deliberately not arbitrarily overwritten or
  deleted from the dashboard. Hand-over secrets remain buyer-only.

Users, content and activity initially load 200 records; **Load more** expands
the query. Search is over loaded records, not a full-text backend search. The
controls tab shows the most recent 50 immutable audit entries. Administrative
content edits, user restrictions, maintenance and publication/withdrawal are
logged. One suspension/removal can require many reads and writes; consider
Spark quotas before mass moderation. No paid infrastructure was enabled.

The admin UID and the currently authenticated administrator cannot be suspended
or removed via these rules. Profile-supplied email addresses do not grant admin
privileges or protection; the authorization boundary uses verified Auth tokens.
Ordinary users cannot clear restriction records or recreate a removed profile.
Guest/public catalogue access remains available. A restriction is per UID, not
a guarantee that a person cannot register a different account.

## Permanent Firebase Authentication deletion

**Marketplace removal is not Firebase Authentication account deletion.** A
Flutter client must never hold the Admin SDK credential needed to delete another
person's login. The Spark-only deployment has no trusted callable backend, so
this final step is a separate IAM-authorized operator tool, not a fake in-app
delete button. A future authenticated backend could safely connect the same
operation to the dashboard.

On a trusted operator machine, install `scripts/requirements-admin.txt` in a
virtual environment and configure Application Default Credentials for a narrowly
authorized project operator. Do not commit credentials or put them in Dart
defines. Review the exact project and UID:

```sh
python3 scripts/delete_auth_user.py --project souqakimi --uid TARGET_UID
```

This defaults to preview and requires a deleted restriction plus completed
marketplace cleanup. It refuses the known administrator UID/email and emulator
environment variables. To apply after reviewing the preview:

```sh
python3 scripts/delete_auth_user.py --project souqakimi --uid TARGET_UID \
  --apply --confirm-uid TARGET_UID
```

The tool revokes refresh tokens, deletes the login and appends an audit record.
The restriction tombstone is retained to block stale tokens. A retry handles an
already-absent Auth account. Order/request records may still contain contact
details from transactions; this feature is **not** a comprehensive privacy/data
erasure policy. The tool was not run against any real account during this work.

## First thing on app open

`appConfig/launchMessage` is public read/admin write, so it reaches guests and
future users as well as existing students without fan-out or a 1,000-user inbox
cap. It contains public information only—never put private user information in
an announcement. Existing transaction/request notifications continue unchanged.

- The full title/body covers the app until **Got it** is selected. Tabs, forms,
  deep links, existing modal routes and foreground inbox alerts sit underneath.
- **Show on every app open** is on by default. Cold starts and returns from
  background display it again. Ordinary rebuilds do not. A newly published
  revision also appears while the app is open.
- Turn that switch off for one acknowledgement per user on each device. Guest
  and account acknowledgements are separate. Republishing creates a new ID.
- Messages display before onboarding. Restricted accounts instead see their
  access status/reason and a sign-out action.
- Withdrawing stops display after the device receives the update. Delivery of
  new messages needs a connection; an offline client can only use cached state.
  This is not closed-app push, forced binary updates or guaranteed delivery.

## Onboarding

New guests/accounts get a four-step, English/Arabic welcome: campus discovery,
photo enlargement and SAR prices, COD/code-sharing safety, then services/inbox.
The language can change in place without opening a popup above the root router.
Back/Next controls work with reduced motion and phone/tablet layouts. Guests
finish locally; authenticated completion also persists on their profile as
`onboardingCompleted: true`, so it is recognized on another device. No sensitive
delivery information is required just to complete onboarding.

## Deployment and verification

Deploy `firestore.rules` before distributing the new client. Rules add
`userAccess`, `appConfig`, `announcements` and `adminAudit` protections, plus
the profile's onboarding flag. New orders are explicitly single-line, matching
the cartless app; seller restrictions, active state and demo protection cannot
be skipped with extra lines or a forged seller. Existing order/request records
and normal COD transitions are retained. Extra rule lookups can consume reads.

Tests live in `test/admin_startup_test.dart`, `rules-tests/escrow.test.js` and
`scripts/test_delete_auth_user.py`. Destructive user/content cases run in tests,
not against the ten requested live demo products or the existing admin account.
