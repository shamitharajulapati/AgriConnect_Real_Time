import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  static late String supabaseUrl;
  static late String supabaseAnonKey;
  static late String mlServiceUrl;
  static late String mlServiceSecret;
  static late String openWeatherKey;
  static late String agmarknetKey;
  static late String googleWebClientId;
  static bool authMock = false;

  /// Returns true if Supabase keys are real (not placeholder)
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && !supabaseUrl.contains('YOUR_') && supabaseUrl.startsWith('https://');

  /// When true, auth always uses mock mode (any 6-digit OTP works)
  static bool get isAuthMock => authMock;

  static bool get isMlConfigured =>
      mlServiceUrl.isNotEmpty && !mlServiceUrl.contains('YOUR_');

  static Future<void> load() async {
    try {
      final json = await rootBundle.loadString('assets/config/app_config.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      supabaseUrl      = map['SUPABASE_URL'] ?? '';
      supabaseAnonKey  = map['SUPABASE_ANON_KEY'] ?? '';
      mlServiceUrl     = map['ML_SERVICE_URL'] ?? '';
      mlServiceSecret  = map['ML_SERVICE_SECRET'] ?? 'agriconnect_ml_secret_2024';
      openWeatherKey   = map['OPENWEATHER_KEY'] ?? '';
      agmarknetKey     = map['AGMARKNET_KEY'] ?? '';
      googleWebClientId = map['GOOGLE_WEB_CLIENT_ID'] ?? '';
      authMock         = map['AUTH_MOCK'] == true;
    } catch (_) {
      supabaseUrl = supabaseAnonKey = mlServiceUrl = '';
      mlServiceSecret = 'agriconnect_ml_secret_2024';
      openWeatherKey = agmarknetKey = googleWebClientId = '';
    }
  }
}
