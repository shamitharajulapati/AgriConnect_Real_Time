import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../../../services/mock_api_service.dart';
import '../../../widgets/demo_data_notice.dart';

class ProfitScreen extends ConsumerWidget {
  const ProfitScreen({super.key});

  static const _crops = ['Tomato', 'Onion', 'Wheat', 'Cotton', 'Rice'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commodity = ref.watch(profitCommodityProvider);
    final advice = ref.watch(profitAdviceProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.profitTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.profSelectCrop, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _crops.map((c) => ChoiceChip(
                    label: Text(c),
                    selected: c == commodity,
                    onSelected: (_) => ref.read(profitCommodityProvider.notifier).state = c,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: c == commodity ? Colors.white : AppColors.textPrimary),
                  )).toList(),
                ),
              ]),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 20),
          // Advice
          advice.when(
            data: (a) => Column(children: [
              if (a.isDemo) const DemoDataNotice(),
              _DecisionBanner(advice: a).animate().scale(duration: 450.ms, curve: Curves.elasticOut),
              const SizedBox(height: 14),
              _PriceCompare(advice: a).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 14),
              _FactorsList(advice: a).animate().fadeIn(delay: 280.ms),
            ]),
            loading: () => Column(children: [
              _shimmerBox(140),
              const SizedBox(height: 14),
              _shimmerBox(100),
              const SizedBox(height: 14),
              _shimmerBox(180),
            ]),
            error: (_, __) => Center(child: ElevatedButton(
              onPressed: () => ref.invalidate(profitAdviceProvider),
              child: Text(s.retry),
            )),
          ),
        ]),
      ),
    );
  }
}

class _DecisionBanner extends ConsumerWidget {
  final ProfitAdvice advice;
  const _DecisionBanner({required this.advice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final cfg = _config(advice.decision, s);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cfg.color.withValues(alpha: 0.18), cfg.color.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: cfg.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(cfg.icon, color: cfg.color, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cfg.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cfg.color)),
            Text('${advice.confidence}% ${s.predConfident}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: cfg.color, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${advice.roi >= 0 ? '+' : ''}${advice.roi.toStringAsFixed(1)}% ROI',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline, color: AppColors.secondary, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(advice.reason, style: const TextStyle(fontSize: 13, height: 1.5))),
          ]),
        ),
      ]),
    );
  }

  _Cfg _config(ProfitDecision d, dynamic s) {
    switch (d) {
      case ProfitDecision.sellNow: return _Cfg('🔴  ${s.profSellNow}', Icons.sell_rounded, AppColors.priceDown);
      case ProfitDecision.hold7:  return _Cfg('🟡  ${s.profHold7}', Icons.hourglass_empty, AppColors.secondary);
      case ProfitDecision.hold14: return _Cfg('🟢  ${s.profHold14}', Icons.hourglass_full, AppColors.primary);
      case ProfitDecision.insufficientData: return const _Cfg('Insufficient history', Icons.info_outline, AppColors.textSecondary);
    }
  }
}

class _Cfg {
  final String label;
  final IconData icon;
  final Color color;
  const _Cfg(this.label, this.icon, this.color);
}

class _PriceCompare extends ConsumerWidget {
  final ProfitAdvice advice;
  const _PriceCompare({required this.advice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final up = advice.projectedPrice >= advice.currentPrice;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.profPriceComp, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _PriceBox(s.profCurrent, advice.currentPrice, AppColors.textPrimary),
          Column(children: [
            Icon(up ? Icons.arrow_forward : Icons.arrow_forward, color: up ? AppColors.priceUp : AppColors.priceDown, size: 24),
            Text(up ? '+${advice.roi.toStringAsFixed(1)}%' : '${advice.roi.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: up ? AppColors.priceUp : AppColors.priceDown, fontWeight: FontWeight.bold)),
          ]),
          _PriceBox(s.profProjected, advice.projectedPrice, up ? AppColors.priceUp : AppColors.priceDown),
        ]),
      ]),
    ));
  }
}

class _PriceBox extends ConsumerWidget {
  final String label;
  final double price;
  final Color color;
  const _PriceBox(this.label, this.price, this.color);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Column(children: [
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    const SizedBox(height: 4),
    Text('₹${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
    Text(s.perQuintal, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  ]);
  }
}

class _FactorsList extends ConsumerWidget {
  final ProfitAdvice advice;
  const _FactorsList({required this.advice});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(ref.watch(appStringsProvider).profKeyFactors, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...advice.factors.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(width: 22, height: 22, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10),
          Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
        ]).animate().fadeIn(delay: Duration(milliseconds: 80 * e.key)).slideX(begin: -0.1),
      )),
    ]),
  ));
}

Widget _shimmerBox(double h) => Container(
  height: h, margin: const EdgeInsets.only(bottom: 2),
  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5));
