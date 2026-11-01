# Campus editorial refresh

- Warm paper surfaces, evergreen masthead, soft mint/ochre/lilac category tiles.
- Responsive decorative icon collage on tablets; compact masthead on phones.
- Working discovery categories, service shortcut, and clear no-results reset.
- Inset product photography, quieter shadows, directional badges and real seller handles.
- Services scroll as a single page; selling uses calmer white action cards and a simple three-step guide.
- All new interface copy is translated into Arabic and respects RTL.

## Public release

All illustrative listings and their sample-photo assets were removed before
GitHub distribution. The masthead uses decorative Material icons, not pretend
inventory. Users' actual listing photos still use the normal Firestore image
mechanism. Developer seeding controls and scripts are absent. Regression tests
use isolated synthetic fixtures and a one-pixel image, never live demo records.

## Fluid motion and photo viewing

- `lib/core/motion.dart` supplies a damped, bounded squash-and-release spring.
  Cards, discovery controls and navigation transform without changing layout or
  tap-target size. A drag cancels press feedback rather than shrinking a card for
  the whole scroll. There are no perpetual decorative animation loops.
- Material button labels/icons respond to pressed state, including keyboard
  activation, without replacing native button actions or disabled semantics.
  Filled/outlined surfaces soften their corners while pressed.
- Android/desktop pages fade, lift and settle with a small spring. iOS/macOS keep
  Cupertino transitions and their native back-swipe gesture. The floating tab
  selection slides between destinations; icons softly change in place.
- Scrolling has bounded, bouncy edge physics. Custom spring, page, gallery-dot,
  entrance and zoom animations respect the platform's reduced-motion setting.
- `ListingGallery`, `PhotoPreview` and `PhotoViewer` share one enlargement flow
  across product/service cards, detail galleries, form photos, admin thumbnails
  and checkout. Tapping a photo opens a root-navigator full-screen viewer; tapping
  a card's text/details continues to open the listing.
- Viewer images use `BoxFit.contain`, support pinch/pan up to 4×, double-tap at
  the chosen focal point to 3×, and have an accessible zoom/reset button.
  Unzoomed images page horizontally. Zoomed images pan instead of accidentally
  changing photos. Explicit previous/next buttons work even while zoomed.
- Closing restores the gallery's last viewed page. Close, Android back, Escape
  and keyboard arrow controls work. Labels and directionality support Arabic.
  Photo deletion controls stay independent; empty placeholders do not open a
  fake viewer. No new package, backend service or database migration is needed.

`test/motion_photo_test.dart` covers spring settling, drag cancellation,
single-fire/disabled button actions, reduced motion, RTL page entry, full-screen
enlargement, double-tap/pinch/pan, gallery paging and restoration, card navigation,
photo removal and phone-sized English/Arabic controls.
