import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../../../services/mock_api_service.dart' show DemandResult;
import '../../../widgets/demo_data_notice.dart';

class DemandScreen extends ConsumerStatefulWidget {
  const DemandScreen({super.key});

  @override
  ConsumerState<DemandScreen> createState() => _DemandScreenState();
}

class _DemandScreenState extends ConsumerState<DemandScreen> {
  String _selectedCrop = 'Tomato';
  bool _loading = true;
  String? _error;
  DemandResult? _data;

  static const _crops = ['Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Chillies'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(apiProvider).fetchDemand(
        _selectedCrop,
        state: ref.read(userLocationProvider),
      );
      setState(() { _data = result; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not load demand data. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.demandTitle)),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _crops.map((c) {
                  final sel = c == _selectedCrop;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { setState(() => _selectedCrop = c); _load(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? Colors.white : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(c, style: TextStyle(color: sel ? AppColors.primary : Colors.white, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_data!.isDemo) const DemoDataNotice(),
                        _DemandIndexCard(data: _data!).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        const _MarketProxyNote(),
                        _DemandChartCard(data: _data!).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        const SizedBox(height: 16),
                        _RegionalDemandCard(data: _data!).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DemandIndexCard extends ConsumerWidget {
  final DemandResult data;
  const _DemandIndexCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final colors = {'HIGH': AppColors.highDemand, 'MEDIUM': AppColors.medDemand, 'LOW': AppColors.lowDemand};
    final color = colors[data.demandLevel]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.commodity, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text('${data.demandLevel} ${s.demDemand}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(data.trend == 'RISING' ? Icons.trending_up : Icons.trending_down, size: 16, color: data.trend == 'RISING' ? AppColors.priceUp : AppColors.priceDown),
                    const SizedBox(width: 4),
                    Text('${data.trend} • ${s.demPeakDays.replaceAll('{n}', '${data.peakDays}')}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: data.demandIndex,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeWidth: 8,
                  ),
                  Text('${(data.demandIndex * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketProxyNote extends StatelessWidget {
  const _MarketProxyNote();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Estimated market activity based on recent Agmarknet price records; buyer orders are not measured.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
}

class _DemandChartCard extends ConsumerWidget {
  final DemandResult data;
  const _DemandChartCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dem7Day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  barGroups: data.weeklyDemand.asMap().entries.map((e) => BarChartGroupData(
                        x: e.key,
                        barRods: [BarChartRodData(toY: e.value, color: AppColors.primary.withOpacity(0.3 + e.key / 10), width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
                      )).toList(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][v.toInt()], style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)))),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionalDemandCard extends ConsumerWidget {
  final DemandResult data;
  const _RegionalDemandCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.demRegional, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...data.regions.asMap().entries.map((e) {
              final d = e.value;
              final color = d.demand > 0.7 ? AppColors.highDemand : d.demand > 0.4 ? AppColors.medDemand : AppColors.lowDemand;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(d.region, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text('${(d.demand * 100).toInt()}%', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: d.demand,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 60 * e.key)).slideX(begin: 0.1);
            }),
          ],
        ),
      ),
    );
  }
}
