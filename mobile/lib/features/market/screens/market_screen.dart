import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../models/market_price.dart';
import '../../../core/l10n/crop_names.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
  }

  Future<void> _syncIfNeeded() async {
    final state = ref.read(marketFilterProvider).state;
    final synced = ref.read(syncedStatesProvider);
    if (state == 'All States' || synced.contains(state)) return;

    setState(() => _syncing = true);
    final count = await ref.read(apiProvider).syncPricesForState(state);
    ref.read(syncedStatesProvider.notifier).state = {...synced, state};
    if (mounted) {
      setState(() => _syncing = false);
      if (count > 0) ref.invalidate(marketPricesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(marketFilterProvider);
    final prices = ref.watch(marketPricesProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.mktTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.read(syncedStatesProvider.notifier).state = {};
              _syncIfNeeded();
              ref.invalidate(marketPricesProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Live bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              _PulsingDot(),
              const SizedBox(width: 6),
              Text(_syncing ? '${s.mktLive}…' : s.mktLive, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${s.mktUpdated} ${_lastUpdated()}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ]),
          ),
          // Commodity chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MockMarketData.commodities.map((c) {
                  final sel = c == filter.commodity;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 10),
                    child: GestureDetector(
                      onTap: () => ref.read(marketFilterProvider.notifier).state = filter.copyWith(commodity: c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AppColors.primary : Colors.grey.shade300),
                        ),
                        child: Text(localCropName(c, s.lang), style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, color: sel ? Colors.white : AppColors.textPrimary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // State picker
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: DropdownButtonFormField<String>(
              initialValue: filter.state,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.map_outlined, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: MockMarketData.states.map((st) => DropdownMenuItem(value: st, child: Text(localCropName(st, s.lang), style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                ref.read(marketFilterProvider.notifier).state = filter.copyWith(state: v);
                _syncIfNeeded();
              },
            ),
          ),
          Expanded(
            child: prices.when(
              data: (list) => list.isEmpty
                  ? _EmptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async => ref.invalidate(marketPricesProvider),
                      child: _buildSectionedList(context, ref, list, s),
                    ),
              loading: () => _ShimmerList(),
              error: (e, _) => Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(s.mktFailed, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: () => ref.invalidate(marketPricesProvider), child: Text(s.retry)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lastUpdated() {
    final t = TimeOfDay.now();
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionedList(BuildContext context, WidgetRef ref, List<MarketPrice> list, dynamic s) {
    final myDistrict = ref.watch(userDistrictProvider);
    final hasDistrict = myDistrict.trim().isNotEmpty;

    final mine = hasDistrict
        ? list.where((p) => p.district.toLowerCase() == myDistrict.toLowerCase()).toList()
        : <MarketPrice>[];
    final others = (hasDistrict ? list.where((p) => p.district.toLowerCase() != myDistrict.toLowerCase()) : list)
        .toList()
      ..sort((a, b) => b.modalPrice.compareTo(a.modalPrice));

    final items = <Widget>[];
    var delay = 0;
    if (mine.isNotEmpty) {
      items.add(_SectionLabel('📍 $myDistrict — Your District'));
      for (final p in mine) {
        items.add(_PriceCard(price: p).animate().fadeIn(delay: Duration(milliseconds: 40 * delay++)).slideY(begin: 0.08));
      }
      items.add(_SectionLabel('💰 Top Markets in Other Districts'));
    }
    for (final p in others) {
      items.add(_PriceCard(price: p).animate().fadeIn(delay: Duration(milliseconds: 40 * delay++)).slideY(begin: 0.08));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: items,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: .2)),
      );
}

class _PriceCard extends ConsumerWidget {
  final MarketPrice price;
  const _PriceCard({required this.price});

  static const _emojis = {'Tomato': '🍅', 'Onion': '🧅', 'Potato': '🥔', 'Wheat': '🌾', 'Rice': '🌾', 'Cotton': '🌿', 'Chillies': '🌶️', 'Soybean': '🫘', 'Maize': '🌽', 'Sugarcane': '🎋'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final delta = price.deltaPercent;
    final isUp = price.isUp;
    final deltaColor = delta == null ? AppColors.textSecondary : isUp ? AppColors.priceUp : AppColors.priceDown;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(_emojis[price.commodity] ?? '🌱', style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(localCropName(price.commodity, s.lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${localCity(price.market, s.lang)} · ${localCropName(price.state, s.lang)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${price.modalPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: deltaColor)),
              Text(s.perQuintal, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              _MiniPrice(s.mktMin, price.minPrice, AppColors.priceDown),
              const Expanded(child: SizedBox()),
              _MiniPrice(s.mktModal, price.modalPrice, AppColors.primary),
              const Expanded(child: SizedBox()),
              _MiniPrice(s.mktMax, price.maxPrice, AppColors.priceUp),
              const Spacer(),
              if (delta != null) ...[
                Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: deltaColor),
                const SizedBox(width: 2),
                Text('${delta.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: deltaColor, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MiniPrice extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniPrice(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        Text('₹${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]);
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(margin: const EdgeInsets.only(bottom: 10), height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
        ),
      );
}

class _EmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(s.mktNoData, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ]),
      );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(width: 8, height: 8, decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5 + _c.value * 0.5),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: _c.value * 0.5), blurRadius: _c.value * 6)])),
      );
}
