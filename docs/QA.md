# Buyer, seller and administrator verification

Test device: Android tablet `HA220ZY7`. No Android emulator was used.
Automated layouts also cover 360px English and Arabic/RTL screens.

## GitHub public-release preparation — 2026-11-01

- Removed the ten known live demo products and ten corresponding images, the
  explicitly labelled QA announcement and both confirmed QA audit records.
  Timestamp preconditions and private before/after comparisons preserved all
  unrelated documents. The original admin profile/image remain; no real orders,
  requests or services were deleted. Seeders and bundled demo photos are gone.
- Published only username/sales count to `publicProfiles`. Private contact
  documents are now owner/admin-only; public seller widgets read safe profiles.
- Registered `com.souqakimi.app` Firebase platform apps and a dedicated Android
  release certificate for Google OAuth. Production builds require private
  signing credentials, disable shared-key AI and exclude demo assets.
- **164 Flutter tests, 64 rule tests and 8 Python safety tests passed**, with
  clean analysis. Rule regressions include stored/count-limited OTP guesses,
  transaction-bound stock movements, price/quantity checks, no free tally
  increments, profile privacy and previous admin/startup protections.
- The historical QA notes below describe earlier development builds, not the
  current release inventory or signing/credential posture. See
  [release guide](releases.md) for install instructions and iOS limitations.

## Administrator, welcome and launch-message follow-up

- Added searchable user access moderation with self/admin protection, required
  reasons and typed removal confirmation; content edits; maintenance controls;
  order/request inspection; and immutable recent audit entries.
- Marketplace removal retains order/request history and a permanent UID
  restriction. Firebase login deletion remains a separate trusted IAM operation
  (`scripts/delete_auth_user.py`), not an in-app Admin SDK credential.
- Full launch messages cover the root router before onboarding; publication,
  replacement, withdrawal, every-open/once-per-device policies, guest/new-user
  reach, account-scoped acknowledgements and background/resume are tested.
- Four-step English/Arabic onboarding persists locally and on authenticated
  profiles. Language controls also work above the root Navigator. Fixed form
  controller disposal to wait until dialog exit animations have completed.
- **165 Flutter tests**, **56 Firestore-rule tests**, **7 Python safety tests**
  passed; clean analysis. Rule tests cover ban/recreation/privilege-spoofing,
  maintenance, public-message authorization, immutable audit records and
  multi-line/forged-seller checkout bypasses. No destructive user-removal test
  was run against the existing administrator or ten live demo products.
- Deployed the updated Firestore rules. On `HA220ZY7`, completed the four-step
  welcome flow, switched English/Arabic, checked Back/Next, verified protected
  administrator actions, inspected the new tabs and opened/cancelled a content
  edit without saving. Published a clearly labelled temporary QA launch message:
  it covered the entire app, switched language, and reappeared after an actual
  background/resume and cold start. Withdrew it afterwards. Its immutable history
  and two publication/withdrawal audit entries are intentionally retained.
- Post-test live inventory: **10 products, 11 images, 1 profile, 0 services,
  orders or service requests**; no user restrictions or maintenance. All ten
  active demo titles/stock match the manifest and their photo bytes match bundled
  assets. The administrator remains `shahzan`; completing onboarding saved the
  profile's completion flag. The earlier temporary baseline was unavailable at
  final audit, so this check does not claim a full document-by-document comparison.
- Tablet testing also prompted an in-place localization dependency fix for
  tooltips and field decorations, plus Arabic service-request labels.
- Final 69.0 MB release APK rebuilt and installed on `HA220ZY7`; verified the
  in-place Arabic admin tooltip/activity labels, withdrawn announcement and
  English Browse with ten demos. No Flutter errors or Android crashes in the
  final-run logs. Source changes remain uncommitted/unpushed.

See [administrator guide](admin-controls.md) for operation and deployment limits.

## Motion and photo-viewer follow-up

- Bounded spring press/release feedback, rounded button morphing, sliding tab
  selection, fluid RTL-aware Android page entry and bouncy edge scrolling.
- Full-screen photo previews from cards, product/service galleries, listing
  form photos, checkout and administrator thumbnails. Listing text/navigation
  and photo-removal controls keep their existing actions.
- Pinch, double-tap-at-focal-point, zoom/reset, zoomed panning, six-photo paging,
  explicit previous/next controls and last-page restoration on close.
- Reduced-motion behavior, native Apple page/back gestures, keyboard Escape/
  arrows, Android back, readable dark viewer chrome and Arabic controls.
- Added 18 motion/photo tests; the full Flutter suite is now **148 tests**.
  The seeder's three offline safety tests remain unchanged. No Firestore rules,
  business workflows, credentials, demo stock or existing records were changed
  to implement these UI interactions.
