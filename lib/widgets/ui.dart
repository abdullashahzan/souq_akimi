/// The app's widget surface.
///
/// Flutter's `Text` is hidden in favour of `AppText`'s translating `Text`, so
/// every screen gets Arabic copy for free. Screens should import this file
/// instead of `package:flutter/material.dart`.
library;

export 'package:flutter/material.dart' hide Text;

export 'app_text.dart';
