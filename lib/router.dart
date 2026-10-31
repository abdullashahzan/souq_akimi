import 'package:souq_akimi/widgets/ui.dart';
import 'core/l10n.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/admin_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/require_auth.dart';
import 'features/browse/browse_screen.dart';
import 'features/browse/search_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/checkout/order_confirmation_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/orders/my_orders_screen.dart';
import 'features/orders/my_sales_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/sale_detail_screen.dart';
import 'features/product/my_listings_screen.dart';
import 'features/product/product_detail_screen.dart';
import 'features/product/product_form_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/services/my_services_screen.dart';
import 'features/services/requests_screen.dart';
import 'features/services/service_detail_screen.dart';
import 'features/services/service_form_screen.dart';
import 'features/services/services_screen.dart';
import 'features/sell/sell_screen.dart';
import 'features/shell/app_shell.dart';

/// Every route in the app.
///
/// All app screens live **inside** [AppShell], so the bottom navigation bar is
/// visible while browsing, checking out, reading an order or editing a listing.
/// Only the signed-out auth screens sit above the shell.
GoRouter createRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    // ---------------------------------------------------------------- #
    // Signed-out auth (full screen, no tabs)
    // ---------------------------------------------------------------- #
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

    // ---------------------------------------------------------------- #
    // The app shell
    // ---------------------------------------------------------------- #
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        // ---- Browse ------------------------------------------------
        GoRoute(
          path: '/',
          builder: (_, _) => const BrowseScreen(),
          routes: [
            GoRoute(path: 'search', builder: (_, _) => const SearchScreen()),
          ],
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) =>
              ProductDetailScreen(productId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) =>
                  ProductFormScreen(productId: state.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
        GoRoute(
          path: '/order/:orderNumber',
          builder: (context, state) => OrderDetailScreen(
            orderNumber: state.pathParameters['orderNumber']!,
          ),
          routes: [
            GoRoute(
              path: 'confirmed',
              builder: (context, state) => OrderConfirmationScreen(
                orderNumber: state.pathParameters['orderNumber']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/sale/:orderNumber',
          builder: (context, state) => SaleDetailScreen(
            orderNumber: state.pathParameters['orderNumber']!,
          ),
        ),

        // ---- Services ----------------------------------------------
        GoRoute(path: '/services', builder: (_, _) => const ServicesScreen()),
        GoRoute(
          path: '/service/:id',
          builder: (context, state) =>
              ServiceDetailScreen(serviceId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) =>
                  ServiceFormScreen(serviceId: state.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(
          path: '/requests',
          builder: (_, _) => const RequireAuth(
            title: 'Requests',
            message: 'Briefs you send and receive live behind your account.',
            child: RequestsScreen(),
          ),
        ),

        // ---- Selling -----------------------------------------------
        GoRoute(
          path: '/sell',
          builder: (_, _) => const RequireAuth(
            title: 'Sell',
            message:
                'Sign in to list something — your listings stay attached to your account.',
            child: SellScreen(),
          ),
          routes: [
            GoRoute(
              path: 'item',
              builder: (_, _) => const RequireAuth(
                title: 'Sell an item',
                message:
                    'Sign in to list something — your listings stay attached to your account.',
                child: ProductFormScreen(),
              ),
            ),
            GoRoute(
              path: 'service',
              builder: (_, _) => const RequireAuth(
                title: 'Offer a service',
                child: ServiceFormScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/my-listings',
          builder: (_, _) => const RequireAuth(
            title: 'My listings',
            child: MyListingsScreen(),
          ),
        ),
        GoRoute(
          path: '/offer',
          redirect: (_, _) => '/sell/service',
        ),
        GoRoute(
          path: '/my-services',
          builder: (_, _) => const RequireAuth(
            title: 'My services',
            child: MyServicesScreen(),
          ),
        ),

        // ---- Orders ------------------------------------------------
        GoRoute(
          path: '/orders',
          builder: (_, _) =>
              const RequireAuth(title: 'My orders', child: MyOrdersScreen()),
        ),
        GoRoute(
          path: '/sales',
          builder: (_, _) =>
              const RequireAuth(title: 'My sales', child: MySalesScreen()),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const RequireAuth(
            title: 'Notifications',
            child: NotificationsScreen(),
          ),
        ),

        // ---- Admin -------------------------------------------------
        GoRoute(
          path: '/admin',
          builder: (_, _) => const RequireAuth(
            title: 'Admin dashboard',
            message: 'Sign in with the administrator account to continue.',
            child: AdminScreen(),
          ),
        ),

        // ---- Profile -----------------------------------------------
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      ],
    ),
  ],
  errorBuilder: (context, state) => _NotFound(location: state.uri.toString()),
);

/// A friendly dead end — typos in deep links should still feel like the app.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  'Nothing lives at {location}',
                  args: {'location': location},
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to the souq'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
