import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../models/crop_alert.dart';
import '../../../core/l10n/crop_names.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.alertsTitle),
        actions: [
          alertsAsync.whenOrNull(data: (_) => IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            onPressed: () => ref.read(alertsProvider.notifier).markAllRead(),
          )) ?? const SizedBox(),
        ],
      ),
      body: alertsAsync.when(
        data: (alerts) => Column(children: [
          _StatsBar(alerts: alerts),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(alertsProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: alerts.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) return _AddAlertTile(onTap: () => _showAddSheet(context, ref));
                  final alert = alerts[i - 1];
                  return Dismissible(
                    key: Key(alert.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => ref.read(alertsProvider.notifier).delete(alert.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    child: _AlertCard(
                      alert: alert,
                      onTap: () => ref.read(alertsProvider.notifier).markRead(alert.id),
                    ).animate().fadeIn(delay: Duration(milliseconds: 60 * i)).slideX(begin: 0.08),
                  );
                },
              ),
            ),
          ),
        ]),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(child: ElevatedButton(
          onPressed: () => ref.read(alertsProvider.notifier).refresh(),
          child: Text(s.retry),
        )),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAlertSheet(onAdd: (type, commodity, price) async {
        await ref.read(alertsProvider.notifier).addAlert(type, commodity, price);
        if (context.mounted) Navigator.pop(context);
      }),
    );
  }
}

class _StatsBar extends ConsumerWidget {
  final List<CropAlert> alerts;
  const _StatsBar({required this.alerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final unread = alerts.where((a) => !a.isRead).length;
    final active = alerts.where((a) => a.isActive).length;
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        _Chip('$unread ${s.alertsUnread}', Icons.notifications_active),
        const SizedBox(width: 12),
        _Chip('$active ${s.alertsActive}', Icons.check_circle_outline),
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

class _AddAlertTile extends ConsumerWidget {
  final VoidCallback onTap;
  const _AddAlertTile({required this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(14),
          color: AppColors.primary.withValues(alpha: 0.04),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(s.alertsCreate, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final CropAlert alert;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.onTap});

  static const _colors = {
    AlertType.priceSpike: AppColors.priceUp,
    AlertType.priceTarget: AppColors.secondary,
    AlertType.demandHigh: AppColors.accent,
    AlertType.newBuyer: Color(0xFF7B1FA2),
    AlertType.weather: Color(0xFF0277BD),
  };
  static const _icons = {
    AlertType.priceSpike: Icons.trending_up,
    AlertType.priceTarget: Icons.flag_rounded,
    AlertType.demandHigh: Icons.bar_chart,
    AlertType.newBuyer: Icons.person_add,
    AlertType.weather: Icons.cloud,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final labels = {
      AlertType.priceSpike: s.alertsPriceSpike,
      AlertType.priceTarget: s.alertsPriceTarget,
      AlertType.demandHigh: s.alertsHighDemand,
      AlertType.newBuyer: s.alertsNewBuyer,
      AlertType.weather: s.dashWeather,
    };
    final color = _colors[alert.type]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: alert.isRead ? Colors.transparent : color.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(_icons[alert.type], color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(labels[alert.type]!, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
              const Spacer(),
              if (!alert.isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 5),
            Text(localCropName(alert.commodity, s.lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(localAlertMessage(alert.type.name, alert.commodity, s.lang), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ])),
        ]),
      ),
    );
  }
}

class _AddAlertSheet extends ConsumerStatefulWidget {
  final Function(AlertType, String, double?) onAdd;
  const _AddAlertSheet({required this.onAdd});
  @override
  ConsumerState<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends ConsumerState<_AddAlertSheet> {
  String _commodity = 'Tomato';
  AlertType _type = AlertType.priceTarget;
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(s.alertsCreate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _commodity,
          decoration: InputDecoration(labelText: s.alertsCrop, prefixIcon: const Icon(Icons.grass)),
          items: ['Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton'].map((c) => DropdownMenuItem(value: c, child: Text(localCropName(c, s.lang)))).toList(),
          onChanged: (v) => setState(() => _commodity = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AlertType>(
          initialValue: _type,
          decoration: InputDecoration(labelText: s.alertsType, prefixIcon: const Icon(Icons.notifications)),
          items: const [
            DropdownMenuItem(value: AlertType.priceTarget, child: Text('When price reaches target')),
            DropdownMenuItem(value: AlertType.priceSpike, child: Text('When price spikes >15%')),
            DropdownMenuItem(value: AlertType.demandHigh, child: Text('When demand is HIGH')),
          ],
          onChanged: (v) => setState(() => _type = v!),
        ),
        if (_type == AlertType.priceTarget) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: '${s.alertsTargetPrice} (₹${s.perQuintal})', prefixText: '₹ ', prefixIcon: const Icon(Icons.price_change)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              await widget.onAdd(_type, _commodity, double.tryParse(_priceCtrl.text));
            },
            child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(s.alertsCreate),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
