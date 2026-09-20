import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _leafCtrl;

  @override
  void initState() {
    super.initState();
    _leafCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    // Listen for future changes
    ref.listenManual(authStateProvider, (_, next) {
      _navigate(next.status);
    });
    // Also check current value (may already be resolved)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigate(ref.read(authStateProvider).status);
    });
  }

  void _navigate(AuthStatus status) {
    if (!mounted) return;
    if (status == AuthStatus.authenticated) {
      context.go(AppRoutes.home);
    } else if (status == AuthStatus.newUser) {
      context.go(AppRoutes.register);
    } else if (status == AuthStatus.unauthenticated) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) context.go(AppRoutes.onboarding);
      });
    }
  }

  @override
  void dispose() {
    _leafCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradient1, AppColors.gradient2],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Animated logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.eco, size: 64, color: Colors.white),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              const Text(
                'AgriConnect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              )
                  .animate()
                  .slideY(begin: 0.3, duration: 500.ms, delay: 200.ms, curve: Curves.easeOut)
                  .fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Farmer Market Intelligence',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms),
              const Spacer(flex: 2),
              // Animated loading dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => _Dot(delay: Duration(milliseconds: i * 200))),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 16),
              Text(
                'किसान की शक्ति, बाज़ार की जानकारी',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 8,
        height: 8 + _ctrl.value * 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5 + _ctrl.value * 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
