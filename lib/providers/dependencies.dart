import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/ai_assistant.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/image_store.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/service_repository.dart';
import '../data/repositories/user_repository.dart';

/// Overridden in `main()` once the preferences store has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(),
);

/// Listing photos live in Firestore (not Cloud Storage) so everything stays
/// on the free tier — see `ImageStore`.
final imageStoreProvider = Provider<ImageStore>((ref) => ImageStore());

/// Writes the sample catalogue straight into Firestore (there are no Cloud
/// Functions on the Spark plan to do it server-side any more).

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

/// Admin-only moderation and broadcast helpers.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

/// Groq-backed copywriting helpers.
final aiAssistantProvider = Provider<AiAssistant>((ref) => AiAssistant());
