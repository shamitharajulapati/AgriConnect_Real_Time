import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import '../../../services/providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final notifier = ref.read(authStateProvider.notifier);
    final ok = await notifier.verifyOTP(_otpCtrl.text.trim());
    if (!mounted) return;
    final state = ref.read(authStateProvider);
    if (ok && state.status == AuthStatus.newUser) {
      context.go(AppRoutes.register);
    } else if (ok && state.status == AuthStatus.authenticated) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? 'Invalid or expired OTP. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final isLoading = ref.watch(authStateProvider).status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(s.otpTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
                .animate()
                .fadeIn()
                .slideX(begin: -0.2),
            const SizedBox(height: 8),
            Text(
              '${s.otpTitle} — ${widget.email}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 40),
            // OTP field
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: TextStyle(letterSpacing: 12, color: AppColors.textHint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _verify,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(s.otpVerify),
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 24),
            Center(
              child: _secondsLeft > 0
                  ? Text(
                      '${s.otpResend} ${_secondsLeft}s',
                      style: const TextStyle(color: AppColors.textSecondary),
                    )
                  : TextButton(
                      onPressed: () {
                        setState(() => _secondsLeft = 60);
                        _startTimer();
                        ref.read(authStateProvider.notifier).sendOTP(widget.email);
                      },
                      child: Text(s.otpResend),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
