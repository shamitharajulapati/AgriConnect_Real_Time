import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/l10n/crop_names.dart';
import '../../../services/providers.dart';
import '../models/chat_models.dart';
import 'find_buyers_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(chatRoomsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.chatTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearch(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(chatRoomsProvider),
          ),
        ],
      ),
      body: rooms.when(
        data: (list) => Column(children: [
          _StatsBar(rooms: list),
          Expanded(
            child: list.isEmpty
                ? _EmptyState(onFindBuyers: () => _openFindBuyers(context))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(chatRoomsProvider),
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
                      itemBuilder: (_, i) => _ChatRoomTile(room: list[i])
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 60 * i))
                          .slideX(begin: 0.08),
                    ),
                  ),
          ),
        ]),
        loading: () => Column(children: [
          _StatsBar(rooms: const []),
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        ]),
        error: (_, __) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(s.mktFailed, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => ref.invalidate(chatRoomsProvider), child: Text(s.retry)),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFindBuyers(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_search),
        label: Text(s.chatFindBuyers),
      ),
    );
  }

  void _openFindBuyers(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FindBuyersScreen()));
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(context: context, delegate: _BuyerSearchDelegate(ref));
  }
}

class _StatsBar extends ConsumerWidget {
  final List<ChatRoom> rooms;
  const _StatsBar({required this.rooms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final unread = rooms.fold<int>(0, (sum, r) => sum + r.unreadCount);
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        _Chip('${rooms.length} ${s.chatBuyers}', Icons.people),
        const SizedBox(width: 12),
        _Chip('$unread ${s.alertsUnread}', Icons.mark_email_unread),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 14),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _EmptyState extends ConsumerWidget {
  final VoidCallback onFindBuyers;
  const _EmptyState({required this.onFindBuyers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline, size: 44, color: AppColors.primary),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(s.chatNoConv, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${s.chatFindBuyers}...',
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onFindBuyers,
          icon: const Icon(Icons.person_search),
          label: Text(s.chatFindNow),
        ),
      ]),
    );
  }
}

class _ChatRoomTile extends ConsumerWidget {
  final ChatRoom room;
  const _ChatRoomTile({required this.room});

  String _formatTime(DateTime dt, String yesterday) {
    final now = DateTime.now();
    if (dt.day == now.day) return DateFormat.jm().format(dt);
    if (now.difference(dt).inDays == 1) return yesterday;
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              room.otherUserName.isNotEmpty ? room.otherUserName[0].toUpperCase() : 'B',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      title: Row(children: [
        Expanded(child: Text(localCropName(room.otherUserName, s.lang), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Text(
          _formatTime(room.lastMessageTime, s.chatYesterday),
          style: TextStyle(fontSize: 11, color: room.unreadCount > 0 ? AppColors.primary : AppColors.textSecondary),
        ),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (room.cropTopic != null)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(localCropName(room.cropTopic!, s.lang), style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        Row(children: [
          Expanded(
            child: Text(
              translateMessage(room.lastMessage, s.lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: room.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: room.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (room.unreadCount > 0)
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Center(child: Text('${room.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ),
        ]),
      ]),
      onTap: () => context.go('${AppRoutes.chatList}/${room.roomId}'),
    );
  }
}

// Search delegate
class _BuyerSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  _BuyerSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    final rooms = ref.read(chatRoomsProvider).valueOrNull ?? [];
    final filtered = rooms.where((r) =>
      r.otherUserName.toLowerCase().contains(query.toLowerCase()) ||
      (r.cropTopic?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(filtered[i].otherUserName[0], style: const TextStyle(color: AppColors.primary))),
        title: Text(filtered[i].otherUserName),
        subtitle: Text(filtered[i].lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          close(context, null);
          context.go('${AppRoutes.chatList}/${filtered[i].roomId}');
        },
      ),
    );
  }
}
