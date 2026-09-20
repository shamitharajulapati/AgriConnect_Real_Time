import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _pages = [
    _OnboardPage(
      icon: Icons.show_chart,
      color: AppColors.primary,
      title: 'Live Market Prices',
      subtitle: 'Get real-time mandi prices\nfrom 600+ markets across India',
      emoji: '📈',
    ),
    _OnboardPage(
      icon: Icons.psychology,
      color: AppColors.accent,
      title: 'AI Price Predictions',
      subtitle: 'ML-powered 14-day forecasts\nwith confidence intervals',
      emoji: '🤖',
    ),
    _OnboardPage(
      icon: Icons.record_voice_over,
      color: AppColors.secondary,
      title: 'Voice Assistant',
      subtitle: 'Ask in Hindi, Telugu, Tamil\nand 8 more Indian languages',
      emoji: '🎤',
    ),
    _OnboardPage(
      icon: Icons.chat_bubble,
      color: const Color(0xFF7B1FA2),
      title: 'Connect with Buyers',
      subtitle: 'Chat directly with buyers\nGet the best price for your crop',
      emoji: '🤝',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageContent(page: _pages[i], isActive: i == _page),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : AppColors.primaryLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () {
                  if (_page < _pages.length - 1) {
                    _ctrl.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    context.go(AppRoutes.login);
                  }
                },
                child: Text(_page < _pages.length - 1 ? 'Next' : 'Get Started'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String emoji;

  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.emoji,
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  final bool isActive;

  const _PageContent({required this.page, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            width: isActive ? 160 : 130,
            height: isActive ? 160 : 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [page.color.withOpacity(0.15), page.color.withOpacity(0.05)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: page.color.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(page.emoji, style: const TextStyle(fontSize: 48)),
                Icon(page.icon, color: page.color, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ).animate(target: isActive ? 1 : 0).fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate(target: isActive ? 1 : 0).fadeIn(delay: 100.ms),
        ],
      ),
    );
  }
}
