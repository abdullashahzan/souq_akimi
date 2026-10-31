# Buyer, seller and administrator verification

Test device: Android tablet `HA220ZY7`. No Android emulator was used.
Automated layouts also cover 360px English and Arabic/RTL screens.

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
