/// Campus-wide constants, mirroring the Django project's `settings.py`
/// (currency, hostel buildings, hand-over rules) and `Service.CATEGORY_CHOICES`.
///
/// Everything tunable in one place so the UI never hard-codes a building name
/// or an attempt limit.
class AppConfig {
  const AppConfig._();

  // --- Branding -----------------------------------------------------------
  /// The name shown inside the app. The Android launcher keeps the original
  /// English name (see `android/app/src/main/res/values/strings.xml`).
  static const String appName = 'سوق أكيمي';
  static const String appNameEnglish = 'Souq Akimi';

  // --- Money --------------------------------------------------------------
  static const String currencySymbol = 'SAR';
  static const String currencyCode = 'SAR';
  static const String currencySymbolArabic = 'ر.س';

  // --- Campus delivery -----------------------------------------------------
  /// Where a buyer can have an order delivered. Mirrors
  /// `HOSTEL_BUILDINGS` in settings.py (`Br 1` … `Br 10`).
  static const List<CampusBuilding> hostelBuildings = [
    CampusBuilding('br1', 'Burj Ashra', 'برج عشرة'),
    CampusBuilding('br2', 'Burj 2', 'برج 2'),
    CampusBuilding('br3', 'Burj 3', 'برج 3'),
    CampusBuilding('br4', 'Burj 4', 'برج 4'),
    CampusBuilding('br5', 'Burj 5', 'برج 5'),
    CampusBuilding('br6', 'Burj 6', 'برج 6'),
    CampusBuilding('br7', 'Burj 7', 'برج 7'),
    CampusBuilding('br8', 'Burj 8', 'برج 8'),
    CampusBuilding('br9', 'Burj 9', 'برج 9'),
    CampusBuilding('br10', 'Burj Wahid', 'برج واحد'),
  ];

  /// Resolve whatever is stored on a profile ('Br 3', 'br3', 'burj 3') to a
  /// building. Unknown values are kept as a code-only entry so old profiles
  /// never lose information.
  static CampusBuilding buildingFor(String raw) {
    final cleaned = raw.trim().toLowerCase().replaceAll(' ', '');
    for (final building in hostelBuildings) {
      if (cleaned == building.code) return building;
    }
    final digits = RegExp(r'(\d+)').firstMatch(cleaned)?.group(1);
    if (digits != null) {
      for (final building in hostelBuildings) {
        if (building.code == 'br$digits') return building;
      }
    }
    return CampusBuilding(raw.trim(), raw.trim(), raw.trim());
  }

  // --- Hand-over code -----------------------------------------------------
  /// `DELIVERY_OTP_MAX_ATTEMPTS` — wrong guesses before the seller is locked
  /// out until the buyer rotates the code.
  static const int otpMaxAttempts = 5;

  // --- Catalogue ----------------------------------------------------------
  /// `PRODUCTS_PER_PAGE` / `SERVICES_PER_PAGE`.
  static const int pageSize = 12;

  /// The browse tab and the services tab each stream a small, newest-first
  /// window. Keeping this intentionally small matters on the Spark plan: every
  /// cold start costs one read per document, so the home screen is cheap.
  static const int browseCatalogueLimit = 60;

  /// The search screen streams a wider window so the on-device smart search
  /// (synonyms + typo tolerance) still has something to rank. It is only
  /// opened on demand, never on the home screen. See
  /// `docs/firestore_schema.md` for the scale-up path (Algolia/Typesense).
  static const int searchCatalogueLimit = 300;

  /// Remembers the buyer's recent searches; mirrors `MAX_SEARCHES`.
  static const int maxRecentSearches = 8;

  // --- Media --------------------------------------------------------------
  /// `MultipleImageField` caps each photo at 5 MB.
  static const int maxImageBytes = 5 * 1024 * 1024;

  /// Longest edge handed to `image_picker` so the Dart-side re-encode (which
  /// stores the photo in Firestore) never sees a full-resolution photo.
  static const double maxImagePickEdge = 1600;

  static const int galleryImagesPerListing = 6;

  // --- Admin --------------------------------------------------------------
  /// The single marketplace administrator. Access is enforced again in
  /// `firestore.rules`, so changing this constant alone grants nothing.
  static const String adminEmail = 'abdullashahzan@gmail.com';
  static const String adminUid = 'srXNKWjiXBbza3JTfg4CAaHN4vx1';
  static const String adminUsername = 'shahzan';

  // --- Backend ------------------------------------------------------------
  /// How long the 6-digit hand-over code stays readable on the order screen.
  static const Duration otpSessionLifetime = Duration(minutes: 30);
}

/// A hostel block. The code is what gets stored; the names are display-only.
class CampusBuilding {
  const CampusBuilding(this.code, this.englishName, this.arabicName);

  final String code;
  final String englishName;
  final String arabicName;

  String get englishLabel => '$code · $englishName';
  String get arabicLabel => '$code · $arabicName';

  String label(bool arabic) => arabic ? arabicLabel : englishLabel;
}
