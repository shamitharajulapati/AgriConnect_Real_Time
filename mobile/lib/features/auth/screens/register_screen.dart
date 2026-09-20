import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/crop_names.dart';
import '../../../core/constants/india_states_districts.dart';
import '../../../services/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  final _nameCtrl = TextEditingController();
  String? _selectedState;
  String? _selectedDistrict;
  final _selectedCrops = <String>{};
  String _selectedLanguage = 'hi';

  static const _states = ['Maharashtra', 'Punjab', 'Karnataka', 'Andhra Pradesh', 'Telangana', 'Tamil Nadu', 'Uttar Pradesh', 'Rajasthan', 'Gujarat', 'Madhya Pradesh'];
  static const _crops = ['Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Sugarcane', 'Maize', 'Soybean', 'Chillies'];
  static const _languages = {
    'hi': 'हिंदी', 'en': 'English', 'te': 'తెలుగు', 'ta': 'தமிழ்', 'kn': 'ಕನ್ನಡ',
    'mr': 'मराठी', 'gu': 'ગુજરાતી', 'pa': 'ਪੰਜਾਬੀ', 'bn': 'বাংলা', 'ml': 'മലയാളം', 'or': 'ଓଡ଼ିଆ',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(appLangProvider);
      if (_languages.containsKey(lang)) setState(() => _selectedLanguage = lang);
    });
  }

  void _next() {
    if (_currentPage < 2) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    await ref.read(authStateProvider.notifier).completeRegistration({
      'name': _nameCtrl.text.trim(),
      'state': _selectedState,
      'district': _selectedDistrict,
      'crops': _selectedCrops.toList(),
      'language': _selectedLanguage,
    });
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentPage + 1}/3 - ${s.regTitle}'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: AppColors.primaryLight.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(s),
                _buildStep2(s),
                _buildStep3(s),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: _next,
              child: Text(_currentPage < 2 ? s.regContinue : s.regStartApp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AppStrings s) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(s.regPersonalInfo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                .animate().fadeIn().slideX(begin: -0.2),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: s.regName,
                prefixIcon: Icon(Icons.person, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );

  Widget _buildStep2(AppStrings s) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(s.regYourLocation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                .animate().fadeIn(),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: InputDecoration(
                labelText: s.regState,
                prefixIcon: Icon(Icons.map, color: AppColors.primary),
              ),
              items: _states.map((st) => DropdownMenuItem(value: st, child: Text(localCropName(st, s.lang)))).toList(),
              onChanged: (v) => setState(() {
                _selectedState = v;
                _selectedDistrict = null; // reset — districts depend on state
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: InputDecoration(
                labelText: s.regDistrict,
                prefixIcon: Icon(Icons.location_city, color: AppColors.primary),
              ),
              items: IndiaStatesDistricts.districtsFor(_selectedState)
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: _selectedState == null ? null : (v) => setState(() => _selectedDistrict = v),
              hint: Text(_selectedState == null ? s.regSelectStateFirst : s.regDistrict),
            ),
          ],
        ),
      );

  Widget _buildStep3(AppStrings s) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(s.regCropsLang, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                .animate().fadeIn(),
            const SizedBox(height: 16),
            Text(s.regSelectCrops, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _crops
                  .map((c) => FilterChip(
                        label: Text(localCropName(c, s.lang)),
                        selected: _selectedCrops.contains(c),
                        onSelected: (v) => setState(() => v ? _selectedCrops.add(c) : _selectedCrops.remove(c)),
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedCrops.contains(c) ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: _selectedCrops.contains(c) ? FontWeight.w600 : FontWeight.normal,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text(s.regPrefLang, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.entries
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: _selectedLanguage == e.key,
                        onSelected: (_) {
                          setState(() => _selectedLanguage = e.key);
                          ref.read(appLangProvider.notifier).state = e.key;
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedLanguage == e.key ? Colors.white : AppColors.textPrimary,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
}
