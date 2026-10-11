import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../models/buyer_listing.dart';

final _buyersProvider = FutureProvider.autoDispose<List<BuyerListing>>((ref) async {
  if (AppConfig.showMockBuyerListings) return BuyerListing.mockListings;
  return const <BuyerListing>[];
});

final _filterProvider = StateProvider<String>((ref) => 'All');

class FindBuyersScreen extends ConsumerWidget {
  const FindBuyersScreen({super.key});

  static const _crops = ['All', 'Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Chillies', 'Maize'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyers = ref.watch(_buyersProvider);
    final filter = ref.watch(_filterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find Buyers')),
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                AppConfig.showMockBuyerListings
                    ? 'Sample buyer listings for demo'
                    : 'Active buyers looking to purchase',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _crops.map((c) {
                    final sel = c == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ref.read(_filterProvider.notifier).state = c,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? Colors.white : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(c, style: TextStyle(
                            color: sel ? AppColors.primary : Colors.white,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
          Expanded(
            child: buyers.when(
              data: (list) {
                final filtered = filter == 'All' ? list : list.where((b) => b.commodity == filter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        filter == 'All'
                            ? 'No active buyer listings right now'
                            : 'No active buyer listings for $filter right now',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _BuyerCard(listing: filtered[i])
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 60 * i))
                      .slideY(begin: 0.08),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const Center(child: Text('Failed to load buyers')),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyerCard extends ConsumerWidget {
  final BuyerListing listing;
  const _BuyerCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(listing.buyerName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.buyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${listing.state ?? ''} · ${listing.district ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(listing.commodity, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          if (listing.description != null)
            Text(listing.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [
            if (listing.quantityNeeded != null) ...[
              const Icon(Icons.scale, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${listing.quantityNeeded!.toInt()} qtl needed',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
            ],
            if (listing.priceOffered != null) ...[
              const Icon(Icons.currency_rupee, size: 14, color: AppColors.priceUp),
              Text('${listing.priceOffered!.toInt()}/qtl offered',
                  style: const TextStyle(fontSize: 12, color: AppColors.priceUp, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _startChat(context, listing),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Chat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _startChat(BuildContext context, BuyerListing listing) {
    final roomId = ['me', listing.buyerId]..sort();
    final chatRoomId = roomId.join('_');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chat with ${listing.buyerName}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Topic: ${listing.commodity}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Offering: ₹${listing.priceOffered?.toInt()}/qtl for ${listing.quantityNeeded?.toInt()} quintals',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          const Text('Start a conversation to negotiate price and delivery.', style: TextStyle(fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('${AppRoutes.chatList}/$chatRoomId');
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }
}
