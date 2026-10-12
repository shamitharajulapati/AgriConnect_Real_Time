import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Load config (Supabase keys, ML URL, etc.)
  await AppConfig.load();
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('language') ?? 'en';
  final savedState = prefs.getString('state')?.trim() ?? '';
  final savedDistrict = prefs.getString('district')?.trim() ?? '';

  // Initialize Supabase if keys are configured
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      debug: false,
    );
    debugPrint('✅ Supabase connected: ${AppConfig.supabaseUrl}');
  } else {
    debugPrint('⚠️  Running in Demo Mode (no Supabase keys found)');
  }

  // Catch rendering errors — show error message instead of black screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: ${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  runApp(
    ProviderScope(
      overrides: [
        appLangProvider.overrideWith((ref) => savedLang),
        userLocationProvider.overrideWith(
          (ref) => savedState.isEmpty ? 'Karnataka' : savedState,
        ),
        userDistrictProvider.overrideWith((ref) => savedDistrict),
        marketFilterProvider.overrideWith(
          (ref) => MarketFilter(
            state: savedState.isEmpty ? 'All States' : savedState,
          ),
        ),
      ],
      child: const AgriConnectApp(),
    ),
  );
}

class AgriConnectApp extends StatefulWidget {
  const AgriConnectApp({super.key});

  @override
  State<AgriConnectApp> createState() => _AgriConnectAppState();
}

class _AgriConnectAppState extends State<AgriConnectApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    _router ??= ProviderScope.containerOf(context).read(routerProvider);
    return MaterialApp.router(
      title: 'AgriConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router!,
    );
  }
}