- Built the release APK (68.2 MB) and installed it on `HA220ZY7`. Verified card
  photo enlargement above the tab shell, zoom/pan, double-tap reset, Android back,
  separate listing-title navigation, detail-gallery enlargement, tab navigation
  and Arabic viewer controls. Restored English Browse with all ten demos visible.
  Tablet logs contained no Flutter errors or Android crashes. Multi-photo paging
  and two-finger pinch are covered by widget tests without changing live photos.

## UI redesign follow-up — 2026-10-31

- Editorial Browse masthead, real photo collage, category shortcuts, inset
  product covers, calmer selling cards and a single scrolling Services page.
- Verified the English and Arabic/RTL redesign on `HA220ZY7`, including the
  category controls, service shortcut, selling choices and disabled demo buy bar.
- Added 15 regression tests: total Flutter suite **130 passed**, with clean
  analysis. Three offline seeder tests cover preview, collision refusal and
  atomic create-only writes. Existing Firestore rules were not changed.
- The live baseline at the start of this follow-up had **0 products, 0 services,
  1 image and 1 profile**. It differs from the historical baseline below; no
  attempt was made to recreate missing earlier documents.
- Created exactly **10 demo products and 10 matching image documents**. A
  private baseline comparison confirmed that the pre-existing profile and image
  contents were unchanged. No accounts, services, orders or requests were added.
- Demo items are visibly labelled and blocked from checkout by the updated
  client. Existing real listings default to `isDemo: false`; edits preserve the
  demo flag. This does not claim additional server-side transaction enforcement.
- A second seeding attempt safely refused without writes or overwriting the
  private backup. Samples remain in the catalogue as requested, not cleaned up
  like the earlier temporary buyer/seller test data.

See [design and sample-data notes](design.md) for photo sources and document IDs.

## Exercised flows

- Registered two temporary accounts using the app, one buyer and one seller.
- Seller published a temporary product and a temporary service.
- Buyer purchased the product with SAR cash-on-delivery, selected `br10`,
  supplied contact/room details, and revealed the six-digit hand-over code.
- Seller opened the sale, entered that code, completed delivery, and gained one
  completed-sale count. Order snapshots survived moderation of the listing.
- Created service requests authenticated as the buyer while the seller was
  browsing on the tablet. The seller immediately received a visible alert and
  Services badge. Tapping opened the exact request in Received.
- Seller accepted and declined requests on the tablet; the buyer received
  response alerts, which opened the correct Sent tab.
- Provider completed accepted work, the buyer received the completion alert,
  and the same service could be requested again. The buyer submitted a new
  request from the final tablet build and cancelled it; the provider's inbox
  contained the cancellation notification.
- Saved phone/building/room autofilled the next brief. Pausing the QA service
  while its buyer was drafting produced a clear error without closing the
  sheet or losing text. Resuming and retrying sent the original brief.
- The final release published a second temporary product with the seller's
  real username (not their email fallback), then saved price/quantity edits.
- The inbox kept its unread badge when opened, and **Mark all read** cleared it
  explicitly. Repeated snapshots did not replay dismissed alerts.
- Google sign-in returned to the existing verified administrator account.
- Admin inspected a product, paused/resumed it, searched listings, and deleted
  only the temporary QA product after confirmation.
- Admin sent a clearly labelled temporary announcement to the administrator and
  the two QA accounts; delivery and the live alert were verified.

## Fixes prompted by testing

- Visible field labels and hints: use complete text styles and persistent
  floating labels, instead of initially blank-looking forms.
- Bottom navigation no longer overlaps checkout, confirmation, management FABs,
  or delivery/request actions.
- Request and response alerts, per-request links, Services unread badges and
  accessible inbox buttons on Browse/Services.
- Explicit inbox read controls; opening the list no longer clears unread work.
- Request actions disable while submitting and confirm terminal actions.
- Failed request sends retain the brief in the sheet for retry.
- Accepted service work can be completed rather than blocking future requests
  for that service indefinitely.
- Real loaded profiles supply listing handles; fallback email-derived names
  cannot silently replace usernames during profile-stream startup.
- Gallery heights are bounded on tablets, empty listings have a single honest
  placeholder, related cards have enough height, and order confirmations scroll.
- Reversible admin moderation and detail inspection; moderation rows wrap on
  narrow English/Arabic screens.
- Gradle memory limits suit an 8 GB development machine.

## Automated checks

- `flutter analyze`: no issues.
- Flutter unit/widget tests: 115 passed.
- Firestore emulator tests: 43 passed, including request-response atomicity,
  completion, invalid transitions, spoofed notifications and unavailable services.

Foreground alerts are not closed-app push notifications. This remains a
documented deployment constraint of the current Spark-only setup.

Cleanup verified: temporary Auth accounts and all 23 remaining QA documents were
removed (the first QA product had already been removed through admin moderation).
All six pre-existing document paths remain: the original product, service,
three photos and administrator profile. The verified administrator Auth account
remains signed in on the tablet. No launch-data wipe was performed.
