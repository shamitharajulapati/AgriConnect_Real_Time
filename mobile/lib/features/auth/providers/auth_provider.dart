import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_config.dart';
import '../../../services/supabase_service.dart';

enum AuthStatus { initial, loading, otpSent, newUser, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? uid;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.uid,
    this.email,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, String? uid, String? email, String? errorMessage}) =>
      AuthState(
        status: status ?? this.status,
        uid: uid ?? this.uid,
        email: email ?? this.email,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  SupabaseClient get _supabase => Supabase.instance.client;
  bool get _useSupabase => AppConfig.isSupabaseConfigured && !AppConfig.isAuthMock;

  Future<void> _init() async {
    state = state.copyWith(status: AuthStatus.loading);
    await Future.delayed(const Duration(milliseconds: 600));

    if (_useSupabase) {
      var session = _supabase.auth.currentSession;
      if (session == null && kIsWeb && Uri.base.queryParameters.containsKey('code')) {
        // Returning from Google's redirect: the code is still being exchanged.
        try {
          final event = await _supabase.auth.onAuthStateChange
              .firstWhere((e) => e.session != null)
              .timeout(const Duration(seconds: 8));
          session = event.session;
        } catch (_) {}
      }
      if (session != null) {
        final profile = await ApiService().getProfile();
        if (profile != null) await _cacheProfileLocally(profile);
        state = state.copyWith(
          status: _isComplete(profile) ? AuthStatus.authenticated : AuthStatus.newUser,
          uid: session.user.id,
          email: session.user.email,
        );
        return;
      }
    } else {
      // Mock path
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid != null) {
        state = state.copyWith(status: AuthStatus.authenticated, uid: uid);
        return;
      }
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  bool _isEmail(String input) => input.contains('@');

  /// A row can exist without the farmer having finished registration (empty
  /// row from a DB trigger, abandoned signup) — only a filled-in profile counts.
  bool _isComplete(Map<String, dynamic>? p) {
    if (p == null) return false;
    bool filled(Object? v) => v is String ? v.trim().isNotEmpty : v is List ? v.isNotEmpty : v != null;
    return filled(p['name']) && filled(p['state']) && filled(p['district']) && filled(p['crops']);
  }

  Future<void> sendOTP(String email) async {
    state = state.copyWith(status: AuthStatus.loading);

    if (_isEmail(email) && AppConfig.isSupabaseConfigured) {
      // Email OTP — always use real Supabase (free)
      try {
        await _supabase.auth.signInWithOtp(email: email, shouldCreateUser: true);
        state = state.copyWith(status: AuthStatus.otpSent, email: email);
      } on AuthException catch (e) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      } catch (e) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      }
    } else {
      // Mock — simulate OTP send
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(status: AuthStatus.otpSent, email: email);
    }
  }

  Future<bool> verifyOTP(String otp) async {
    state = state.copyWith(status: AuthStatus.loading);
    final input = state.email ?? '';

    if (_isEmail(input) && AppConfig.isSupabaseConfigured) {
      // Email OTP verification — real Supabase
      try {
        final response = await _supabase.auth.verifyOTP(
          email: input,
          token: otp,
          type: OtpType.email,
        );
        if (response.user == null) {
          state = state.copyWith(status: AuthStatus.error, errorMessage: 'Invalid OTP');
          return false;
        }
        final prefs = await SharedPreferences.getInstance();
        final isNew = prefs.getString('name') == null;
        state = state.copyWith(
          status: isNew ? AuthStatus.newUser : AuthStatus.authenticated,
          uid: response.user!.id,
        );
        return true;
      } on AuthException catch (e) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
        return false;
      }
    } else {
      // Mock — accept any 6-digit OTP
      await Future.delayed(const Duration(milliseconds: 800));
      if (otp.length == 6) {
        final prefs = await SharedPreferences.getInstance();
        final isNew = prefs.getString('name') == null;
        state = state.copyWith(
          status: isNew ? AuthStatus.newUser : AuthStatus.authenticated,
          uid: 'mock_user_$input',
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Invalid OTP');
      return false;
    }
  }

  Future<void> completeRegistration(Map<String, dynamic> data) async {
    state = state.copyWith(status: AuthStatus.loading);

    if (_useSupabase) {
      try {
        await ApiService().saveProfile(data);
        // Supabase is the source of truth, but the dashboard, profile screen,
        // and district-priority market sorting all read the farmer's profile
        // from local prefs for instant access — cache it here too, or every
        // real (non-mock) user sees generic defaults until the next fetch.
        await _cacheProfileLocally(data);
        state = state.copyWith(status: AuthStatus.authenticated);
      } catch (e) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', state.uid ?? 'mock_user');
      await _cacheProfileLocally(data);
      state = state.copyWith(status: AuthStatus.authenticated);
    }
  }

  Future<void> _cacheProfileLocally(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', data['name'] ?? '');
    await prefs.setString('state', data['state'] ?? '');
    await prefs.setString('district', data['district'] ?? '');
    await prefs.setString('language', data['language'] ?? 'en');
    final crops = data['crops'];
    if (crops is List) {
      await prefs.setStringList('crops', crops.map((e) => e.toString()).toList());
    }
  }

  void setNewUser(String uid) {
    state = state.copyWith(status: AuthStatus.newUser, uid: uid);
  }

  /// Call after a Supabase session is created outside this notifier (e.g. Google
  /// sign-in). Mirrors the session branch of [_init]: the router only lets a user
  /// past the auth screens once the state is [AuthStatus.authenticated].
  Future<void> onSessionEstablished(String uid) async {
    final profile = await ApiService().getProfile();
    if (profile != null) await _cacheProfileLocally(profile);
    state = state.copyWith(
      status: _isComplete(profile) ? AuthStatus.authenticated : AuthStatus.newUser,
      uid: uid,
    );
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try { await GoogleSignIn().signOut(); } catch (_) {}
    }
    if (_useSupabase) {
      try {
        await _supabase.auth.signOut();
      } catch (_) {}
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Listen to Supabase auth state changes (token refresh etc.)
  void listenToAuthChanges() {
    if (!_useSupabase) return;
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else if (data.event == AuthChangeEvent.tokenRefreshed) {
        if (state.status != AuthStatus.authenticated) {
          state = state.copyWith(status: AuthStatus.authenticated, uid: data.session?.user.id);
        }
      }
    });
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
