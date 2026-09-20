import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/home/screens/dashboard_screen.dart';
import '../../features/market/screens/market_screen.dart';
import '../../features/prediction/screens/prediction_screen.dart';
import '../../features/profit/screens/profit_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/demand/screens/demand_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/crop_reco/screens/crop_reco_screen.dart';
import '../../features/voice/screens/voice_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/language_screen.dart';

// ChangeNotifier that GoRouter listens to — avoids recreating the router on auth changes
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
  bool get isAuthenticated => _ref.read(authStateProvider).isAuthenticated;
  AuthStatus get status => _ref.read(authStateProvider).status;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.isAuthenticated;
      final loc = state.matchedLocation;

      // Never redirect away from splash — splash handles its own navigation
      if (loc == '/') return null;

      final isAuthRoute = loc.startsWith('/onboarding') ||
          loc.startsWith('/login') ||
          loc.startsWith('/otp') ||
          loc.startsWith('/register');

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, s) => _fade(s, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, s) => _slide(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, s) => _fade(s, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        pageBuilder: (_, s) => _slide(s, OtpScreen(
          email: s.uri.queryParameters['email'] ?? s.extra as String? ?? '',
        )),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (_, s) => _slide(s, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.languageSelect,
        pageBuilder: (_, s) => _slide(s, const LanguageScreen()),
      ),
      ShellRoute(
        pageBuilder: (_, __, child) => NoTransitionPage(child: HomeShell(child: child)),
        routes: [
          GoRoute(path: AppRoutes.home, pageBuilder: (_, s) => _fade(s, const DashboardScreen())),
          GoRoute(path: AppRoutes.market, pageBuilder: (_, s) => _fade(s, const MarketScreen())),
          GoRoute(path: AppRoutes.prediction, pageBuilder: (_, s) => _fade(s, const PredictionScreen())),
          GoRoute(path: AppRoutes.profit, pageBuilder: (_, s) => _fade(s, const ProfitScreen())),
          GoRoute(path: AppRoutes.chatList, pageBuilder: (_, s) => _fade(s, const ChatListScreen())),
          GoRoute(
            path: AppRoutes.chatRoom,
            pageBuilder: (_, s) => _slide(s, ChatRoomScreen(roomId: s.pathParameters['roomId']!)),
          ),
          GoRoute(path: AppRoutes.alerts, pageBuilder: (_, s) => _fade(s, const AlertsScreen())),
          GoRoute(path: AppRoutes.demand, pageBuilder: (_, s) => _fade(s, const DemandScreen())),
          GoRoute(path: AppRoutes.analytics, pageBuilder: (_, s) => _fade(s, const AnalyticsScreen())),
          GoRoute(path: AppRoutes.cropReco, pageBuilder: (_, s) => _fade(s, const CropRecoScreen())),
          GoRoute(path: AppRoutes.voiceAssist, pageBuilder: (_, s) => _slide(s, const VoiceScreen())),
          GoRoute(path: AppRoutes.profile, pageBuilder: (_, s) => _fade(s, const ProfileScreen())),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, c) => FadeTransition(opacity: anim, child: c),
    );

CustomTransitionPage<void> _slide(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, anim, __, c) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: c,
      ),
    );
