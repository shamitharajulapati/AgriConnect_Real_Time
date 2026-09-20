import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';
import '../../../services/mock_api_service.dart' show CropRecoResult;

class CropRecoScreen extends ConsumerStatefulWidget {
  const CropRecoScreen({super.key});

  @override
  ConsumerState<CropRecoScreen> createState() => _CropRecoScreenState();
}

class _CropRecoScreenState extends ConsumerState<CropRecoScreen> {
  String _soilType = 'Loamy';
  String _season = 'Kharif';
  double _rainfall = 800;
  bool _loading = false;
  String? _error;
  List<CropRecoResult>? _recommendations;
  String _userState = '';
  String _userDistrict = '';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userState = prefs.getString('state') ?? '';
      _userDistrict = prefs.getString('district') ?? '';
    });
  }

  String get _locationLabel {
    if (_userState.isEmpty) return 'India';
    if (_userDistrict.isEmpty) return _userState;
    return '$_userState, $_userDistrict';
  }

  static const _soilTypes = ['Sandy', 'Loamy', 'Clay', 'Silt', 'Black Cotton'];
  static const _seasons = ['Kharif (Jun-Sep)', 'Rabi (Oct-Mar)', 'Zaid (Apr-Jun)'];
  static const _rainfallOptions = {'Low': 400.0, 'Medium': 800.0, 'High': 1400.0};

  Future<void> _getRecommendations() async {
    setState(() { _loading = true; _error = null; });
    final weather = ref.read(weatherProvider);
    final temperature = weather.asData?.value.temperature.toDouble() ?? 28.0;
    try {
      final results = await ref.read(apiProvider).fetchCropRecommendation(
        soilType: _soilType,
        season: _season,
        temperature: temperature,
        rainfall: _rainfall,
      );
      setState(() { _recommendations = results; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not get recommendations. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.cropRecoTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.cropTellFarm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    // Location info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(_locationLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                          const Spacer(),
                          Builder(builder: (_) {
                            final weather = ref.watch(weatherProvider);
                            return Text(
                              weather.when(
                                data: (w) => '${w.temperature}°C · ${w.humidity}% Humidity',
                                loading: () => '...',
                                error: (_, __) => '',
                              ),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('${s.cropRecoSoil}:', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _soilTypes.map((s) => ChoiceChip(
                            label: Text(s),
                            selected: s == _soilType,
                            onSelected: (_) => setState(() => _soilType = s),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: s == _soilType ? Colors.white : AppColors.textPrimary, fontSize: 12),
                          )).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('${s.cropRecoSeason}:', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _seasons.map((s) => ChoiceChip(
                            label: Text(s.split(' ')[0]),
                            selected: s.startsWith(_season),
                            onSelected: (_) => setState(() => _season = s.split(' ')[0]),
                            selectedColor: AppColors.secondary,
                            labelStyle: TextStyle(color: s.startsWith(_season) ? Colors.white : AppColors.textPrimary, fontSize: 12),
                          )).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Rainfall:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _rainfallOptions.entries.map((e) => ChoiceChip(
                            label: Text('${e.key} (${e.value.toInt()}mm)'),
                            selected: _rainfall == e.value,
                            onSelected: (_) => setState(() => _rainfall = e.value),
                            selectedColor: AppColors.accent,
                            labelStyle: TextStyle(color: _rainfall == e.value ? Colors.white : AppColors.textPrimary, fontSize: 12),
                          )).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.psychology_rounded),
                        label: Text(_loading ? 'Running KNN + RF Model...' : s.cropRecoGetBtn),
                        onPressed: _loading ? null : _getRecommendations,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: AppColors.priceDown, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(),
            if (_recommendations != null) ...[
              const SizedBox(height: 20),
              Text(s.cropRecoResult, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  .animate()
                  .fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              ..._recommendations!.asMap().entries.map((e) => _CropRecoCard(reco: e.value, rank: e.key + 1)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * e.key))
                  .slideY(begin: 0.15)),
            ],
          ],
        ),
      ),
    );
  }
}


class _CropRecoCard extends ConsumerWidget {
  final CropRecoResult reco;
  final int rank;
  const _CropRecoCard({required this.reco, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final colors = [AppColors.secondary, AppColors.primary, AppColors.accent, AppColors.primaryLight, AppColors.textSecondary];
    final rankColors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32), AppColors.primaryLight, AppColors.textSecondary];
    final color = colors[rank - 1];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: rankColors[rank - 1].withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: rankColors[rank - 1].withOpacity(0.5)),
              ),
              child: Center(child: Text(reco.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(reco.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text('#$rank ${s.cropMatch}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(reco.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Tag(Icons.schedule, reco.duration),
                      const SizedBox(width: 8),
                      _Tag(Icons.water_drop, '${reco.waterReq} ${s.cropWater}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text('${(reco.matchScore * 100).toInt()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(s.cropMatch.toLowerCase(), style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
