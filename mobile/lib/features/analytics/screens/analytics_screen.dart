import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../../market/models/market_price.dart';
import 'dart:math';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Prices'),
            Tab(text: 'Earnings'),
            Tab(text: 'Market Share'),
            Tab(text: 'Compare'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _PriceTrendTab(),
          _EarningsTab(),
          _MarketShareTab(),
          _CompareCropsTab(),
        ],
      ),
    );
  }
}

class _PriceTrendTab extends ConsumerWidget {
  const _PriceTrendTab();

  static const _crops = ['Tomato', 'Onion', 'Potato'];
  static const _colors = [AppColors.primary, AppColors.secondary, AppColors.accent];

  List<FlSpot> _toSpots(List<double> history) =>
      List.generate(history.length, (i) => FlSpot(i.toDouble(), history[i]));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histories = _crops.map((c) => ref.watch(priceHistoryProvider(c))).toList();
    final loaded = histories.every((h) => h.hasValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('30-Day Price Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Tomato vs Onion vs Potato', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: !loaded
                        ? const Center(child: CircularProgressIndicator())
                        : LineChart(LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  if (v.toInt() % 7 != 0) return const SizedBox();
                                  return Text('D${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary));
                                },
                              )),
                              leftTitles: AxisTitles(sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 55,
                                getTitlesWidget: (v, _) => Text('₹${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                              )),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: List.generate(_crops.length, (i) => LineChartBarData(
                                  spots: _toSpots(histories[i].value ?? []),
                                  color: _colors[i],
                                  barWidth: 2.5,
                                  isCurved: true,
                                  dotData: const FlDotData(show: false),
                                )),
                          )),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_crops.length, (i) => Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
                          child: _Legend(_colors[i], _crops[i]),
                        )),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 16),
          const _SummaryCards(),
        ],
      ),
    );
  }
}

class _EarningsTab extends StatelessWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context) {
    final rng = Random(99);
    final monthlyEarnings = List.generate(6, (i) => 8000.0 + rng.nextDouble() * 12000);
    final months = ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Illustrative projection — sales tracking not yet implemented', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('Total: ₹${monthlyEarnings.reduce((a, b) => a + b).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(BarChartData(
                      barGroups: monthlyEarnings.asMap().entries.map((e) => BarChartGroupData(
                            x: e.key,
                            barRods: [BarChartRodData(
                              toY: e.value,
                              gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              width: 32,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            )],
                          )).toList(),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(months[v.toInt()], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 55, getTitlesWidget: (v, _) => Text('₹${(v / 1000).toInt()}K', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)))),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                    )),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
  }
}

class _MarketShareTab extends ConsumerWidget {
  const _MarketShareTab();

  static const _palette = [
    AppColors.primary, AppColors.secondary, AppColors.accent,
    Color(0xFF7B1FA2), Color(0xFFE65100), Color(0xFF00838F), Color(0xFF5D4037),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(analyticsMarketPricesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Commodity Market Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Share of active mandi listings by commodity', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 20),
              SizedBox(
                height: 260,
                child: pricesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Unable to load market data')),
                  data: (prices) {
                    if (prices.isEmpty) return const Center(child: Text('No market data available'));
                    final counts = <String, int>{};
                    for (final p in prices) {
                      counts[p.commodity] = (counts[p.commodity] ?? 0) + 1;
                    }
                    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                    final total = prices.length;
                    final top = sorted.take(5).toList();
                    final otherCount = sorted.skip(5).fold<int>(0, (s, e) => s + e.value);

                    final sections = <PieChartSectionData>[];
                    for (var i = 0; i < top.length; i++) {
                      final pct = (top[i].value / total * 100);
                      sections.add(PieChartSectionData(
                        value: top[i].value.toDouble(),
                        color: _palette[i % _palette.length],
                        title: '${top[i].key}\n${pct.toStringAsFixed(0)}%',
                        radius: 70,
                        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ));
                    }
                    if (otherCount > 0) {
                      final pct = (otherCount / total * 100);
                      sections.add(PieChartSectionData(
                        value: otherCount.toDouble(),
                        color: _palette[top.length % _palette.length],
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: 70,
                        titleStyle: const TextStyle(color: Colors.white, fontSize: 10),
                      ));
                    }

                    return PieChart(PieChartData(
                      sections: sections,
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      startDegreeOffset: -90,
                    ));
                  },
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareCropsTab extends ConsumerWidget {
  const _CompareCropsTab();
  static const _crops = ['Tomato', 'Onion', 'Potato', 'Wheat'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histories = _crops.map((c) => ref.watch(priceHistoryProvider(c))).toList();
    final loaded = histories.every((h) => h.hasValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current vs 30 Days Ago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: !loaded
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(builder: (context) {
                        final current = <double>[];
                        final previous = <double>[];
                        for (final h in histories) {
                          final v = h.value ?? [];
                          previous.add(v.isNotEmpty ? v.first : 0);
                          current.add(v.isNotEmpty ? v.last : 0);
                        }
                        return BarChart(BarChartData(
                          barGroups: _crops.asMap().entries.map((e) => BarChartGroupData(
                                x: e.key,
                                barsSpace: 4,
                                barRods: [
                                  BarChartRodData(toY: current[e.key], color: AppColors.primary, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                  BarChartRodData(toY: previous[e.key], color: AppColors.primaryLight.withOpacity(0.5), width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                ],
                              )).toList(),
                          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1)),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(_crops[v.toInt()], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 55, getTitlesWidget: (v, _) => Text('₹${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)))),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                        ));
                      }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Legend(AppColors.primary, 'Current'),
                  const SizedBox(width: 16),
                  _Legend(AppColors.primaryLight.withOpacity(0.5), '30 Days Ago'),
                ],
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }
}

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(analyticsMarketPricesProvider);

    return pricesAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<MarketPrice> prices) {
        if (prices.isEmpty) return const SizedBox.shrink();

        final byCommodity = <String, List<double>>{};
        final markets = <String>{};
        for (final p in prices) {
          byCommodity.putIfAbsent(p.commodity, () => []).add(p.modalPrice);
          markets.add(p.market);
        }
        final avgByCommodity = byCommodity.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
        final bestCrop = avgByCommodity.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        final overallAvg = prices.map((p) => p.modalPrice).reduce((a, b) => a + b) / prices.length;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _StatCard('Highest Priced', bestCrop, Icons.trending_up, AppColors.priceUp),
            _StatCard('Avg Price', '₹${overallAvg.toStringAsFixed(0)}', Icons.analytics, AppColors.primary),
            _StatCard('Markets', '${markets.length} Active', Icons.store, AppColors.secondary),
            _StatCard('Commodities', '${byCommodity.length} Tracked', Icons.eco, AppColors.accent),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 4, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
