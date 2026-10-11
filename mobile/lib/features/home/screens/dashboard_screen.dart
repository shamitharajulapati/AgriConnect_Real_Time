import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/mock_api_service.dart';
import '../../../core/l10n/crop_names.dart';
import '../../market/models/market_price.dart';
import '../../alerts/models/crop_alert.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final state = prefs.getString('state') ?? 'Karnataka';
    ref.read(userLocationProvider.notifier).state = state;
    ref.read(userDistrictProvider.notifier).state = prefs.getString('district') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);
    final prices = ref.watch(marketPricesProvider);
    final alerts = ref.watch(alertsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, ref, s),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Weather card
                weather.when(
                  data: (w) => _WeatherCard(weather: w, s: s).animate().fadeIn(delay: 100.ms).slideY(begin: -0.05),
                  loading: () => _shimmerBox(80),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 10),

                // Backend status banner
                _BackendBanner(ref).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 10),

                // Quick actions
                _QuickActionsGrid(context, s).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 20),

                // Top prices
                _SectionHeader(s.dashMarketPrice, s.seAll, () => context.go(AppRoutes.market)),
                const SizedBox(height: 8),
                prices.when(
                  data: (list) => _TopPricesRow(list.take(5).toList(), context, s),
                  loading: () => SizedBox(height: 110, child: _shimmerBox(110)),
                  error: (_, __) => _ErrorTile('Could not load prices', s),
                ),
                const SizedBox(height: 20),

                // Alerts
                _SectionHeader(s.navAlerts, s.seAll, () => context.go(AppRoutes.alerts)),
                const SizedBox(height: 8),
                alerts.when(
                  data: (list) => _AlertsList(list.take(3).toList(), s),
                  loading: () => _shimmerBox(200),
                  error: (_, __) => _ErrorTile('Could not load alerts', s),
                ),
                const SizedBox(height: 20),

                // Tools grid
                _SectionHeader(s.dashMoreTools, '', null),
                const SizedBox(height: 8),
                _ToolsGrid(context, s).animate().fadeIn(delay: 500.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, dynamic s) {
    return SliverAppBar(
      expandedHeight: 130,
      floating: true,
      snap: true,
      pinned: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('🌱 ', style: TextStyle(fontSize: 14)),
                          Text('${s.dashGreeting} ${_timeGreeting(s)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        ]),
                        const SizedBox(height: 2),
                        Text(s.dashTitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                      ],
                    ),
                  ),
                  _AppBarAction(Icons.record_voice_over_rounded, () => context.go(AppRoutes.voiceAssist)),
                  const SizedBox(width: 4),
                  _AppBarAction(Icons.notifications_outlined, () => context.go(AppRoutes.alerts)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.profile),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeGreeting(dynamic s) {
    final h = DateTime.now().hour;
    if (h < 12) return s.dashMorning;
    if (h < 17) return s.dashAfternoon;
    return s.dashEvening;
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarAction(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

class _WeatherCard extends StatelessWidget {
  final WeatherData weather;
  final dynamic s;
  const _WeatherCard({required this.weather, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1565C0).withValues(alpha: 0.9), const Color(0xFF42A5F5).withValues(alpha: 0.85)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Text(weather.icon, style: const TextStyle(fontSize: 38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${weather.temperature}°C  ·  ${localWeather(weather.description, s.lang)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${weather.humidity}% ${s.dashHumidity}  ·  ${s.dashGoodHarvest}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Consumer(builder: (_, ref, __) => Text(localCropName(ref.watch(userLocationProvider), ref.watch(appLangProvider)), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final BuildContext ctx;
  final dynamic s;
  const _QuickActionsGrid(this.ctx, this.s);

  List<_QA> get _actions => [
    _QA(s.navMarket, Icons.show_chart, const Color(0xFF2E7D32), AppRoutes.market),
    _QA(s.navPredict, Icons.psychology_rounded, const Color(0xFF0097A7), AppRoutes.prediction),
    _QA(s.dashSell, Icons.trending_up, const Color(0xFFF57F17), AppRoutes.profit),
    _QA(s.dashCrops, Icons.grass_rounded, const Color(0xFF6A1B9A), AppRoutes.cropReco),
    _QA(s.demandTitle, Icons.bar_chart_rounded, const Color(0xFFBF360C), AppRoutes.demand),
    _QA(s.dashCharts, Icons.analytics_rounded, const Color(0xFF00695C), AppRoutes.analytics),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.45,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: _actions.asMap().entries.map((e) {
        final a = e.value;
        return GestureDetector(
          onTap: () => ctx.go(a.route),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [a.color.withValues(alpha: 0.12), a.color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: a.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: a.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
                  child: Icon(a.icon, color: a.color, size: 19),
                ),
                const SizedBox(height: 5),
                Text(a.label, style: TextStyle(fontSize: 11, color: a.color, fontWeight: FontWeight.w700)),
              ],
            ),
          ).animate().scale(delay: Duration(milliseconds: 40 * e.key), duration: 300.ms, curve: Curves.elasticOut),
        );
      }).toList(),
    );
  }
}

class _QA {
  final String label, route;
  final IconData icon;
  final Color color;
  const _QA(this.label, this.icon, this.color, this.route);
}

class _SectionHeader extends StatelessWidget {
  final String title, actionLabel;
  final VoidCallback? onTap;
  const _SectionHeader(this.title, this.actionLabel, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const Spacer(),
        if (actionLabel.isNotEmpty && onTap != null)
          TextButton(onPressed: onTap, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(actionLabel, style: const TextStyle(color: AppColors.primary, fontSize: 12))),
      ],
    );
  }
}

class _TopPricesRow extends StatelessWidget {
  final List<MarketPrice> prices;
  final BuildContext ctx;
  final dynamic s;
  const _TopPricesRow(this.prices, this.ctx, this.s);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: prices.length,
        itemBuilder: (_, i) {
          final p = prices[i];
          final delta = p.deltaPercent;
          final isUp = p.isUp;
          final color = delta == null ? AppColors.primary : isUp ? AppColors.priceUp : AppColors.priceDown;
          return Container(
            width: 130,
            margin: EdgeInsets.only(right: 10, left: i == 0 ? 0 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_emoji(p.commodity), style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(localCropName(p.commodity, s.lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text('₹${p.modalPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                Text(s.perQuintal, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                const Spacer(),
                if (delta != null)
                  Row(children: [
                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: color),
                    Text('${delta.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                  ]),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 80 * i)).slideX(begin: 0.15);
        },
      ),
    );
  }

  String _emoji(String c) => {'Tomato': '🍅', 'Onion': '🧅', 'Potato': '🥔', 'Wheat': '🌾', 'Rice': '🌾', 'Cotton': '🌿', 'Chillies': '🌶️', 'Soybean': '🫘', 'Maize': '🌽', 'Sugarcane': '🎋'}[c] ?? '🌱';
}

class _AlertsList extends StatelessWidget {
  final List<CropAlert> alerts;
  final dynamic s;
  const _AlertsList(this.alerts, this.s);

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox();
    return Column(
      children: alerts.asMap().entries.map((e) {
        final a = e.value;
        final color = _alertColor(a.type);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(_alertIcon(a.type), color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(localCropName(a.commodity, s.lang), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text(localAlertMessage(a.type.name, a.commodity, s.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            if (!a.isRead) Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
        ).animate().fadeIn(delay: Duration(milliseconds: 60 * e.key)).slideX(begin: 0.1);
      }).toList(),
    );
  }

  Color _alertColor(AlertType t) => {
        AlertType.priceSpike: AppColors.priceUp,
        AlertType.priceTarget: AppColors.secondary,
        AlertType.demandHigh: AppColors.accent,
        AlertType.newBuyer: const Color(0xFF7B1FA2),
        AlertType.weather: const Color(0xFF0277BD),
      }[t]!;

  IconData _alertIcon(AlertType t) => {
        AlertType.priceSpike: Icons.trending_up,
        AlertType.priceTarget: Icons.flag_rounded,
        AlertType.demandHigh: Icons.bar_chart,
        AlertType.newBuyer: Icons.person_add,
        AlertType.weather: Icons.cloud,
      }[t]!;
}

class _ToolsGrid extends StatelessWidget {
  final BuildContext ctx;
  final dynamic s;
  const _ToolsGrid(this.ctx, this.s);

  @override
  Widget build(BuildContext context) {
    final tools = [
      _Tool('🎤  ${s.dashVoiceAss}', AppColors.primary, AppRoutes.voiceAssist),
      _Tool('💬  ${s.dashChatBuyers}', const Color(0xFF7B1FA2), AppRoutes.chatList),
      _Tool('📊  ${s.demandTitle}', AppColors.accent, AppRoutes.demand),
      _Tool('🔔  ${s.dashSetAlerts}', AppColors.secondary, AppRoutes.alerts),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: tools.asMap().entries.map((e) {
        final t = e.value;
        return GestureDetector(
          onTap: () => ctx.go(t.route),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.color.withValues(alpha: 0.1), t.color.withValues(alpha: 0.04)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.color.withValues(alpha: 0.2)),
            ),
            child: Text(t.label, style: TextStyle(fontSize: 12, color: t.color, fontWeight: FontWeight.w600)),
          ).animate().fadeIn(delay: Duration(milliseconds: 60 * e.key)),
        );
      }).toList(),
    );
  }
}

class _Tool {
  final String label, route;
  final Color color;
  const _Tool(this.label, this.color, this.route);
}

// ── Backend Status Banner ──────────────────────────────────────────────────

class _BackendBanner extends StatelessWidget {
  final WidgetRef ref;
  const _BackendBanner(this.ref);

  @override
  Widget build(BuildContext context) {
    final isLive = AppConfig.isSupabaseConfigured;
    final isMlLive = AppConfig.isMlConfigured;

    if (isLive && isMlLive) return const SizedBox(); // fully live — hide banner

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLive ? Colors.blue.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLive ? Colors.blue.withValues(alpha: 0.25) : Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(isLive ? Icons.cloud_done : Icons.cloud_off_outlined,
            size: 15, color: isLive ? Colors.blue : Colors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(
          isLive
              ? '🟢 Supabase connected · ML service not configured'
              : '🟡 Demo Mode — Add Supabase keys to go live',
          style: TextStyle(fontSize: 11, color: isLive ? Colors.blue.shade700 : Colors.orange.shade700, fontWeight: FontWeight.w500),
        )),
        GestureDetector(
          onTap: () => _showConfigDialog(context),
          child: Icon(Icons.settings_outlined, size: 15, color: isLive ? Colors.blue : Colors.orange),
        ),
      ]),
    );
  }

  void _showConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backend Configuration'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ConfigRow('Supabase', AppConfig.isSupabaseConfigured),
          _ConfigRow('ML Service', AppConfig.isMlConfigured),
          _ConfigRow('OpenWeather', AppConfig.openWeatherKey.isNotEmpty && !AppConfig.openWeatherKey.contains('YOUR_')),
          _ConfigRow('Agmarknet sync service', AppConfig.isMlConfigured),
          const SizedBox(height: 12),
          const Text('The Agmarknet API key and Supabase service-role key stay on the server.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final bool connected;
  const _ConfigRow(this.label, this.connected);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(connected ? Icons.check_circle : Icons.cancel_outlined, size: 16, color: connected ? Colors.green : Colors.grey),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      Text(connected ? 'Connected' : 'Not set', style: TextStyle(fontSize: 11, color: connected ? Colors.green : Colors.grey)),
    ]),
  );
}

class _ErrorTile extends StatelessWidget {
  final String msg;
  final dynamic s;
  const _ErrorTile(this.msg, this.s);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
        child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12))]),
      );
}

Widget _shimmerBox(double height) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200], stops: const [0, 0.5, 1]),
      borderRadius: BorderRadius.circular(12),
    ),
  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.4));
}
