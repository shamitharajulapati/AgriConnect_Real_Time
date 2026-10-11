import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  static late String supabaseUrl;
  static late String supabaseAnonKey;
  static late String mlServiceUrl;
  static late String openWeatherKey;
  static late String googleWebClientId;
  static bool authMock = false;
  static bool buyerListingsMock = false;
  static bool mlDemoFallback = false;
  static bool analyticsDemoFallback = false;

  /// Returns true if Supabase keys are real (not placeholder)
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('YOUR_') &&
      supabaseUrl.startsWith('https://');

  /// When true, auth always uses mock mode (any 6-digit OTP works)
  static bool get isAuthMock => authMock;
  static bool get showMockBuyerListings => buyerListingsMock;

  static bool get isMlConfigured =>
      mlServiceUrl.isNotEmpty && !mlServiceUrl.contains('YOUR_');

  static Future<void> load() async {
    try {
      final json = await rootBundle.loadString('assets/config/app_config.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      supabaseUrl = map['SUPABASE_URL'] ?? '';
      supabaseAnonKey = map['SUPABASE_ANON_KEY'] ?? '';
      mlServiceUrl = map['ML_SERVICE_URL'] ?? '';
      openWeatherKey = map['OPENWEATHER_KEY'] ?? '';
      googleWebClientId = map['GOOGLE_WEB_CLIENT_ID'] ?? '';
      authMock = map['AUTH_MOCK'] == true;
      buyerListingsMock = map['BUYER_LISTINGS_MOCK'] == true;
      mlDemoFallback = map['ML_DEMO_FALLBACK'] == true;
      analyticsDemoFallback = map['ANALYTICS_DEMO_FALLBACK'] == true;
    } catch (_) {
      supabaseUrl = supabaseAnonKey = mlServiceUrl = '';
      openWeatherKey = googleWebClientId = '';
      buyerListingsMock = false;
      mlDemoFallback = false;
      analyticsDemoFallback = false;
    }
  }
}
