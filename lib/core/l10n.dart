import 'package:flutter/widgets.dart';

/// The two languages the app ships in.
enum AppLanguage {
  english('en', 'English', 'العربية'),
  arabic('ar', 'English', 'العربية');

  const AppLanguage(this.code, this.englishName, this.arabicName);

  final String code;
  final String englishName;
  final String arabicName;

  bool get isArabic => this == AppLanguage.arabic;

  static AppLanguage fromCode(String? code) =>
      code == 'ar' ? AppLanguage.arabic : AppLanguage.english;
}

/// The currently selected language.
///
/// This is deliberately a tiny process-wide value: every screen rebuilds when
/// [MaterialApp.locale] changes, and the copy lookup below is synchronous. It
/// keeps validators, snack bars and repository messages (which do not always
/// have a `BuildContext`) localised too.
class AppLocale {
  const AppLocale._();

  static AppLanguage current = AppLanguage.english;

  static bool get isArabic => current.isArabic;

  static String get code => current.code;

  static Locale get locale => Locale(code);
}

/// Look up [english] in the Arabic dictionary.
///
/// English strings are the keys — that keeps the call sites readable and means
/// an untranslated phrase still renders as sensible English instead of a key
/// such as `checkout.title`.
String translate(String english, {Map<String, String>? args}) {
  if (!AppLocale.isArabic) return _fill(english, args);
  final arabic = _arabic[english];
  return _fill(arabic ?? english, args);
}

String _fill(String value, Map<String, String>? args) {
  if (args == null || args.isEmpty) return value;
  var out = value;
  for (final entry in args.entries) {
    out = out.replaceAll('{${entry.key}}', entry.value);
  }
  return out;
}

extension LocalizationContext on BuildContext {
  String tr(String english, {Map<String, String>? args}) =>
      translate(english, args: args);

  bool get isArabic => AppLocale.isArabic;

  TextDirection get textDirection =>
      AppLocale.isArabic ? TextDirection.rtl : TextDirection.ltr;
}

