import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../../../widgets/demo_data_notice.dart';
import '../../market/models/market_price.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
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
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Prices'),
            Tab(text: 'Prices by Crop'),
            Tab(text: 'Market Share'),
            Tab(text: 'Compare'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _PriceTrendTab(),
          _AveragePricesTab(),
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
  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
  ];

  List<FlSpot> _toSpots(List<double> history) =>
      List.generate(history.length, (i) => FlSpot(i.toDouble(), history[i]));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histories = _crops
        .map((c) => ref.watch(priceHistoryProvider(c)))
        .toList();
    final failed = histories.any((h) => h.hasError);
    final loaded = histories.every((h) => h.hasValue || h.hasError);
    final availableIndexes = loaded
        ? List.generate(
            _crops.length,
            (i) => i,
          ).where((i) => (histories[i].value?.values ?? []).isNotEmpty).toList()
        : <int>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (histories.any((history) => history.value?.isDemo ?? false))
            const DemoDataNotice(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price Trend',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tomato vs Onion vs Potato · averaged by observation date',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: failed
                        ? _HistoryErrorState(
                            onRetry: () {
                              for (final crop in _crops) {
                                ref.invalidate(priceHistoryProvider(crop));
                              }
                            },
                          )
                        : !loaded
                        ? const Center(child: CircularProgressIndicator())
                        : availableIndexes.isEmpty
                        ? const SizedBox.shrink()
                        : availableIndexes.every(
                            (i) => histories[i].value!.values.length < 2,
                          )
                        ? _SinglePricesCard(
                            entries: availableIndexes
                                .map((i) => (
                                  _crops[i],
                                  histories[i].value!.values.last,
                                ))
                                .toList(),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                  color: Color(0xFFEEEEEE),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      if (v.toInt() % 7 != 0) {
                                        return const SizedBox();
                                      }
                                      return Text(
                                        'D${v.toInt()}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textSecondary,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 55,
                                    getTitlesWidget: (v, _) => Text(
                                      '₹${v.toInt()}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: availableIndexes
                                  .map(
                                    (i) => LineChartBarData(
                                      spots: _toSpots(
                                        histories[i].value!.values,
                                      ),
                                      color: _colors[i],
                                      barWidth: 2.5,
                                      isCurved: true,
                                      dotData: const FlDotData(show: true),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: availableIndexes
                        .map(
                          (i) => Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
                            child: _Legend(_colors[i], _crops[i]),
                          ),
                        )
                        .toList(),
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

class _AveragePricesTab extends ConsumerWidget {
  const _AveragePricesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(analyticsMarketPricesProvider);
    return prices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: IconButton(
          tooltip: 'Refresh market prices',
          onPressed: () => ref.invalidate(analyticsMarketPricesProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (rows) {
        final byCrop = <String, List<MarketPrice>>{};
        for (final row in rows) {
          (byCrop[row.commodity] ??= []).add(row);
        }
        final entries = byCrop.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        if (entries.isEmpty) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Average modal prices from your market records',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
            ...entries.map((entry) {
              final values = entry.value.map((p) => p.modalPrice).toList();
              final average = values.reduce((a, b) => a + b) / values.length;
              final low = values.reduce((a, b) => a < b ? a : b);
              final high = values.reduce((a, b) => a > b ? a : b);
              return Card(
                child: ListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    '${entry.value.length} markets · ₹${low.toStringAsFixed(0)}–₹${high.toStringAsFixed(0)} / quintal',
                  ),
                  trailing: Text(
                    '₹${average.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MarketShareTab extends ConsumerWidget {
  const _MarketShareTab();

  static const _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    Color(0xFF7B1FA2),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFF5D4037),
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
              const Text(
                'Commodity Market Share',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Share of active mandi listings by commodity',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 260,
                child: pricesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Center(child: Text('Unable to load market data')),
                  data: (prices) {
                    if (prices.isEmpty) {
                      return const Center(
                        child: Text('No market data available'),
                      );
                    }
                    final counts = <String, int>{};
                    for (final p in prices) {
                      counts[p.commodity] = (counts[p.commodity] ?? 0) + 1;
                    }
                    final sorted = counts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final total = prices.length;
                    final top = sorted.take(5).toList();
                    final otherCount = sorted
                        .skip(5)
                        .fold<int>(0, (s, e) => s + e.value);

                    final sections = <PieChartSectionData>[];
                    for (var i = 0; i < top.length; i++) {
                      final pct = (top[i].value / total * 100);
                      sections.add(
                        PieChartSectionData(
                          value: top[i].value.toDouble(),
                          color: _palette[i % _palette.length],
                          title: '${top[i].key}\n${pct.toStringAsFixed(0)}%',
                          radius: 70,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    if (otherCount > 0) {
                      final pct = (otherCount / total * 100);
                      sections.add(
                        PieChartSectionData(
                          value: otherCount.toDouble(),
                          color: _palette[top.length % _palette.length],
                          title: '${pct.toStringAsFixed(0)}%',
                          radius: 70,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }

                    return PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 3,
                        centerSpaceRadius: 50,
                        startDegreeOffset: -90,
                      ),
                    );
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
    final histories = _crops
        .map((c) => ref.watch(priceHistoryProvider(c)))
        .toList();
    final failed = histories.any((h) => h.hasError);
    final loaded = histories.every((h) => h.hasValue || h.hasError);
    final availableIndexes = loaded
        ? List.generate(
            _crops.length,
            (i) => i,
          ).where((i) => (histories[i].value?.values ?? []).isNotEmpty).toList()
        : <int>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (histories.any((history) => history.value?.isDemo ?? false))
            const DemoDataNotice(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price Comparison',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: failed
                        ? _HistoryErrorState(
                            onRetry: () {
                              for (final crop in _crops) {
                                ref.invalidate(priceHistoryProvider(crop));
                              }
                            },
                          )
                        : !loaded
                        ? const Center(child: CircularProgressIndicator())
                        : availableIndexes.isEmpty
                        ? const SizedBox.shrink()
                        : availableIndexes.every(
                            (i) => histories[i].value!.values.length < 2,
                          )
                        ? _SinglePricesCard(
                            entries: availableIndexes
                                .map((i) => (
                                  _crops[i],
                                  histories[i].value!.values.last,
                                ))
                                .toList(),
                          )
                        : Builder(
                            builder: (context) {
                              final current = <double>[];
                              final previous = <double>[];
                              for (final i in availableIndexes) {
                                final v = histories[i].value!;
                                previous.add(
                                  v.values.length > 1
                                      ? v.values.first
                                      : double.nan,
                                );
                                current.add(v.values.last);
                              }
                              return BarChart(
                                BarChartData(
                                  barGroups: availableIndexes
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => BarChartGroupData(
                                          x: e.key,
                                          barsSpace: 4,
                                          barRods: [
                                            BarChartRodData(
                                              toY: current[e.key],
                                              color: AppColors.primary,
                                              width: 16,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(4),
                                                  ),
                                            ),
                                            if (previous[e.key].isFinite)
                                              BarChartRodData(
                                                toY: previous[e.key],
                                                color: AppColors.primaryLight
                                                    .withOpacity(0.5),
                                                width: 16,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(4),
                                                    ),
                                              ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (_) =>
                                        const FlLine(
                                          color: Color(0xFFEEEEEE),
                                          strokeWidth: 1,
                                        ),
                                  ),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (v, _) {
                                          final index = v.toInt();
                                          if (index < 0 ||
                                              index >=
                                                  availableIndexes.length) {
                                            return const SizedBox.shrink();
                                          }
                                          return Text(
                                            _crops[availableIndexes[index]],
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 55,
                                        getTitlesWidget: (v, _) => Text(
                                          '₹${v.toInt()}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Legend(AppColors.primary, 'Current'),
                      if (histories.any(
                        (h) => (h.value?.values.length ?? 0) > 1,
                      )) ...[
                        const SizedBox(width: 16),
                        _Legend(
                          AppColors.primaryLight.withOpacity(0.5),
                          'Earlier',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(analyticsMarketPricesProvider);

    return pricesAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<MarketPrice> prices) {
        if (prices.isEmpty) return const SizedBox.shrink();

        final byCommodity = <String, List<double>>{};
        final markets = <String>{};
        for (final p in prices) {
          byCommodity.putIfAbsent(p.commodity, () => []).add(p.modalPrice);
          markets.add(p.market);
        }
        final avgByCommodity = byCommodity.map(
          (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length),
        );
        final bestCrop = avgByCommodity.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        final overallAvg =
            prices.map((p) => p.modalPrice).reduce((a, b) => a + b) /
            prices.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            final cardWidth =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  height: 92,
                  child: _StatCard(
                    'Highest Avg Price',
                    bestCrop,
                    Icons.trending_up,
                    AppColors.priceUp,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 92,
                  child: _StatCard(
                    'Avg Price / quintal',
                    '₹${overallAvg.toStringAsFixed(0)}',
                    Icons.analytics,
                    AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 92,
                  child: _StatCard(
                    'Markets',
                    '${markets.length} Active',
                    Icons.store,
                    AppColors.secondary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 92,
                  child: _StatCard(
                    'Commodities',
                    '${byCommodity.length} Tracked',
                    Icons.eco,
                    AppColors.accent,
                  ),
                ),
              ],
            );
          },
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
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _HistoryErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      tooltip: 'Refresh prices',
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
    ),
  );
}

class _SinglePricesCard extends StatelessWidget {
  final List<(String, double)> entries;
  const _SinglePricesCard({required this.entries});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.$1),
                Text(
                  '₹${entry.$2.toStringAsFixed(0)} / quintal',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}
