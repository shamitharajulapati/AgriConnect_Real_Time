import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import '../../../services/providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  void _onTap(int i, List<_Tab> tabs) {
    context.go(tabs[i].route);
  }

  // The bottom nav's highlight must reflect wherever the app actually is,
  // not just where the last bottom-nav tap sent it — dashboard tiles, "See
  // All" links, and deep links all navigate without going through _onTap.
  int _indexForLocation(String location, List<_Tab> tabs) {
    // Longest matching route prefix wins, so e.g. /home/chats/:roomId still
    // highlights the Chat tab rather than falling through to Home.
    var bestIndex = 0;
    var bestLength = -1;
    for (var i = 0; i < tabs.length; i++) {
      final route = tabs[i].route;
      final matches = route == AppRoutes.home ? location == route : location.startsWith(route);
      if (matches && route.length > bestLength) {
        bestIndex = i;
        bestLength = route.length;
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final tabs = [
      _Tab(Icons.dashboard_rounded, Icons.dashboard_outlined, s.navHome, AppRoutes.home),
      _Tab(Icons.show_chart, Icons.show_chart, s.navMarket, AppRoutes.market),
      _Tab(Icons.psychology_rounded, Icons.psychology_outlined, s.navPredict, AppRoutes.prediction),
      _Tab(Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, s.navChat, AppRoutes.chatList),
      _Tab(Icons.notifications_rounded, Icons.notifications_outlined, s.navAlerts, AppRoutes.alerts),
    ];
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexForLocation(location, tabs);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _BottomBar(selectedIndex: selectedIndex, tabs: tabs, onTap: (i) => _onTap(i, tabs)),
    );
  }
}

class _Tab {
  final IconData activeIcon, icon;
  final String label, route;
  const _Tab(this.activeIcon, this.icon, this.label, this.route);
}

class _BottomBar extends StatelessWidget {
  final int selectedIndex;
  final List<_Tab> tabs;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.selectedIndex, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
          height: 52,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = i == selectedIndex;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: sel ? 1 : 0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    builder: (_, t, __) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Color.lerp(Colors.transparent, AppColors.primary.withValues(alpha: 0.12), t),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sel ? tab.activeIcon : tab.icon,
                              color: Color.lerp(AppColors.textSecondary, AppColors.primary, t),
                              size: 22),
                          if (sel) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(tab.label,
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        ),
      ),
    );
  }
}
