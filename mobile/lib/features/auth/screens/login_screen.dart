import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // Login is email OTP (free via Supabase) or Google — no phone/SMS sign-in.
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    await ref.read(authStateProvider.notifier).sendOTP(email);
    if (mounted && ref.read(authStateProvider).status == AuthStatus.otpSent) {
      context.go('${AppRoutes.otpVerify}?email=${Uri.encodeQueryComponent(email)}');
    } else if (mounted) {
      final err = ref.read(authStateProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Could not send OTP. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).status == AuthStatus.loading;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradient1, AppColors.background],
            stops: [0, 0.45],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                          ),
                          child: const Icon(Icons.eco, size: 44, color: AppColors.primary),
                        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        Text(
                          s.loginWelcome,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
                        const SizedBox(height: 8),
                        Text(
                          s.loginSubtitle,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email field — primary login method, OTP sent here
                          const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'name@gmail.com',
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                            ),
                            validator: (v) {
                              if (v == null || !v.contains('@')) return 'Enter valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _sendOTP,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(s.loginSendOtp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().slideY(begin: 0.3, duration: 500.ms, delay: 300.ms, curve: Curves.easeOut).fadeIn(delay: 300.ms),
                  const SizedBox(height: 16),
                  // OR divider
                  Row(children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ]).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),
                  // Google Sign-In button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Image.network('https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg', width: 20, height: 20,
                        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.red)),
                      label: const Text('Sign in with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: isLoading ? null : () async {
                        try {
                          if (kIsWeb) {
                            // google_sign_in has no serverClientId on web; use Supabase's
                            // redirect flow. The app reloads afterwards and AuthNotifier
                            // picks up the session.
                            await Supabase.instance.client.auth.signInWithOAuth(
                              OAuthProvider.google,
                              redirectTo: Uri.base.origin,
                            );
                            return;
                          }
                          final googleSignIn = GoogleSignIn(
                            scopes: ['email'],
                            serverClientId: AppConfig.googleWebClientId,
                          );
                          // Forget the last-used account, otherwise Google silently reuses it
                          // and the account picker never appears.
                          try { await googleSignIn.signOut(); } catch (_) {}
                          final googleUser = await googleSignIn.signIn();
                          if (googleUser == null) return; // user cancelled the picker
                          final googleAuth = await googleUser.authentication;
                          final idToken = googleAuth.idToken;
                          if (idToken == null) throw Exception('Google did not return an ID token');

                          final response = await Supabase.instance.client.auth.signInWithIdToken(
                            provider: OAuthProvider.google,
                            idToken: idToken,
                            accessToken: googleAuth.accessToken,
                          );
                          if (response.user == null) throw Exception('Supabase rejected the Google sign-in');

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('email', googleUser.email);
                          // Profile in Supabase decides new vs returning; this also flips the
                          // router's auth state, otherwise it bounces us back to /login.
                          await ref.read(authStateProvider.notifier).onSessionEstablished(response.user!.id);
                          final authed = ref.read(authStateProvider).status == AuthStatus.authenticated;
                          if (context.mounted) context.go(authed ? AppRoutes.home : AppRoutes.register);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Google sign-in failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ).animate().fadeIn(delay: 450.ms),
                  const SizedBox(height: 24),
                  // Language selection chips
                  Builder(builder: (_) {
                    final curLang = ref.watch(appLangProvider);
                    return Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ['English','en'],['हिंदी','hi'],['తెలుగు','te'],['தமிழ்','ta'],['ಕನ್ನಡ','kn'],
                          ['मराठी','mr'],['ગુજરાતી','gu'],['ਪੰਜਾਬੀ','pa'],['বাংলা','bn'],['മലയാളം','ml'],['ଓଡ଼ିଆ','or'],
                        ].map((pair) {
                          final sel = curLang == pair[1];
                          return GestureDetector(
                            onTap: () async {
                              ref.read(appLangProvider.notifier).state = pair[1];
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('language', pair[1]);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? AppColors.primary : Colors.grey.shade300, width: sel ? 2 : 1),
                              ),
                              child: Text(pair[0], style: TextStyle(fontSize: 13, color: sel ? Colors.white : AppColors.textPrimary, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
