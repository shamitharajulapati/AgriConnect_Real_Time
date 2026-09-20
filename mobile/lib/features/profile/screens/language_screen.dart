import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const _langs = {
    'en': ('English', 'Select your language'),
    'hi': ('हिंदी', 'अपनी भाषा चुनें'),
    'te': ('తెలుగు', 'మీ భాషను ఎంచుకోండి'),
    'ta': ('தமிழ்', 'உங்கள் மொழியை தேர்வு செய்யவும்'),
    'kn': ('ಕನ್ನಡ', 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ'),
    'mr': ('मराठी', 'तुमची भाषा निवडा'),
    'gu': ('ગુજરાતી', 'તમારી ભાષા પસંદ કરો'),
    'pa': ('ਪੰਜਾਬੀ', 'ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ'),
    'bn': ('বাংলা', 'আপনার ভাষা নির্বাচন করুন'),
    'ml': ('മലയാളം', 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക'),
    'or': ('ଓଡ଼ିଆ', 'ଆପଣଙ୍କ ଭାଷା ବାଛନ୍ତୁ'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌐 Language / భాష'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Select language. App will restart.\nభాష ఎంచుకోండి. యాప్ రీస్టార్ట్ అవుతుంది.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          ..._langs.entries.map((e) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: const Icon(Icons.language, color: Color(0xFF2E7D32)),
              title: Text(e.value.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              subtitle: Text(e.value.$2, style: const TextStyle(fontSize: 12)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('language', e.key);
                if (context.mounted) {
                  // Show confirmation and tell user to restart
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${e.value.$1} selected! Close & reopen app.'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Navigator.of(context).pop(e.key);
                }
              },
            ),
          )),
        ],
      ),
    );
  }
}
