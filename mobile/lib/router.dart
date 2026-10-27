import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models/models.dart';
import 'screens/addresses_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/pay_screen.dart';
import 'screens/product_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'state/providers.dart';
import 'widgets/page_transitions.dart';

String _backToPay(Ref ref) {
  final id = ref.read(lastPayOrderProvider);
  return id == null ? '/' : '/pay/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(splashDoneProvider, (_, _) => refresh.value++);
  ref.listen(welcomeSeenProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final splashDone = ref.read(splashDoneProvider);
      final welcomeSeen = ref.read(welcomeSeenProvider);
      final loc = state.matchedLocation;
      if (!splashDone || auth.isLoading) return loc == '/splash' ? null : '/splash';
      // Welcome selalu tampil sekali pada setiap pembukaan app, sebelum login atau beranda.
      if (!welcomeSeen) return loc == '/onboarding' ? null : '/onboarding';
      if (auth.value == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash' || loc == '/onboarding') return '/';
      return null;
    },
    routes: [
      // Perpindahan besar (splash → welcome → login → beranda) memakai fade; layar lain geser kecil + fade.
      GoRoute(path: '/splash', pageBuilder: (_, s) => fadePage(key: s.pageKey, child: const SplashScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (_, s) => fadePage(key: s.pageKey, child: const OnboardingScreen())),
      GoRoute(path: '/login', pageBuilder: (_, s) => fadePage(key: s.pageKey, child: const LoginScreen())),
      GoRoute(path: '/', pageBuilder: (_, s) => fadePage(key: s.pageKey, child: const HomeShell())),
      GoRoute(
        path: '/product',
        // Tanpa extra (mis. refresh browser) kembali ke menu, bukan crash.
        redirect: (_, state) => state.extra is Product ? null : '/',
        pageBuilder: (_, state) => fadeThroughPage(key: state.pageKey, child: ProductScreen(product: state.extra as Product)),
      ),
      GoRoute(path: '/cart', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const CartScreen())),
      GoRoute(path: '/checkout', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const CheckoutScreen())),
      GoRoute(path: '/pay/:orderId', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: PayScreen(orderId: s.pathParameters['orderId']!))),
      // Tautan balik dari aplikasi e-wallet (kopiapp://payment/finish): kembali ke pesanan yang sedang dibayar.
      GoRoute(path: '/finish', redirect: (_, _) => _backToPay(ref)),
      GoRoute(path: '/payment/finish', redirect: (_, _) => _backToPay(ref)),
      GoRoute(path: '/profile/edit', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const EditProfileScreen())),
      GoRoute(path: '/inbox', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const InboxScreen())),
      GoRoute(path: '/addresses', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const AddressesScreen())),
      GoRoute(path: '/orders', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const OrdersTab())),
      GoRoute(path: '/orders/:id', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: OrderDetailScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/addresses/new', pageBuilder: (_, s) => fadeThroughPage(key: s.pageKey, child: const AddressFormScreen())),
    ],
  );
});