/// Arabic translations. English is the source language and the fallback.
const Map<String, String> _arabic = {
  // ---- Brand & shell -----------------------------------------------------
  'Souq Akimi': 'سوق أكيمي',
  'Browse': 'تصفّح',
  'Services': 'الخدمات',
  'Sell': 'بِع',
  'Orders': 'طلباتي',
  'Profile': 'حسابي',
  'Language': 'اللغة',
  'English': 'English',
  'Arabic': 'العربية',
  'Back': 'رجوع',
  'Close': 'إغلاق',
  'Not found': 'الصفحة غير موجودة',
  'Back to the souq': 'العودة إلى السوق',
  'Try again': 'حاول مرة أخرى',
  'That did not load': 'تعذّر التحميل',
  'Nothing to show yet': 'لا يوجد شيء بعد',
  'Be the first to list something on campus.': 'كن أول من يعرض شيئًا في الحرم.',
  'List an item': 'أضف منتجًا',
  'Search': 'بحث',
  'Search the campus…': 'ابحث في الحرم…',
  'Search laptops, textbooks, tutoring…': 'ابحث عن لابتوب، كتب، دروس خصوصية…',
  'Find something great on campus': 'اعثر على شيء مميز في الحرم',
  'Buy and sell with students around you.':
      'اشترِ وبِع مع طلاب جامعتك من حولك.',
  'Latest on campus': 'أحدث ما في الحرم',
  'Dismiss': 'إغلاق',
  'Confirm': 'تأكيد',
  'Notifications marked read.': 'تم تحديد الإشعارات كمقروءة.',
  'Please sign in again.': 'يرجى تسجيل الدخول مجددًا.',
  'Mark this request completed?': 'هل تم إنجاز هذا الطلب؟',
  'Decline this request?': 'رفض هذا الطلب؟',
  'Cancel this request?': 'إلغاء هذا الطلب؟',
  'The other student will be notified.': 'سيتم إشعار الطالب الآخر.',
  'Keep request': 'الاحتفاظ بالطلب',
  'Completed': 'مكتمل',
  'Mark completed': 'تحديد كمكتمل',
  'Request completed': 'تم إنجاز الطلب',
  'Request completed.': 'تم إنجاز الطلب.',
  'Pause listing': 'إيقاف العرض مؤقتًا',
  'Resume listing': 'استئناف العرض',
  'Listing updated.': 'تم تحديث العرض.',
  'Mark all read': 'تحديد الكل كمقروء',
  'Request accepted': 'تم قبول الطلب',
  'Request declined': 'تم رفض الطلب',
  'Request cancelled': 'تم إلغاء الطلب',
  'Copied.': 'تم النسخ.',
  'You cannot request your own service.': 'لا يمكنك طلب خدمتك الخاصة.',
  'This service is no longer available.': 'هذه الخدمة لم تعد متاحة.',
  'That request no longer exists.': 'هذا الطلب لم يعد موجودًا.',
  'This request has already been updated.': 'تم تحديث هذا الطلب بالفعل.',
  'Start selling': 'ابدأ البيع',
  'Turn an item you no longer need, or a skill you have, into extra cash.':
      'حوّل ما لم تعد تحتاجه أو مهارة تتقنها إلى دخل إضافي.',

  // ---- Auth --------------------------------------------------------------
  'Welcome back to Souq Akimi': 'أهلًا بعودتك إلى سوق أكيمي',
  'Email': 'البريد الإلكتروني',
  'Email or username': 'البريد الإلكتروني أو اسم المستخدم',
  'Password': 'كلمة المرور',
  'Sign in': 'تسجيل الدخول',
  'Sign out': 'تسجيل الخروج',
  'Create an account': 'إنشاء حساب',
  'Keep browsing as a guest': 'متابعة التصفح كزائر',
  'Forgot password?': 'نسيت كلمة المرور؟',
  'Continue with Google': 'المتابعة باستخدام Google',
  'or': 'أو',
  'Full name': 'الاسم الكامل',
  'Username': 'اسم المستخدم',
  'Create account': 'إنشاء الحساب',
  'Already have an account?': 'لديك حساب بالفعل؟',
  'No account yet?': 'ليس لديك حساب؟',
  'Sign up': 'إنشاء حساب',
  'Send reset link': 'إرسال رابط الاستعادة',
  'Reset your password': 'استعادة كلمة المرور',
  'Sign out?': 'تسجيل الخروج؟',
  'Stay': 'البقاء',
  'You can sign back in with your email and password.':
      'يمكنك تسجيل الدخول مجددًا ببريدك وكلمة المرور.',
  'That email address does not look right.':
      'يبدو أن البريد الإلكتروني غير صحيح.',
  'That email is already registered. Try signing in instead.':
      'هذا البريد مسجّل بالفعل. جرّب تسجيل الدخول.',
  'Please choose a password of at least 6 characters.':
      'اختر كلمة مرور من 6 أحرف على الأقل.',
  'Email or password is incorrect.': 'البريد أو كلمة المرور غير صحيحة.',
  'This account has been disabled.': 'تم تعطيل هذا الحساب.',
  'Too many attempts. Please wait a moment and retry.':
      'محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة.',
  'No connection. Check your network and try again.':
      'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
  'Please sign in again to continue.': 'سجّل الدخول مجددًا للمتابعة.',
  'Something went wrong. Please try again.':
      'حدث خطأ ما. يرجى المحاولة مجددًا.',
  'Sign in to continue.': 'سجّل الدخول للمتابعة.',
  'Sign in to buy, sell and keep your delivery details handy.':
      'سجّل الدخول للشراء والبيع وحفظ بيانات التوصيل.',
  'You are browsing as a guest': 'أنت تتصفح كزائر',

  // ---- Validation --------------------------------------------------------
  'Use at least 3 characters': 'استخدم 3 أحرف على الأقل',
  'Tell buyers a little more': 'أخبر المشتري بتفاصيل أكثر',
  'Tell clients a little more': 'أخبر العميل بتفاصيل أكثر',
  'Enter a price above zero': 'أدخل سعرًا أكبر من صفر',
  'Enter a quantity': 'أدخل الكمية',
  'Enter your name': 'أدخل اسمك',
  'Enter a phone number': 'أدخل رقم الجوال',
  'Enter your room number': 'أدخل رقم الغرفة',
  'Choose your building': 'اختر المبنى',
  'Enter the name the seller should ask for':
      'أدخل الاسم الذي سيسأل عنه البائع',
  'Enter a valid email': 'أدخل بريدًا إلكترونيًا صحيحًا',
  'Add a little more detail so they can help.':
      'أضف تفاصيل أكثر ليتمكنوا من المساعدة.',

  // ---- Money & listing labels -------------------------------------------
  'New': 'جديد',
  'Used': 'مستعمل',
  'PAUSED': 'موقوف',
  'SOLD OUT': 'نفدت الكمية',
  'Cover': 'الغلاف',
  'Photos': 'الصور',
  'Add a cover photo': 'أضف صورة الغلاف',
  'Condition': 'الحالة',
  'Description': 'الوصف',
  'Tags (optional)': 'الوسوم (اختياري)',
  'Price': 'السعر',
  'Quantity': 'الكمية',
  'Title': 'العنوان',
  'Category': 'التصنيف',
  'Charged': 'طريقة التسعير',
  'Fixed price': 'سعر ثابت',
  'Per hour': 'بالساعة',
  'Per job': 'بالوظيفة',
  'Per page': 'بالصفحة',
  'Sell an item': 'بع منتجًا',
  'Offer a service': 'قدّم خدمة',
  'Selling': 'البيع',
  'Buying': 'الشراء',
  'My listings': 'منتجاتي',
  'My services': 'خدماتي',
  'My sales': 'مبيعاتي',
  'My orders': 'طلباتي',
  'Notifications': 'الإشعارات',
  'Requests': 'الطلبات',
  'Delivery details': 'بيانات التوصيل',
  'Account': 'الحساب',
  'Sign in to list something — your listings stay attached to your account.':
      'سجّل الدخول لعرض منتج — ستبقى منتجاتك مرتبطة بحسابك.',
  'Sell a service': 'قدّم خدمة',
  'A physical item students can buy and receive in their room.':
      'منتج مادي يمكن للطلاب شراؤه واستلامه في غرفتهم.',
  'A skill, errand or service you can do for other students.':
      'مهارة أو مهمة أو خدمة يمكنك تقديمها لطلاب آخرين.',
  'Publish listing': 'نشر المنتج',
  'Publish service': 'نشر الخدمة',
  'Save changes': 'حفظ التغييرات',
  'Edit listing': 'تعديل المنتج',
  'Edit service': 'تعديل الخدمة',
  'Service updated.': 'تم تحديث الخدمة.',
  'Listing is live.': 'تم نشر المنتج.',
  'Service is live.': 'تم نشر الخدمة.',
  'Listing removed.': 'تم حذف المنتج.',
  'Service removed.': 'تم حذف الخدمة.',
  'Remove listing?': 'حذف المنتج؟',
  'Remove service?': 'حذف الخدمة؟',
  'Remove': 'حذف',
  'Cancel': 'إلغاء',
  'Edit': 'تعديل',
  'New listing': 'منتج جديد',
  'New service': 'خدمة جديدة',
  'What are you selling?': 'ماذا تبيع؟',
  'Describe the item, its condition and any details.':
      'صف المنتج وحالته وأي تفاصيل أخرى.',
  'Up to {count} photos. The first is the cover.':
      '{count} صور كحد أقصى. الأولى هي الغلاف.',
  'Photo {n}': 'صورة {n}',
  'Skipped {name}: over 5 MB.': 'تم تخطي {name}: الحجم أكبر من 5 ميجابايت.',
  'That photo is over 5 MB.': 'حجم الصورة أكبر من 5 ميجابايت.',
  'That photo is too large to store.': 'الصورة كبيرة جدًا للحفظ.',
  'That photo could not be read. Please pick a JPEG or PNG.':
      'تعذّر قراءة الصورة. اختر صورة JPEG أو PNG.',
  'Add photos': 'أضف صورًا',
  'Save': 'حفظ',
  'Saving…': 'جارٍ الحفظ…',

  // ---- Browse & search ---------------------------------------------------
  'Best match': 'الأفضل تطابقًا',
  'Newest': 'الأحدث',
  'Price: low to high': 'السعر: من الأقل للأعلى',
  'Price: high to low': 'السعر: من الأعلى للأقل',
  'Top sales': 'الأكثر مبيعًا',
  'Most viewed': 'الأكثر مشاهدة',
  'Name A–Z': 'الاسم أ–ي',
  'All': 'الكل',
  'Sort': 'ترتيب',
  'Results': 'النتائج',
  'Recent searches': 'عمليات البحث الأخيرة',
  'Clear': 'مسح',
  'Did you mean "{term}"?': 'هل تقصد «{term}»؟',
  'Search services…': 'ابحث عن خدمة…',
  'Campus services': 'خدمات الحرم',
  'Homework help, printouts, delivery runs and more':
      'مساعدة دراسية، طباعة، توصيل وأكثر',
  'No services found': 'لا توجد خدمات',
  'Offer your own skills and other students will find you.':
      'اعرض مهاراتك وسيجدك الطلاب.',
  'No listings found': 'لا توجد منتجات',
  'Try a different search or filter.': 'جرّب بحثًا أو تصفية مختلفة.',
  'Nothing here yet': 'لا يوجد شيء بعد',
  'Clear filters': 'مسح التصفية',
  'Filters': 'التصفية',
  'Apply': 'تطبيق',
  'Under': 'أقل من',
  'Over': 'أكثر من',
  'Price range': 'نطاق السعر',
  'Any price': 'أي سعر',
  'Related listings': 'منتجات مشابهة',
  'More from this seller': 'المزيد من هذا البائع',
  'Seller': 'البائع',

  // ---- Product detail & checkout ----------------------------------------
  'Buy now': 'اشترِ الآن',
  'Add to order': 'أضف للطلب',
  'Out of stock': 'غير متوفر',
  'In stock': 'متوفر',
  'Stock': 'المخزون',
  'Checkout': 'إتمام الطلب',
  'Nothing to check out': 'لا يوجد ما يمكن طلبه',
  'Pick something you like first.': 'اختر شيئًا يعجبك أولًا.',
  'Browse the souq': 'تصفّح السوق',
  'Delivery': 'التوصيل',
  'Delivered to your hostel room': 'يوصَّل إلى غرفتك في السكن',
  'Your details': 'بياناتك',
  'We remember these, so you only fill them in once.':
      'نحفظ هذه البيانات حتى تملأها مرة واحدة فقط.',
  'Phone': 'رقم الجوال',
  'Building': 'المبنى',
  'Room number': 'رقم الغرفة',
  'Choose your hostel block': 'اختر مبنى السكن',
  'Notes for the seller (optional)': 'ملاحظات للبائع (اختياري)',
  'Payment': 'الدفع',
  'Cash on delivery': 'الدفع عند الاستلام',
  'Place order · {total}': 'تأكيد الطلب · {total}',
  'Only {count} left — adjust the quantity on the listing page.':
      'بقي {count} فقط — عدّل الكمية من صفحة المنتج.',
  'Your order is in': 'تم استلام طلبك',
  'Order confirmed': 'تم تأكيد الطلب',
  'Order number': 'رقم الطلب',
  'We let the seller know. Pay cash when it arrives.':
      'أبلغنا البائع. ادفع نقدًا عند وصول الطلب.',
  'View order': 'عرض الطلب',
  'Continue browsing': 'متابعة التصفّح',
  'Delivery code': 'رمز التسليم',
  'Show code': 'إظهار الرمز',
  'Complete delivery': 'إتمام التسليم',
  'Cancel order': 'إلغاء الطلب',
  'Order details': 'تفاصيل الطلب',
  'Delivered': 'تم التسليم',
  'On the way': 'في الطريق',
  'Cancelled': 'ملغى',
  'Ready for delivery': 'جاهز للتسليم',
  'No items': 'لا توجد منتجات',
  'To {address}': 'إلى {address}',
  'Sales': 'المبيعات',
  'Sale': 'بيع',

  // ---- Requests ----------------------------------------------------------
  'Sent': 'المُرسلة',
  'Received': 'المستلمة',
  'No requests sent': 'لا توجد طلبات مرسلة',
  'Find a service you need and send the provider a brief.':
      'ابحث عن خدمة تحتاجها وأرسل تفاصيلها لمقدّم الخدمة.',
  'Nothing yet': 'لا يوجد بعد',
  'When students request your services, they show up here.':
      'عندما يطلب الطلاب خدماتك ستظهر هنا.',
  'Accept': 'قبول',
  'Decline': 'رفض',
  'Cancel request': 'إلغاء الطلب',
  'Open': 'فتح',
  'Pending': 'قيد الانتظار',
  'Accepted': 'مقبول',
  'Declined': 'مرفوض',
  'Request accepted.': 'تم قبول الطلب.',
  'Request declined.': 'تم رفض الطلب.',
  'Request cancelled.': 'تم إلغاء الطلب.',
  'Request sent.': 'تم إرسال الطلب.',
  'Request sent ({status})': 'تم الإرسال ({status})',
  'Request this service': 'اطلب هذه الخدمة',
  'What do you need?': 'ماذا تحتاج؟',
  'Send request': 'إرسال الطلب',
  'Sign in to request a service.': 'سجّل الدخول لطلب خدمة.',
  'Your contact details': 'بيانات التواصل',
  'We use your saved details, or you can change them for this request.':
      'نستخدم بياناتك المحفوظة، أو يمكنك تغييرها لهذا الطلب.',
  'New service request': 'طلب خدمة جديد',
  'View request': 'عرض الطلب',

  // ---- Service categories ------------------------------------------------
  'Delivery & errands': 'التوصيل والمهام',
  'Homework help': 'مساعدة دراسية',
  'Project help': 'مساعدة في المشاريع',
  'Printing & copies': 'الطباعة والنسخ',
  'Tutoring & lessons': 'دروس خصوصية',
  'Design & creative': 'التصميم والإبداع',
  'Tech help & repairs': 'الدعم التقني والإصلاح',
  'Other campus help': 'خدمات جامعية أخرى',
  'What you get': 'ما ستحصل عليه',

  // ---- Profile -----------------------------------------------------------
  'Listings': 'المنتجات',
  'unread — new orders and updates': 'غير مقروءة — طلبات وتحديثات جديدة',
  'New orders land here': 'ستظهر الطلبات الجديدة هنا',
  'Briefs sent and received': 'الطلبات المرسلة والمستلمة',
  'offered': 'معروضة',
  'Add a phone, building and room so checkout is prefilled':
      'أضف الجوال والمبنى والغرفة لتعبئة الطلب تلقائيًا',
  'Saved once and used to prefill every checkout.':
      'تُحفظ مرة واحدة وتُستخدم في كل طلب.',
  'Delivery details saved.': 'تم حفظ بيانات التوصيل.',
  'Developer': 'المطوّر',
  'Seed demo data': 'بيانات تجريبية',
  'Write the sample catalogue into Firestore':
      'كتابة كتالوج تجريبي في Firestore',
  'Admin dashboard': 'لوحة الإدارة',
  'Admins only': 'للمشرفين فقط',
  'This area is for the marketplace admin.': 'هذه المنطقة مخصّصة لمشرف السوق.',

  // ---- Notifications -----------------------------------------------------
  'Inbox': 'صندوق الوارد',
  'No notifications yet': 'لا توجد إشعارات بعد',
  'Orders and updates will appear here.': 'ستظهر الطلبات والتحديثات هنا.',
  'New order': 'طلب جديد',
  'Announcement': 'إعلان',
  'All caught up': 'لا جديد',

  // ---- Admin -------------------------------------------------------------
  'Overview': 'نظرة عامة',
  'Content': 'المحتوى',
  'Broadcast': 'إشعار جماعي',
  'Users': 'المستخدمون',
  'Products': 'المنتجات',
  'Pending requests': 'طلبات معلّقة',
  'Remove this listing?': 'حذف هذا المنتج؟',
  'Remove this service?': 'حذف هذه الخدمة؟',
  'This cannot be undone.': 'لا يمكن التراجع عن هذا.',
  'Send to everyone': 'إرسال للجميع',
  'Notification title': 'عنوان الإشعار',
  'Message': 'الرسالة',
  'Send announcement': 'إرسال الإعلان',
  'Announcement sent to {count} users.':
      'تم إرسال الإعلان إلى {count} مستخدمًا.',
  'Write an announcement…': 'اكتب إعلانًا…',
  'Draft with AI': 'اكتب بالذكاء الاصطناعي',
  'Search users or listings…': 'ابحث عن مستخدم أو منتج…',
  'No results': 'لا توجد نتائج',

  // ---- AI ----------------------------------------------------------------
  'Write with AI': 'اكتب بالذكاء الاصطناعي',
  'Improve with AI': 'حسّن بالذكاء الاصطناعي',
  'Suggest tags': 'اقترح وسومًا',
  'Draft my brief': 'اكتب طلبي',
  'Generating…': 'جارٍ الكتابة…',
  'AI is thinking…': 'الذكاء الاصطناعي يفكّر…',
  'AI could not write that. Please try again.':
      'تعذّر على الذكاء الاصطناعي الكتابة. حاول مجددًا.',
  'Add a title first so AI has something to work with.':
      'أضف عنوانًا أولًا ليتمكن الذكاء الاصطناعي من المساعدة.',
  'AI is taking too long. Please try again.':
      'يستغرق الذكاء الاصطناعي وقتًا طويلًا. حاول مجددًا.',
  'AI is busy right now. Please try again in a moment.':
      'الذكاء الاصطناعي مشغول الآن. حاول بعد قليل.',
  'AI needs a connection. Check your internet and try again.':
      'يحتاج الذكاء الاصطناعي إلى اتصال. تحقّق من الإنترنت وحاول مجددًا.',

  // ---- Errors ------------------------------------------------------------
  'This list is still getting ready. Please try again in a moment.':
      'هذه القائمة قيد التجهيز. حاول بعد قليل.',
  'You do not have access to that. Try signing in again.':
      'لا تملك صلاحية الوصول. سجّل الدخول مجددًا.',
  'No connection. Check your internet and try again.':
      'لا يوجد اتصال. تحقّق من الإنترنت وحاول مجددًا.',
  'That item no longer exists.': 'هذا العنصر لم يعد موجودًا.',
  'Too many attempts. Please wait a moment and try again.':
      'محاولات كثيرة. انتظر قليلًا وحاول مجددًا.',
  'Please sign in again to finish that.': 'سجّل الدخول مجددًا لإكمال العملية.',
  'That email and password do not match.': 'البريد وكلمة المرور غير متطابقين.',
  'You are not allowed to do that.': 'غير مسموح لك بهذا الإجراء.',
  'We could not find that any more.': 'لم نعد نجد هذا العنصر.',
  'The server is unreachable. Check your connection and try again.':
      'تعذّر الوصول إلى الخادم. تحقّق من الاتصال وحاول مجددًا.',
  'Someone else changed this just now. Please try again.':
      'قام شخص آخر بتغيير هذا الآن. حاول مجددًا.',
  'Could not allocate an order number. Please retry.':
      'تعذّر إنشاء رقم طلب. حاول مجددًا.',
  'One of the items in your basket is no longer available.':
      'أحد المنتجات لم يعد متاحًا.',
  'This delivery is already settled.': 'تم إنهاء هذا التسليم بالفعل.',
  'This delivery has already been settled.': 'تم إنهاء هذا التسليم بالفعل.',
  'This order has already been settled.': 'تم إنهاء هذا الطلب بالفعل.',
  'This order is already cancelled.': 'تم إلغاء هذا الطلب بالفعل.',
  'Order not found.': 'الطلب غير موجود.',
  'Delivery not found.': 'التسليم غير موجود.',
  'Incorrect code.': 'الرمز غير صحيح.',
  'Only the buyer can cancel this order.': 'المشتري فقط يمكنه إلغاء هذا الطلب.',
  'Only the seller can complete this delivery.':
      'البائع فقط يمكنه إتمام هذا التسليم.',
  'Only the buyer can view this delivery code.':
      'المشتري فقط يمكنه رؤية رمز التسليم.',
  'Too many incorrect codes. Ask the buyer to generate a new code.':
      'رموز خاطئة كثيرة. اطلب من المشتري إنشاء رمز جديد.',
  'Add at least one item to your order.': 'أضف منتجًا واحدًا على الأقل.',
  'Google sign-in could not start. Please try again.':
      'تعذّر بدء تسجيل الدخول بـ Google. حاول مجددًا.',
  'Google sign-in is not available on this device.':
      'تسجيل الدخول بـ Google غير متاح على هذا الجهاز.',
  'Google sign-in was cancelled.': 'تم إلغاء تسجيل الدخول بـ Google.',

  // ---- Additional UI copy ------------------------------------------------
  'Refresh': 'تحديث',
  'Reach': 'الوصول',
  'inboxes per announcement': 'صندوق وارد لكل إعلان',
  'You are in control': 'أنت تتحكم',
  'Moderate the catalogue and reach every student from one place.':
      'أدر الكتالوج وصِل إلى كل طالب من مكان واحد.',
  'Deleting a listing also removes its stored photos. Order history is kept for both sides.':
      'حذف المنتج يحذف صوره المحفوظة أيضًا. يبقى سجل الطلبات محفوظًا للطرفين.',
  'No services match that search.': 'لا توجد خدمات تطابق هذا البحث.',
  'No products match that search.': 'لا توجد منتجات تطابق هذا البحث.',
  'Services are removable here. Providers keep their order history.':
      'يمكن حذف الخدمات من هنا. يحتفظ مقدّمو الخدمة بسجل طلباتهم.',
  'Products are removable here. Stored photos are cleaned up too.':
      'يمكن حذف المنتجات من هنا. تُنظّف الصور المحفوظة أيضًا.',
  'Live': 'نشط',
  'Paused': 'موقوف',
  'There are no user inboxes to write to yet.':
      'لا توجد صناديق وارد للمستخدمين بعد.',
  'This will add the announcement to {count} inboxes. Continue?':
      'سيُضاف الإعلان إلى {count} صندوق وارد. هل تريد المتابعة؟',
  'Write once. It lands in every student\'s in-app inbox and lights up the badge.':
      'اكتبه مرة واحدة ليصل إلى صندوق وارد كل طالب ويضيء شارة الإشعارات.',
  'A small campus update': 'تحديث صغير في الحرم',
  'Your message preview appears here.': 'ستظهر معاينة رسالتك هنا.',
  'Send to everyone ({count})': 'إرسال للجميع ({count})',
  'Announcements are written to each inbox now; new users will not receive past announcements.': 'تُكتب الإعلانات في كل صندوق وارد الآن؛ لن يستلم المستخدمون الجدد الإعلانات السابقة.',
  'Moderate listings and reach every student': 'أدر المنتجات وصِل إلى كل طالب',
  'Briefs you send and receive live behind your account.':
      'الطلبات التي ترسلها وتستلمها مرتبطة بحسابك.',
  'Sign in with the administrator account to continue.':
      'سجّل الدخول بحساب المشرف للمتابعة.',
  'Nothing lives at {location}': 'لا يوجد شيء في {location}',
  'Please sign in to continue.': 'سجّل الدخول للمتابعة.',
  'Your orders, listings and requests live behind your account.':
      'طلباتك ومنتجاتك وطلبات الخدمة مرتبطة بحسابك.',
  'That username is not registered. Sign in with your email instead.':
      'اسم المستخدم هذا غير مسجّل. سجّل الدخول ببريدك الإلكتروني.',
  'Enter your email first, then tap "Forgot password".':
      'أدخل بريدك الإلكتروني أولًا ثم اضغط «نسيت كلمة المرور».',
  'Reset link sent to {email}.': 'أُرسل رابط الاستعادة إلى {email}.',
  'Welcome back to {app}': 'أهلًا بعودتك إلى {app}',
  'Enter your email': 'أدخل بريدك الإلكتروني',
  'At least 6 characters': '6 أحرف على الأقل',
  'Join {app}': 'انضم إلى {app}',
  'Buy, sell and offer services to students on campus.':
      'اشترِ وبِع وقدّم خدمات لطلاب الحرم الجامعي.',
  'Shown publicly on your listings': 'يظهر علنًا في منتجاتك',
  'No spaces, please': 'بدون مسافات، من فضلك',
  'I already have an account': 'لديّ حساب بالفعل',
  'No matches': 'لا توجد نتائج',
  'Try fewer words, a brand name, or a price like "under 50".':
      'جرّب كلمات أقل أو اسم ماركة أو سعرًا مثل «أقل من 50».',
  'Sort by': 'ترتيب حسب',
  'Service not found': 'الخدمة غير موجودة',
  'It may have been removed by its provider.': 'ربما حذفها مقدّم الخدمة.',
  'Service provider on campus': 'مقدّم خدمة في الحرم',
  'The provider comes to your hostel room. Share your building and room with the brief.':
      'يأتي مقدّم الخدمة إلى غرفتك في السكن. شارك المبنى والغرفة في الطلب.',
  'Student': 'طالب',
  'This brief goes straight to the provider, with your contact details.':
      'يصل هذا الطلب مباشرة إلى مقدّم الخدمة مع بيانات تواصلك.',
  'e.g. I need 40 pages printed in colour and bound, ready by Thursday evening.':
      'مثال: أحتاج طباعة 40 صفحة ملوّنة وتجليدها، جاهزة مساء الخميس.',
  'Shared with provider': 'تُشارك مع مقدّم الخدمة',
  'You pay the provider directly when the work is done.':
      'تدفع لمقدّم الخدمة مباشرة عند إنجاز العمل.',
  'For "{title}"': 'لـ «{title}»',
  'Sent {date}': 'أُرسل {date}',
  'Room {number}': 'غرفة {number}',
  'No services yet': 'لا توجد خدمات بعد',
  'Offer printouts, tutoring, delivery runs or anything you are good at.':
      'اعرض الطباعة أو الدروس أو التوصيل أو أي شيء تجيده.',
  'My requests': 'طلباتي',
  'e.g. Printouts & binding — same day': 'مثال: طباعة وتجليد — في نفس اليوم',
  'What you will do, how long it takes, and where you can hand it over.':
      'ماذا ستقدّم، وكم يستغرق، وأين يمكن التسليم.',
  'printing, binding, thesis': 'طباعة، تجليد، رسالة',
  'Cancel this order?': 'إلغاء هذا الطلب؟',
  'The seller will not deliver it, and the items go back on sale. This cannot be undone.':
      'لن يوصّل البائع الطلب، وستعود المنتجات للبيع. لا يمكن التراجع عن هذا.',
  'Keep it': 'الإبقاء عليه',
  'Order cancelled.': 'تم إلغاء الطلب.',
  'Show this to @{seller}': 'أظهر هذا إلى @{seller}',
  'They type it into their phone when they hand over the item.':
      'يكتبه في هاتفه عند تسليم المنتج.',
  'That is every try used up. Mint a fresh code and read that one out instead — the old one stops working.': 'انتهت كل المحاولات. أنشئ رمزًا جديدًا واقرأه بدلًا منه — الرمز القديم يتوقف عن العمل.',
  'Generate a new code': 'إنشاء رمز جديد',
  'Done': 'تم',
  'Order not found': 'الطلب غير موجود',
  'Check the order number and try again.': 'تحقّق من رقم الطلب وحاول مجددًا.',
  'Deliver to {address}': 'التوصيل إلى {address}',
  'Items ({count})': 'المنتجات ({count})',
  'Total · cash on delivery': 'الإجمالي · الدفع عند الاستلام',
  'Deliveries ({count})': 'عمليات التسليم ({count})',
  'One per seller': 'واحدة لكل بائع',
  'Preparing…': 'جارٍ التجهيز…',
  'Delivered {date}': 'سُلّم {date}',
  'Show hand-over code': 'إظهار رمز التسليم',
  'No orders yet': 'لا توجد طلبات بعد',
  'Buy something and you can follow its delivery here.':
      'اشترِ شيئًا ويمكنك متابعة توصيله من هنا.',
  'No sales yet': 'لا توجد مبيعات بعد',
  'List an item and buyers will find you through search.':
      'أضف منتجًا وسيجدك المشترون عبر البحث.',
  'The code is 6 digits.': 'الرمز من 6 أرقام.',
  'Delivery confirmed. Order complete.': 'تم تأكيد التسليم. اكتمل الطلب.',
  'Delivery confirmed.': 'تم تأكيد التسليم.',
  'Your items ({count})': 'منتجاتك ({count})',
  'This order does not contain your items (yet).':
      'لا يحتوي هذا الطلب على منتجاتك (بعد).',
  'Your delivery': 'تسليمك',
  'Delivered — this order is complete.': 'تم التسليم — اكتمل هذا الطلب.',
  'Ask the buyer for their 6-digit code when you hand over the item and collect the cash.': 'اطلب من المشتري رمزه المكوّن من 6 أرقام عند تسليم المنتج واستلم المبلغ نقدًا.',
  'Checking…': 'جارٍ التحقق…',
  'Confirm delivery': 'تأكيد التسليم',
  'This delivery was cancelled.': 'تم إلغاء هذا التسليم.',
  'Order placed': 'تم الطلب',
  'Order {number}': 'الطلب {number}',
  'Your order is being written to the ledger.': 'جارٍ تسجيل طلبك.',
  'What happens next': 'ماذا يحدث بعد ذلك',
  'The seller prepares your item': 'يجّهز البائع منتجك',
  'They bring it to your hostel room. You can follow the delivery from My orders.':
      'يوصّلونه إلى غرفتك في السكن. يمكنك متابعة التسليم من «طلباتي».',
  'Show your 6-digit hand-over code': 'أظهر رمز التسليم المكوّن من 6 أرقام',
  'Open the order, reveal the code and read it to the seller when the item arrives.':
      'افتح الطلب، وأظهر الرمز، واقرأه للبائع عند وصول المنتج.',
  'Pay cash at the door': 'ادفع نقدًا عند الباب',
  'Hand over the exact amount when you receive the item. Nothing is charged in the app.':
      'سلّم المبلغ بالضبط عند استلام المنتج. لا يُخصم أي مبلغ في التطبيق.',
  'Keep browsing': 'متابعة التصفح',
  'Listing not found': 'المنتج غير موجود',
  'It may have been removed by the seller.': 'ربما حذفه البائع.',
  'How many?': 'كم العدد؟',
  'Buy {count} for {total}': 'اشترِ {count} مقابل {total}',
  'Sign in to buy this item.': 'سجّل الدخول لشراء هذا المنتج.',
  'e.g. 214': 'مثال: 214',
  'e.g. Call me when you reach the block gate.':
      'مثال: اتصل بي عندما تصل إلى بوابة المبنى.',
  'Pay {amount} in cash': 'ادفع {amount} نقدًا',
  'when the item is in your hands.': 'عندما يكون المنتج بين يديك.',
  'You will get a 6-digit hand-over code. Read it to the seller only when the item arrives — that is what completes the order.': 'ستحصل على رمز تسليم من 6 أرقام. اقرأه للبائع فقط عند وصول المنتج — بهذا يكتمل الطلب.',
  'Turn the things you no longer need into cash.':
      'حوّل أشياءك التي لم تعد تحتاجها إلى نقود.',
  'No listings yet': 'لا توجد منتجات بعد',
  'Listing paused — it is hidden from buyers.':
      'تم إيقاف المنتج — إنه مخفي عن المشترين.',
  'Listing is live again.': 'تم نشر المنتج مجددًا.',
  '"{name}" will be deleted permanently.': 'سيُحذف «{name}» نهائيًا.',
  'Turn something you own into cash, or turn a skill into a service.':
      'حوّل شيئًا تملكه إلى نقود، أو حوّل مهارتك إلى خدمة.',
  'Manage': 'إدارة',
  'Buyers pay cash on delivery. Keep hand-overs on campus and use the six-digit code to confirm.': 'يدفع المشترون نقدًا عند الاستلام. سلّموا داخل الحرم واستخدموا الرمز المكوّن من ستة أرقام للتأكيد.',
  'Listings with a clear cover photo sell much faster. Add up to six.':
      'المنتجات ذات صورة غلاف واضحة تُبيع أسرع بكثير. أضف حتى ست صور.',
  'e.g. Vintage camera': 'مثال: كاميرا قديمة',
  'gaming, vintage, size 42': 'ألعاب، قديم، مقاس 42',
  'AI can make mistakes — give it a quick read before publishing.':
      'قد يخطئ الذكاء الاصطناعي — راجعه سريعًا قبل النشر.',
  'That part of the screen could not be shown.':
      'تعذّر عرض هذا الجزء من الشاشة.',
  'New orders, service requests and campus announcements will appear here.':
      'ستظهر هنا الطلبات الجديدة وطلبات الخدمة وإعلانات الحرم.',
  'Seeded {products} products and {services} services.':
      'أُضيف {products} منتجًا و{services} خدمة.',
  'just now': 'الآن',
  'Sold out': 'نفدت الكمية',
  'SAR': 'ر.س',
  'Deliver to': 'التوصيل إلى',
  'to {address}': 'إلى {address}',
  'Remove photo': 'حذف الصورة',

  'more': '+{count}',
  '{count} order on the way': '{count} طلب في الطريق',
  '{count} orders on the way': '{count} طلبات في الطريق',
  '{count} of yours': '{count} من مبيعاتك',
  '@{seller} brings it to your room — pay cash when it arrives.':
      '@{seller} يوصّله إلى غرفتك — ادفع نقدًا عند وصوله.',
  'Pay {amount} in cash when the item is in your hands.':
      'ادفع {amount} نقدًا عندما يكون المنتج بين يديك.',
  '{count} item · {total} cash on delivery':
      '{count} منتج · {total} عند الاستلام',
  '{count} items · {total} cash on delivery':
      '{count} منتجات · {total} عند الاستلام',
  '{count} percent': '{count}',

  '{remaining} of {max} attempts left': '{remaining} من {max} محاولات متبقية',
  '{count} attempts left before the buyer is asked for a new code.':
      'بقي {count} محاولات قبل أن يُطلب من المشتري رمز جديد.',
  '{count} listing': '{count} منتج',
  '{count} listings': '{count} منتجات',
  '{count} offered': '{count} معروضة',
  '{count} sale': '{count} عملية بيع',
  '{count} sales': '{count} مبيعات',
  '{count} order': '{count} طلب',
  '{count} orders': '{count} طلبات',
  '{count} unread — new orders and updates':
      '{count} غير مقروءة — طلبات وتحديثات جديدة',
  'AI is not configured for this build.':
      'الذكاء الاصطناعي غير مهيأ في هذا الإصدار.',

  'Sign in to continue': 'سجّل الدخول للمتابعة',
  'At least 3 characters': '3 أحرف على الأقل',
  'Resume': 'استئناف',
  'Seller on campus': 'بائع في الحرم',
  'More like this': 'المزيد من هذا القبيل',
  '{count} views': '{count} مشاهدة',
  '{count} live': '{count} نشط',
  '{count} stock': '{count} في المخزون',

  '{requester} requested "{service}".': '{requester} طلب «{service}».',
};
