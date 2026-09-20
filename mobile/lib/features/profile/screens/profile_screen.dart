import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/l10n/crop_names.dart';
import '../../../core/constants/india_states_districts.dart';
import '../../../services/providers.dart';
import '../../auth/providers/auth_provider.dart';
import 'language_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _name = '';
  String _location = '';
  List<String> _crops = [];
  static const _langs = {
    'en': 'English', 'hi': 'हिंदी', 'te': 'తెలుగు', 'ta': 'தமிழ்',
    'kn': 'ಕನ್ನಡ', 'mr': 'मराठी', 'gu': 'ગુજરાતી', 'pa': 'ਪੰਜਾਬੀ',
    'bn': 'বাংলা', 'ml': 'മലయാളം', 'or': 'ଓଡ଼ିଆ',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? 'Farmer';
      final st = prefs.getString('state') ?? '';
      final dist = prefs.getString('district') ?? '';
      _location = [st, dist].where((s) => s.isNotEmpty).join(', ');
      _crops = prefs.getStringList('crops') ?? ['Tomato', 'Onion', 'Wheat'];
    });
  }

  static const _profileStates = ['Maharashtra', 'Punjab', 'Karnataka', 'Andhra Pradesh', 'Telangana', 'Tamil Nadu', 'Uttar Pradesh', 'Rajasthan', 'Gujarat', 'Madhya Pradesh'];

  void _showEditProfile(BuildContext context, AppStrings s) {
    final nameCtrl = TextEditingController(text: _name);
    final parts = _location.split(', ');
    String? selectedState = parts.isNotEmpty && parts[0].isNotEmpty && _profileStates.contains(parts[0]) ? parts[0] : null;
    String? selectedDistrict = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    final allCrops = ['Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Maize', 'Chillies', 'Soybean', 'Groundnut'];
    final selected = Set<String>.from(_crops);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(s.profileEditProf, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.regName, prefixIcon: const Icon(Icons.person_outline))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedState,
                decoration: InputDecoration(labelText: s.regState, prefixIcon: const Icon(Icons.map_outlined)),
                items: _profileStates.map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
                onChanged: (v) => setModal(() { selectedState = v; selectedDistrict = null; }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDistrict,
                decoration: InputDecoration(labelText: s.regDistrict, prefixIcon: const Icon(Icons.location_on_outlined)),
                items: IndiaStatesDistricts.districtsFor(selectedState).map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: selectedState == null ? null : (v) => setModal(() => selectedDistrict = v),
              ),
              const SizedBox(height: 16),
              Text(s.profileMyCrops, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: allCrops.map((c) => FilterChip(
                  label: Text(c),
                  selected: selected.contains(c),
                  onSelected: (v) => setModal(() => v ? selected.add(c) : selected.remove(c)),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected.contains(c) ? AppColors.primary : AppColors.textPrimary),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                )).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('name', nameCtrl.text.trim());
                  await prefs.setString('state', selectedState ?? '');
                  await prefs.setString('district', selectedDistrict ?? '');
                  await prefs.setStringList('crops', selected.toList());
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadProfile();
                },
                child: Text(s.saveChanges),
              )),
            ]),
          ),
        );
      }),
    );
  }


  void _showNotificationPrefs(BuildContext context, AppStrings s) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => StatefulBuilder(builder: (ctx, setDialog) {
        return AlertDialog(
          title: Text(s.profileNotif),
          content: FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              final prefs = snap.data!;
              bool priceAlerts = prefs.getBool('notif_price_alerts') ?? true;
              bool weather = prefs.getBool('notif_weather') ?? true;
              bool buyers = prefs.getBool('notif_buyers') ?? true;

              Widget row(String label, IconData icon, Color color, bool value, String key, void Function(bool) onSet) {
                return SwitchListTile(
                  secondary: Icon(icon, color: color),
                  title: Text(label),
                  value: value,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    prefs.setBool(key, v);
                    setDialog(() => onSet(v));
                  },
                );
              }

              return Column(mainAxisSize: MainAxisSize.min, children: [
                row(s.alertsTitle, Icons.trending_up, AppColors.primary, priceAlerts, 'notif_price_alerts', (v) => priceAlerts = v),
                row(s.dashWeather, Icons.cloud_outlined, Colors.blue, weather, 'notif_weather', (v) => weather = v),
                row(s.chatFindBuyers, Icons.person_add_outlined, Colors.purple, buyers, 'notif_buyers', (v) => buyers = v),
              ]);
            },
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: Text(s.close))],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final currentLang = ref.watch(appLangProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.gradient1, AppColors.gradient2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.person, size: 44, color: AppColors.primary),
                      ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 12),
                      Text(_name.isEmpty ? 'Farmer' : transliterate(_name, currentLang), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 4),
                      Text(_location.isEmpty ? 'India' : _location.split(', ').map((p) => localCropName(p.trim(), currentLang)).join(', '), style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats — localized
                  Row(
                    children: [
                      _StatCard(s.profileActiveCrops, '${_crops.length}', Icons.grass, AppColors.primary),
                      const SizedBox(width: 12),
                      _StatCard(s.profileAlertsSet, '3', Icons.notifications, AppColors.secondary),
                      const SizedBox(width: 12),
                      _StatCard(s.profileTransact, '12', Icons.receipt_long, AppColors.accent),
                    ],
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 20),
                  // Crops
                  _SectionCard(
                    title: s.profileMyCrops,
                    icon: Icons.grass,
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: (_crops.isEmpty ? ['Tomato', 'Onion', 'Wheat'] : _crops).map((c) => Chip(
                        label: Text(localCropName(c, currentLang)),
                        avatar: const Text('🌱', style: TextStyle(fontSize: 14)),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      )).toList(),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),
                  // Settings
                  _SectionCard(
                    title: s.profileSettings,
                    icon: Icons.settings,
                    child: Column(
                      children: [
                        _SettingTile(s.profileEditProf, Icons.edit, onTap: () => _showEditProfile(context, s)),
                        // Language — just save to prefs, user restarts app
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.language, color: AppColors.textSecondary, size: 20),
                          title: Text(s.profileLang, style: const TextStyle(fontSize: 14)),
                          trailing: DropdownButton<String>(
                            value: currentLang,
                            underline: const SizedBox(),
                            items: _langs.entries.map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: const TextStyle(fontSize: 13)),
                            )).toList(),
                            onChanged: (code) async {
                              if (code == null || code == currentLang) return;
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('language', code);
                              ref.read(appLangProvider.notifier).state = code;
                            },
                          ),
                        ),
                        _SettingTile(s.profileNotif, Icons.notifications_outlined, onTap: () => _showNotificationPrefs(context, s)),
                        _SettingTile(s.profilePrivacy, Icons.privacy_tip_outlined, onTap: () {
                          showDialog(
                            context: context,
                            useRootNavigator: true,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text(s.profilePrivacy),
                              content: const SingleChildScrollView(
                                child: Text(
                                  'AgriConnect Privacy Policy\n\nLast updated: June 2026\n\nWe collect the following data:\n• Name, email, state, district\n• Crops you grow\n• Market queries and alerts set\n\nHow we use it:\n• To show relevant market prices\n• To send price and weather alerts\n• To connect you with buyers\n\nData security:\n• All data is encrypted in transit (HTTPS)\n• We never sell your data to third parties\n• You can delete your account at any time\n\nContact us:\nsupport@agriconnect.in',
                                  style: TextStyle(fontSize: 13, height: 1.7),
                                ),
                              ),
                              actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('OK'))],
                            ),
                          );
                        }),
                        _SettingTile('AgriConnect', Icons.info_outline, onTap: () {
                          showAboutDialog(
                            context: context,
                            useRootNavigator: true,
                            applicationName: 'AgriConnect',
                            applicationVersion: '2.0.0',
                            applicationIcon: const Icon(Icons.eco, color: AppColors.primary, size: 40),
                            children: [const Text('Farmer Market Intelligence Platform')],
                          );
                        }),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(s.profileSignOut, style: const TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      onPressed: () async {
                        await ref.read(authStateProvider.notifier).signOut();
                        if (context.mounted) context.go(AppRoutes.login);
                      },
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),
                  const Text('Build: v11-lang', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? trailing;
  final VoidCallback onTap;
  const _SettingTile(this.label, this.icon, {this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) Text(trailing!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

