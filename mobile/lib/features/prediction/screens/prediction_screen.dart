import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../../../widgets/demo_data_notice.dart';
import '../models/price_prediction.dart';
import '../../../core/l10n/crop_names.dart';

class PredictionScreen extends ConsumerWidget {
  const PredictionScreen({super.key});

  static const _commodities = ['Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Chillies', 'Soybean'];
  static const _horizons = [7, 14, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commodity = ref.watch(selectedCommodityProvider);
    final horizon = ref.watch(selectedHorizonProvider);
    final prediction = ref.watch(predictionProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.dashAiPredict)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Selector card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.predSelectCrop, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _commodities.map((c) {
                    final sel = c == commodity;
                    return ChoiceChip(
                      label: Text(localCropName(c, s.lang)),
                      selected: sel,
                      onSelected: (_) => ref.read(selectedCommodityProvider.notifier).state = c,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textPrimary, fontSize: 12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Text('${s.predHorizon}: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ..._horizons.map((d) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text('$d ${s.predDays}'),
                      selected: horizon == d,
                      onSelected: (_) => ref.read(selectedHorizonProvider.notifier).state = d,
                      selectedColor: AppColors.secondary,
                      labelStyle: TextStyle(color: horizon == d ? Colors.white : AppColors.textPrimary, fontSize: 12),
                    ),
                  )),
                ]),
              ]),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          // Prediction result
          prediction.when(
            data: (pred) => pred.points.isEmpty
                ? _ErrorCard(onRetry: () => ref.invalidate(predictionProvider))
                : Column(children: [
              if (pred.isDemo) const DemoDataNotice(),
              _ChartCard(pred: pred, horizon: horizon).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06),
              const SizedBox(height: 14),
              _StatsRow(pred: pred, horizon: horizon).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 14),
              _ForecastTable(pred: pred).animate().fadeIn(delay: 350.ms),
            ]),
            loading: () => Column(children: [
              _LoadingChart(),
              const SizedBox(height: 14),
              _shimmer(60),
              const SizedBox(height: 14),
              _shimmer(200),
            ]),
            error: (e, _) => _ErrorCard(onRetry: () => ref.invalidate(predictionProvider)),
          ),
        ]),
      ),
    );
  }
}

class _ChartCard extends ConsumerWidget {
  final PricePrediction pred;
  final int horizon;
  const _ChartCard({required this.pred, required this.horizon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final pts = pred.points.take(horizon).toList();
    final meanSpots = pts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.price)).toList();
    final upperSpots = pts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.upperBound)).toList();
    final lowerSpots = pts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.lowerBound)).toList();
    final minY = pts.map((p) => p.lowerBound).reduce((a, b) => a < b ? a : b) * 0.97;
    final maxY = pts.map((p) => p.upperBound).reduce((a, b) => a > b ? a : b) * 1.03;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${localCropName(pred.commodity, s.lang)} ${s.predForecast}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${s.predNext} $horizon ${s.predDays} · ${s.mktModal}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.psychology_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${(pred.confidence * 100).toStringAsFixed(0)}% ${s.predConfident}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              minY: minY, maxY: maxY,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: horizon <= 7 ? 1 : 2,
                    getTitlesWidget: (v, _) => Text('D${v.toInt() + 1}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)))),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 58,
                    getTitlesWidget: (v, _) => Text('₹${v.toInt()}', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: upperSpots, isCurved: true, color: Colors.transparent,
                    belowBarData: BarAreaData(show: true, color: AppColors.chartBand), dotData: const FlDotData(show: false)),
                LineChartBarData(spots: lowerSpots, isCurved: true, color: Colors.transparent, dotData: const FlDotData(show: false)),
                LineChartBarData(spots: meanSpots, isCurved: true, color: AppColors.chartLine, barWidth: 2.5,
                    dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) => FlDotCirclePainter(radius: i == pts.length - 1 ? 5 : 2.5, color: AppColors.chartLine, strokeWidth: 0)),
                    shadow: Shadow(color: AppColors.chartLine.withValues(alpha: 0.3), blurRadius: 6)),
              ],
            )),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _Legend(AppColors.chartLine, s.predPredicted),
            const SizedBox(width: 16),
            _Legend(AppColors.chartBand, s.predConfBand),
          ]),
        ]),
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  final PricePrediction pred;
  final int horizon;
  const _StatsRow({required this.pred, required this.horizon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final pts = pred.points.take(horizon).toList();
    final prices = pts.map((p) => p.price).toList();
    final minP = prices.reduce((a, b) => a < b ? a : b);
    final maxP = prices.reduce((a, b) => a > b ? a : b);
    final avgP = prices.reduce((a, b) => a + b) / prices.length;
    return Row(children: [
      _StatBox(s.predAvg, '₹${avgP.toStringAsFixed(0)}', Icons.analytics, AppColors.primary),
      const SizedBox(width: 10),
      _StatBox(s.predMin, '₹${minP.toStringAsFixed(0)}', Icons.south, AppColors.priceDown),
      const SizedBox(width: 10),
      _StatBox(s.predMax, '₹${maxP.toStringAsFixed(0)}', Icons.north, AppColors.priceUp),
    ]);
  }
}

class _ForecastTable extends ConsumerWidget {
  final PricePrediction pred;
  const _ForecastTable({required this.pred});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final pts = pred.points.take(7).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.predDetail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(s.predDay, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
            Expanded(child: Text(s.predLow, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.priceDown))),
            Expanded(child: Text(s.predPredicted, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary))),
            Expanded(child: Text(s.predHigh, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.priceUp))),
          ]),
          const Divider(height: 12),
          ...pts.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text('${s.predDay} ${e.key + 1}', style: const TextStyle(fontSize: 12))),
              Expanded(child: Text('₹${e.value.lowerBound.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.priceDown))),
              Expanded(child: Text('₹${e.value.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))),
              Expanded(child: Text('₹${e.value.upperBound.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.priceUp))),
            ]).animate().fadeIn(delay: Duration(milliseconds: 40 * e.key)),
          )),
        ]),
      ),
    );
  }
  
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(icon, color: color, size: 18), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))]))));
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 14, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))]);
}

class _LoadingChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Card(child: SizedBox(height: 260, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
    const SizedBox(height: 14),
    Text(s.predLoading, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  ]))));
  }
}

class _ErrorCard extends ConsumerWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    const Icon(Icons.error_outline, color: Colors.red, size: 40),
    const SizedBox(height: 8),
    Text(s.predFailed, style: const TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    ElevatedButton(onPressed: onRetry, child: Text(s.retry)),
  ])));
  }
}

Widget _shimmer(double h) => Container(
  height: h, margin: const EdgeInsets.only(bottom: 2),
  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5));
