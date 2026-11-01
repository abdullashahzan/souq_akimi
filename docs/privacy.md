# Souq Akimi privacy and contact

Contact **abdullashahzan@gmail.com** for privacy, account removal, unsafe
users/listings or support. Never send a password, delivery code or API key.

## Data used

- Firebase Authentication handles email/password and optional Google login.
- Your username and sales count are visible with listings. Under the release
  rules, private profile email, mobile number, building and room are readable
  only by your account and the marketplace administrator.
- Orders share entered contact/delivery details with the seller for fulfillment.
  Service requests share their contact information with the provider.
  Order/request history and inbox messages are stored in Firestore.
- Listing text/photos are public. Never upload private documents, identity
  cards, another person's contact details, or content you cannot share. Selected
  photos are resized/JPEG-encoded on-device and stored in Firestore. Camera and
  library permissions are used for selecting listing photos.
- Device preferences remember language, onboarding and announcement/inbox
  acknowledgements. Android cloud backup is disabled in the public release.
- Public builds have no shared Groq key or AI drafting and send no form content
  to Groq. There is no advertising SDK, card processing or in-app payment flow.

Firebase is provided by Google and subject to Google's processing terms/privacy
policies. Fresh data requires a connection. Cached data can remain on a device;
sign out and clear app storage before giving a shared device to another person.

## Removal and retention

Email the administrator from your account email to request account/profile/
listing removal. The administrator can block access and remove your marketplace
profile, public profile, owned listings/photos and inbox. Firebase login deletion
is a separate trusted administrator operation. Ownership verification may be
needed, but never provide your password.

Order and service-request snapshots may contain historical contacts and are
retained for fulfillment/disputes. The app does not automatically erase every
historical record. Ask specifically about retained records. Minimal UID
restrictions/moderation audits may be retained to enforce bans and record
administrative actions. Instant comprehensive erasure is not promised.

## Reporting and safety

Report abusive content/unsafe users privately by email with the listing/user
identifier; GitHub Issues are for non-private bugs only. Do not share a hand-over
code until receiving your item. Pay the seller directly at delivery. The app
holds no money, offers no escrow, and cannot guarantee a seller's claims.
