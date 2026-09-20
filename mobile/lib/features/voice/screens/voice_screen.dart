import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/app_colors.dart';
import '../../../services/providers.dart';

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcribed = '';
  String _response = '';
  String _selectedLang = 'hi';
  final _textCtrl = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  static const _languages = {
    'hi': 'हिंदी',
    'en': 'English',
    'te': 'తెలుగు',
    'ta': 'தமிழ்',
    'kn': 'ಕನ್ನಡ',
    'mr': 'मराठी',
    'gu': 'ગુજરાતી',
    'pa': 'ਪੰਜਾਬੀ',
    'bn': 'বাংলা',
    'ml': 'മലയാളം',
    'or': 'ଓଡ଼ିଆ',
  };

  static const _sampleQueries = {
    'hi': ['टमाटर का भाव क्या है?', 'कौन सी फसल बोयें?', 'आज का मौसम', 'कब बेचूं?', 'MSP क्या है?', 'खाद की सलाह दो', 'किसान लोन कैसे लें?'],
    'en': ['Tomato price today?', 'Which crop to grow?', 'Today\'s weather', 'When to sell?', 'What is MSP?', 'Fertilizer tips', 'Kisan Credit Card loan?'],
    'te': ['టమాట ధర ఏంటి?', 'ఏ పంట వేయాలి?', 'నేటి వాతావరణం', 'ఎప్పుడు అమ్మాలి?', 'MSP అంటే ఏంటి?'],
    'ta': ['தக்காளி விலை?', 'என்ன பயிர்?', 'இன்றைய வானிலை', 'எப்போது விற்பது?', 'MSP என்ன?'],
    'kn': ['ಟೊಮೆಟೊ ಬೆಲೆ?', 'ಯಾವ ಬೆಳೆ?', 'ಇಂದಿನ ಹವಾಮಾನ', 'ಯಾವಾಗ ಮಾರಬೇಕು?'],
    'mr': ['टोमॅटोचा भाव?', 'कोणती पीक?', 'आजचे हवामान', 'केव्हा विकावे?', 'MSP काय आहे?'],
    'gu': ['ટામેટાનો ભાવ?', 'કઈ ખેતી?', 'આજનું હવામાન', 'ક્યારે વેચવું?'],
    'pa': ['ਟਮਾਟਰ ਦਾ ਭਾਅ?', 'ਕਿਹੜੀ ਫਸਲ?', 'ਅੱਜ ਦਾ ਮੌਸਮ', 'ਕਦੋਂ ਵੇਚਣਾ?'],
    'bn': ['টমেটোর দাম?', 'কোন ফসল?', 'আজকের আবহাওয়া', 'কখন বিক্রি?'],
    'ml': ['തക്കാളി വില?', 'ഏത് വിള?', 'ഇന്നത്തെ കാലാവസ്ഥ', 'എപ്പോൾ വിൽക്കണം?'],
    'or': ['ଟମାଟୋ ଦର?', 'କେଉଁ ଫସଲ?', 'ଆଜି ପାଣିପାଗ', 'କେବେ ବିକ୍ରି?'],
  };

  static const _priceResponses = {
    'hi': 'आज टमाटर का मोडल भाव ₹1,500/क्विंटल है। आज़ादपुर मंडी में। कल से 11% ऊपर। 🍅📈',
    'en': 'Tomato modal price today is ₹1,500/quintal at Azadpur market. Up 11% from yesterday. 🍅📈',
    'te': 'ఈరోజు టమాట ధర ₹1,500/క్వింటాల్. ఆజాద్‌పూర్ మార్కెట్‌లో. నిన్నటి కంటే 11% పెరిగింది. 🍅📈',
    'ta': 'இன்று தக்காளி விலை ₹1,500/குவிண்டால். ஆசாத்பூர் சந்தையில். நேற்றை விட 11% அதிகம். 🍅📈',
    'kn': 'ಇಂದು ಟೊಮೆಟೊ ಬೆಲೆ ₹1,500/ಕ್ವಿಂಟಾಲ್. ಆಜಾದ್‌ಪುರ್ ಮಾರ್ಕೆಟ್‌ನಲ್ಲಿ. ನಿನ್ನೆಗಿಂತ 11% ಹೆಚ್ಚು. 🍅📈',
    'mr': 'आज टोमॅटोचा भाव ₹1,500/क्विंटल आहे. आझादपूर बाजारात. काल पेक्षा 11% जास्त. 🍅📈',
    'gu': 'આજે ટામેટાનો ભાવ ₹1,500/ક્વિન્ટલ છે. આઝાદપુર બજારમાં. ગઈ કાલ કરતાં 11% વધુ. 🍅📈',
    'pa': 'ਅੱਜ ਟਮਾਟਰ ਦਾ ਭਾਅ ₹1,500/ਕੁਇੰਟਲ ਹੈ। ਆਜ਼ਾਦਪੁਰ ਮੰਡੀ ਵਿੱਚ। ਕੱਲ੍ਹ ਨਾਲੋਂ 11% ਵੱਧ। 🍅📈',
    'bn': 'আজ টমেটোর দাম ₹1,500/কুইন্টাল। আজাদপুর বাজারে। গতকালের চেয়ে 11% বেশি। 🍅📈',
    'ml': 'ഇന്ന് തക്കാളി വില ₹1,500/ക്വിന്റൽ. ആസാദ്‌പൂർ മാർക്കറ്റിൽ. ഇന്നലെയെക്കാൾ 11% കൂടുതൽ. 🍅📈',
    'or': 'ଆଜି ଟମାଟୋ ଦର ₹1,500/କ୍ୱିଣ୍ଟାଲ। ଆଜାଦପୁର ବଜାରରେ। ଗତକାଲ ଅପେକ୍ଷା 11% ଅଧିକ। 🍅📈',
  };

  static const _cropResponses = {
    'hi': 'आपकी जमीन और मौसम के हिसाब से टमाटर, प्याज, और गेहूं की खेती अच्छी रहेगी। 🌾',
    'en': 'Based on your soil and season: Tomato, Onion, and Wheat are recommended. 🌾',
    'te': 'మీ నేల మరియు సీజన్ ప్రకారం: టమాట, ఉల్లిపాయ, గోధుమ సూచించబడింది. 🌾',
    'ta': 'உங்கள் நிலம் மற்றும் பருவத்திற்கு: தக்காளி, வெங்காயம், கோதுமை பரிந்துரைக்கப்படுகிறது. 🌾',
    'kn': 'ನಿಮ್ಮ ಮಣ್ಣು ಮತ್ತು ಋತುವಿಗೆ: ಟೊಮೆಟೊ, ಈರುಳ್ಳಿ, ಗೋಧಿ ಶಿಫಾರಸು. 🌾',
    'mr': 'तुमच्या जमीन आणि हंगामानुसार: टोमॅटो, कांदा, गहू शिफारस केली आहे. 🌾',
    'gu': 'તમારી જમીન અને ઋતુ પ્રમાણે: ટામેટા, ડુંગળી, ઘઉં ભલામણ. 🌾',
    'pa': 'ਤੁਹਾਡੀ ਜ਼ਮੀਨ ਅਤੇ ਮੌਸਮ ਅਨੁਸਾਰ: ਟਮਾਟਰ, ਪਿਆਜ਼, ਕਣਕ ਦੀ ਸਿਫਾਰਸ਼। 🌾',
    'bn': 'আপনার মাটি ও মৌসুম অনুযায়ী: টমেটো, পেঁয়াজ, গম সুপারিশ করা হচ্ছে। 🌾',
    'ml': 'നിങ്ങളുടെ മണ്ണും കാലവും അനുസരിച്ച്: തക്കാളി, ഉള്ളി, ഗോതമ്പ് ശുപാർശ. 🌾',
    'or': 'ଆପଣଙ୍କ ମାଟି ଓ ଋତୁ ଅନୁଯାୟୀ: ଟମାଟୋ, ପିଆଜ, ଗହମ ସୁପାରିଶ। 🌾',
  };

  static const _marketResponses = {
    'hi': 'आज मंडी भाव:\n🍅 टमाटर: ₹1,500 (+11%)\n🧅 प्याज: ₹950 (-13%)\n🥔 आलू: ₹750 (+4%)',
    'en': "Today's market:\n🍅 Tomato: ₹1,500 (+11%)\n🧅 Onion: ₹950 (-13%)\n🥔 Potato: ₹750 (+4%)",
    'te': 'నేటి మార్కెట్:\n🍅 టమాట: ₹1,500 (+11%)\n🧅 ఉల్లి: ₹950 (-13%)\n🥔 బంగాళదుంప: ₹750 (+4%)',
    'ta': 'இன்றைய சந்தை:\n🍅 தக்காளி: ₹1,500 (+11%)\n🧅 வெங்காயம்: ₹950 (-13%)\n🥔 உருளைக்கிழங்கு: ₹750 (+4%)',
    'kn': 'ಇಂದಿನ ಮಾರುಕಟ್ಟೆ:\n🍅 ಟೊಮೆಟೊ: ₹1,500 (+11%)\n🧅 ಈರುಳ್ಳಿ: ₹950 (-13%)\n🥔 ಆಲೂ: ₹750 (+4%)',
    'mr': 'आजची बाजार:\n🍅 टोमॅटो: ₹1,500 (+11%)\n🧅 कांदा: ₹950 (-13%)\n🥔 बटाटा: ₹750 (+4%)',
    'gu': 'આજનો બજાર:\n🍅 ટામેટા: ₹1,500 (+11%)\n🧅 ડુંગળી: ₹950 (-13%)\n🥔 બટેટા: ₹750 (+4%)',
    'pa': 'ਅੱਜ ਮੰਡੀ:\n🍅 ਟਮਾਟਰ: ₹1,500 (+11%)\n🧅 ਪਿਆਜ਼: ₹950 (-13%)\n🥔 ਆਲੂ: ₹750 (+4%)',
    'bn': 'আজকের বাজার:\n🍅 টমেটো: ₹1,500 (+11%)\n🧅 পেঁয়াজ: ₹950 (-13%)\n🥔 আলু: ₹750 (+4%)',
    'ml': 'ഇന്നത്തെ മാർക്കറ്റ്:\n🍅 തക്കാളി: ₹1,500 (+11%)\n🧅 ഉള്ളി: ₹950 (-13%)\n🥔 ഉരുളക്കിഴങ്ങ്: ₹750 (+4%)',
    'or': 'ଆଜି ବଜାର:\n🍅 ଟମାଟୋ: ₹1,500 (+11%)\n🧅 ପିଆଜ: ₹950 (-13%)\n🥔 ଆଳୁ: ₹750 (+4%)',
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(appLangProvider);
      if (_languages.containsKey(lang) && lang != _selectedLang) {
        setState(() => _selectedLang = lang);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _submitText(String q) {
    if (q.trim().isEmpty) return;
    _textCtrl.clear();
    setState(() { _transcribed = q.trim(); _isProcessing = true; _response = ''; });
    _fetchRealResponse(q.trim()).then((resp) {
      if (!mounted) return;
      setState(() { _response = resp; _isProcessing = false; });
    });
  }

  // Detect commodity name from query text
  String? _detectCommodity(String ql) {
    const map = {
      'Tomato':   ['tomato','टमाटर','టమాట','தக்காளி','ಟೊಮೆಟೊ','टोमॅटो','ટામેટ','ਟਮਾਟਰ','টমেটো','തക്കാളി','ଟମାଟୋ'],
      'Onion':    ['onion','प्याज','ఉల్లి','வெங்காயம்','ಈರುಳ್ಳಿ','कांदा','ડુંગળી','ਪਿਆਜ਼','পেঁয়াজ','ഉള്ളി','ପିଆଜ'],
      'Potato':   ['potato','आलू','బంగాళదుంప','உருளைக்கிழங்கு','ಆಲೂ','बटाटा','બટેટ','ਆਲੂ','আলু','ഉരുളക്കിഴ','ଆଳୁ'],
      'Wheat':    ['wheat','गेहूं','గోధుమ','கோதுமை','ಗೋಧಿ','गहू','ઘઉ','ਕਣਕ','গম','ഗോതമ്പ','ଗହମ'],
      'Rice':     ['rice','चावल','వరి','அரிசி','ಭತ್ತ','तांदूळ','ચોખ','ਚਾਵਲ','চাল','അരി','ଚାଉଳ'],
      'Cotton':   ['cotton','कपास','పత్తి','பருத்தி','ಹತ್ತಿ','कापूस','કપાસ','ਕਪਾਹ','তুলা','പരുത്തി','କପା'],
      'Maize':    ['maize','corn','मक्का','మొక్కజొన్న','மக்காச்சோளம்','ಮೆಕ್ಕೆಜೋಳ','मका','મકઈ','ਮੱਕੀ','ভুট্টা','ചോളം','ମକା'],
      'Soybean':  ['soybean','soyabean','soya','सोयाबीन','సోయాబీన్','சோயா','ಸೋಯಾ','सोयाबीन','સોયા','ਸੋਇਆ','সয়া','സോയ','ସୋୟା'],
      'Chillies': ['chilli','chillies','chili','मिर्च','మిర్చి','மிளகாய்','ಮೆಣಸು','मिरची','મરચ','ਮਿਰਚ','মরিচ','മുളക','ମିର୍ଚ'],
      'Groundnut':['groundnut','peanut','मूंगफली','వేరుశనగ','வேர்க்கடலை','ಕಡಲೆ','भुईमूग','મગફળ','ਮੂੰਗਫਲੀ','চিনাবাদাম','നിലക്കടല','ଚିନାବାଦାମ'],
      'Sugarcane':['sugarcane','गन्ना','చెరకు','கரும்பு','ಕಬ್ಬು','ऊस','શેરડી','ਗੰਨਾ','আখ','കരിമ്പ','ଆଖୁ'],
    };
    for (final entry in map.entries) {
      if (entry.value.any((k) => ql.contains(k))) return entry.key;
    }
    return null;
  }

  // Localized crop names for use in live responses
  static const _cropNames = {
    'Tomato':    {'hi':'टमाटर','en':'Tomato','te':'టమాట','ta':'தக்காளி','kn':'ಟೊಮೆಟೊ','mr':'टोमॅटो','gu':'ટામેટ','pa':'ਟਮਾਟਰ','bn':'টমেটো','ml':'തക്കാളി','or':'ଟମାଟୋ'},
    'Onion':     {'hi':'प्याज','en':'Onion','te':'ఉల్లి','ta':'வெங்காயம்','kn':'ಈರುಳ್ಳಿ','mr':'कांदा','gu':'ડુંગળી','pa':'ਪਿਆਜ਼','bn':'পেঁয়াজ','ml':'ഉള്ളി','or':'ପିଆଜ'},
    'Potato':    {'hi':'आलू','en':'Potato','te':'బంగాళదుంప','ta':'உருளை','kn':'ಆಲೂ','mr':'बटाटा','gu':'બટેટ','pa':'ਆਲੂ','bn':'আলু','ml':'ഉരുളക്കിഴ','or':'ଆଳୁ'},
    'Wheat':     {'hi':'गेहूं','en':'Wheat','te':'గోధుమ','ta':'கோதுமை','kn':'ಗೋಧಿ','mr':'गहू','gu':'ઘઉ','pa':'ਕਣਕ','bn':'গম','ml':'ഗോതമ്പ','or':'ଗହମ'},
    'Rice':      {'hi':'चावल','en':'Rice','te':'వరి','ta':'அரிசி','kn':'ಭತ್ತ','mr':'तांदूळ','gu':'ચોખ','pa':'ਚਾਵਲ','bn':'চাল','ml':'അരി','or':'ଚାଉଳ'},
    'Cotton':    {'hi':'कपास','en':'Cotton','te':'పత్తి','ta':'பருத்தி','kn':'ಹತ್ತಿ','mr':'कापूस','gu':'કપાસ','pa':'ਕਪਾਹ','bn':'তুলা','ml':'പരുത്തി','or':'କପା'},
    'Maize':     {'hi':'मक्का','en':'Maize','te':'మొక్కజొన్న','ta':'மக்காச்சோளம்','kn':'ಮೆಕ್ಕೆಜೋಳ','mr':'मका','gu':'મકઈ','pa':'ਮੱਕੀ','bn':'ভুট্টা','ml':'ചോളം','or':'ମକା'},
    'Chillies':  {'hi':'मिर्च','en':'Chillies','te':'మిర్చి','ta':'மிளகாய்','kn':'ಮೆಣಸು','mr':'मिरची','gu':'મરચ','pa':'ਮਿਰਚ','bn':'মরিচ','ml':'മുളക','or':'ମିର୍ଚ'},
    'Soybean':   {'hi':'सोयाबीन','en':'Soybean','te':'సోయాబీన్','ta':'சோயா','kn':'ಸೋಯಾ','mr':'सोयाबीन','gu':'સોયા','pa':'ਸੋਇਆ','bn':'সয়া','ml':'സോയ','or':'ସୋୟା'},
    'Groundnut': {'hi':'मूंगफली','en':'Groundnut','te':'వేరుశనగ','ta':'வேர்க்கடலை','kn':'ಕಡಲೆ','mr':'भुईमूग','gu':'મગફળ','pa':'ਮੂੰਗਫਲੀ','bn':'চিনাবাদাম','ml':'നിലക്കടല','or':'ଚିନାବାଦାମ'},
  };

  String _localCropName(String commodity, String lang) {
    return _cropNames[commodity]?[lang] ?? _cropNames[commodity]?['en'] ?? commodity;
  }

  Future<String> _fetchRealResponse(String q) async {
    final ql = q.toLowerCase();
    final lang = _selectedLang;

    // Always try to load market prices for context
    List<dynamic> livePrices = [];
    try {
      livePrices = await ref.read(apiProvider).fetchMarketPrices(limit: 10);
    } catch (_) {}

    final commodity = _detectCommodity(ql);
    final today = '${DateTime.now().day}/${DateTime.now().month}';

    // ── Price query ───────────────────────────────────────────────────────────
    if (_containsAny(ql, ['भाव','दाम','price','rate','cost','कीमत','मूल्य','ధర','రేటు','ఎంత','விலை','என்ன','ಬೆಲೆ','ಎಷ್ಟು','ভাও','দাম','কত','ਭਾਅ','ਦਰ','ਕੀਮਤ','किंमत','ദര','ദില','ଦର'])) {
      final matches = commodity != null
          ? livePrices.where((p) => p.commodity == commodity).toList()
          : livePrices;
      if (matches.isNotEmpty) {
        final p = matches.first;
        final name = _localCropName(p.commodity, lang);
        final modal = p.modalPrice.toInt();
        final prev = p.previousModalPrice ?? 0.0;
        final change = prev > 0 ? ((modal - prev) / prev * 100).toStringAsFixed(1) : null;
        final trend = change != null ? (double.parse(change) >= 0 ? '📈 +$change%' : '📉 $change%') : '';
        return _liveLabel(lang) + '\n'
            + _buildLivePriceAnswer(name, '₹$modal', p.market, p.state, today, lang)
            + (trend.isNotEmpty ? '\n$trend' : '');
      }
      return _priceResponses[lang] ?? _priceResponses['en']!;
    }

    // ── Market overview ───────────────────────────────────────────────────────
    if (_containsAny(ql, ['mandi','market','मंडी','बाजार','మార్కెట్','மார்கெட்','ಮಾರುಕಟ್ಟೆ','বাজার','ਮੰਡੀ','മാർക്കറ്റ്','ବଜାର'])) {
      if (livePrices.isNotEmpty) {
        return _liveLabel(lang) + '\n' + _buildMarketOverview(livePrices, lang);
      }
      return _marketResponses[lang] ?? _marketResponses['en']!;
    }

    // ── Crop recommendation — show top-priced crops ───────────────────────────
    if (_containsAny(ql, ['फसल','खेती','बोना','crop','grow','plant','sow','పంట','வேయాలి','பயிர்','ಬೆಳೆ','ফসল','চাষ','ਫਸਲ','ਖੇਤੀ','วิล','ଫସଲ'])) {
      if (livePrices.isNotEmpty) {
        final sorted = [...livePrices]..sort((a, b) => b.modalPrice.compareTo(a.modalPrice));
        final top3 = sorted.take(3).toList();
        final lines = top3.map((p) => '• ${_localCropName(p.commodity, lang)}: ₹${p.modalPrice.toInt()}${_perQtlLabel(lang)}').join('\n');
        return _liveLabel(lang) + '\n' + _buildCropRecoLive(lines, lang);
      }
      return _cropResponses[lang] ?? _cropResponses['en']!;
    }

    // ── Sell timing — use live price trend ────────────────────────────────────
    if (_containsAny(ql, ['बेच','sell','when','कब','అమ్మ','விற்','ಮಾರ','বিক্রি','ਵੇਚ','विक्री','വിൽ','ବିକ୍ର'])) {
      if (livePrices.isNotEmpty) {
        // Find commodity in question or pick top priced crop
        final target = commodity != null
            ? livePrices.firstWhere((p) => p.commodity == commodity, orElse: () => livePrices.first)
            : (([...livePrices]..sort((a,b) => b.modalPrice.compareTo(a.modalPrice))).first);
        final name = _localCropName(target.commodity, lang);
        final modal = target.modalPrice.toInt();
        final prev = target.previousModalPrice ?? 0.0;
        final rising = prev > 0 && modal > prev;
        return _liveLabel(lang) + '\n' + _buildSellAdviceLive(name, '₹$modal', rising, lang);
      }
      return _sellResponses[lang] ?? _sellResponses['en']!;
    }

    // ── MSP / govt / loans / fertilizer — static but always accurate ─────────
    if (_containsAny(ql, ['msp','minimum','support','government','सरकार','न्यूनतम','pm kisan','kisan','ప్రభుత్వ','அரசு','ಸರ್ಕಾರ','সরকার','ਸਰਕਾਰ'])) {
      return _mspResponses[lang] ?? _mspResponses['en']!;
    }
    if (_containsAny(ql, ['खाद','उर्वरक','fertilizer','manure','urea','dap','ఎరువు','உரம்','ಗೊಬ್ಬರ','সার','ਖਾਦ','வளம்','ସାର'])) {
      return _fertilizerResponses[lang] ?? _fertilizerResponses['en']!;
    }
    if (_containsAny(ql, ['loan','credit','लोन','ऋण','kcc','scheme','yojana','రుణం','கடன்','ಸಾಲ','ঋণ','ਕਰਜ਼','ബാങ്ക്'])) {
      return _loanResponses[lang] ?? _loanResponses['en']!;
    }
    if (_containsAny(ql, ['मौसम','बारिश','weather','rain','temperature','forecast','వాతావరణ','வானிலை','ಹವಾಮಾನ','আবহাওয়া','ਮੌਸਮ','കാലാവസ്ഥ'])) {
      return _weatherResponses[lang] ?? _weatherResponses['en']!;
    }

    // ── ANY other question — always show live market data ──────────────────
    if (livePrices.isNotEmpty) {
      // If a commodity was detected in the question, show its price
      if (commodity != null) {
        final match = livePrices.where((p) => p.commodity == commodity).toList();
        if (match.isNotEmpty) {
          final p = match.first;
          final name = _localCropName(p.commodity, lang);
          return _liveLabel(lang) + '\n'
              + _buildLivePriceAnswer(name, '₹${p.modalPrice.toInt()}', p.market, p.state, today, lang);
        }
      }
      // Otherwise show full market overview with top crops and sell advice
      final sorted = [...livePrices]..sort((a, b) => b.modalPrice.compareTo(a.modalPrice));
      final top = sorted.first;
      final topName = _localCropName(top.commodity, lang);
      final overview = _buildMarketOverview(livePrices.take(5).toList(), lang);
      final prev = top.previousModalPrice ?? 0.0;
      final rising = prev > 0 && top.modalPrice > prev;
      final sellAdvice = _buildSellAdviceLive(topName, '₹${top.modalPrice.toInt()}', rising, lang);
      return _liveLabel(lang) + '\n' + overview + '\n\n' + sellAdvice;
    }
    return _defaultResponses[lang] ?? _defaultResponses['en']!;
  }

  String _liveLabel(String lang) {
    const m = {
      'hi':'📡 लाइव मार्केट डेटा:','en':'📡 Live Market Data:','te':'📡 లైవ్ మార్కెట్ డేటా:',
      'ta':'📡 நேரடி சந்தை தரவு:','kn':'📡 ಲೈವ್ ಮಾರ್ಕೆಟ್ ಡೇಟಾ:','mr':'📡 लाइव्ह बाजार डेटा:',
      'gu':'📡 લાઇવ બજાર ડેટા:','pa':'📡 ਲਾਈਵ ਮੰਡੀ ਡੇਟਾ:','bn':'📡 লাইভ বাজার ডেটা:',
      'ml':'📡 തത്സമയ വിപണി ഡേറ്റ:','or':'📡 ଲାଇଭ ବଜାର ଡାଟା:',
    };
    return m[lang] ?? m['en']!;
  }

  String _buildCropRecoLive(String lines, String lang) {
    const m = {
      'hi':'आज के सबसे ऊंचे भाव की फसलें:\n{lines}\n\nये फसलें अभी सबसे ज़्यादा मुनाफा दे रही हैं। 🌾',
      'en':'Today\'s highest-priced crops:\n{lines}\n\nThese crops are giving maximum profit right now. 🌾',
      'te':'నేటి అత్యధిక ధర పంటలు:\n{lines}\n\nఇవి ఇప్పుడు అత్యధిక లాభాన్ని ఇస్తున్నాయి. 🌾',
      'ta':'இன்றைய அதிக விலை பயிர்கள்:\n{lines}\n\nஇவை இப்போது அதிகமான லாபம் தருகின்றன. 🌾',
      'kn':'ಇಂದಿನ ಹೆಚ್ಚಿನ ಬೆಲೆ ಬೆಳೆಗಳು:\n{lines}\n\nಇವು ಈಗ ಹೆಚ್ಚಿನ ಲಾಭ ನೀಡುತ್ತಿವೆ. 🌾',
      'mr':'आजचे सर्वाधिक भावाचे पिके:\n{lines}\n\nही पिके आता सर्वाधिक नफा देत आहेत. 🌾',
      'gu':'આજના સૌથી ઊંચા ભાવના પાક:\n{lines}\n\nઆ પાક હવે સૌથી વધુ નફો આપી રહ્યા છે. 🌾',
      'pa':'ਅੱਜ ਦੀਆਂ ਸਭ ਤੋਂ ਵੱਧ ਭਾਅ ਫਸਲਾਂ:\n{lines}\n\nਇਹ ਫਸਲਾਂ ਹੁਣ ਸਭ ਤੋਂ ਵੱਧ ਮੁਨਾਫਾ ਦੇ ਰਹੀਆਂ ਹਨ। 🌾',
      'bn':'আজকের সর্বোচ্চ দামের ফসল:\n{lines}\n\nএই ফসলগুলো এখন সর্বোচ্চ মুনাফা দিচ্ছে। 🌾',
      'ml':'ഇന്നത്തെ ഉയർന്ന വിലയുള്ള വിളകൾ:\n{lines}\n\nഇവ ഇപ്പോൾ ഏറ്റവും കൂടുതൽ ലാഭം നൽകുന്നു. 🌾',
      'or':'ଆଜିର ସର୍ବୋଚ୍ଚ ଦରରେ ଫସଲ:\n{lines}\n\nଏଗୁଡ଼ିକ ଏବେ ସର୍ବାଧିକ ଲାଭ ଦେଉଛି। 🌾',
    };
    return (m[lang] ?? m['en']!).replaceAll('{lines}', lines);
  }

  String _buildSellAdviceLive(String name, String price, bool rising, String lang) {
    if (rising) {
      const m = {
        'hi':'{name} आज {price}/क्विंटल पर है और बढ़ रहा है। अगले 2-3 दिन और रुकें, भाव और ऊपर जा सकता है। 💰📈',
        'en':'{name} is at {price}/qtl today and rising. Hold 2-3 more days for better price. 💰📈',
        'te':'{name} ఈరోజు {price}/క్వి ఉంది మరియు పెరుగుతోంది. మరో 2-3 రోజులు ఆగండి. 💰📈',
        'ta':'{name} இன்று {price}/குவி மற்றும் உயர்கிறது. 2-3 நாட்கள் காத்திருங்கள். 💰📈',
        'kn':'{name} ಇಂದು {price}/ಕ್ವಿ ಮತ್ತು ಹೆಚ್ಚಾಗುತ್ತಿದೆ. 2-3 ದಿನ ತಡೆಯಿರಿ. 💰📈',
        'mr':'{name} आज {price}/क्विंटल आहे व वाढत आहे. 2-3 दिवस थांबा. 💰📈',
        'gu':'{name} આજ {price}/ક્વિ છે ને વધી રહ્યો છે. 2-3 દિવસ રાહ જુઓ. 💰📈',
        'pa':'{name} ਅੱਜ {price}/ਕੁਇੰਟਲ ਅਤੇ ਵੱਧ ਰਿਹਾ ਹੈ। 2-3 ਦਿਨ ਉਡੀਕ ਕਰੋ। 💰📈',
        'bn':'{name} আজ {price}/কুইন্টাল এবং বাড়ছে। 2-3 দিন অপেক্ষা করুন। 💰📈',
        'ml':'{name} ഇന്ന് {price}/ക്വി, ഉയരുന്നുണ്ട്. 2-3 ദിവസം കൂടി കാത്തിരിക്കുക. 💰📈',
        'or':'{name} ଆଜି {price}/କ୍ୱି ଏବଂ ବଢ଼ୁଛି। 2-3 ଦିନ ଅପେକ୍ଷା କରନ୍ତୁ। 💰📈',
      };
      return (m[lang] ?? m['en']!).replaceAll('{name}', name).replaceAll('{price}', price);
    } else {
      const m = {
        'hi':'{name} आज {price}/क्विंटल पर है और नीचे आ सकता है। अभी बेच दें, और रुकना नुकसान हो सकता है। 💰📉',
        'en':'{name} is at {price}/qtl today and may fall. Sell now to avoid loss. 💰📉',
        'te':'{name} ఈరోజు {price}/క్వి ఉంది మరియు తగ్గవచ్చు. ఇప్పుడే అమ్మండి. 💰📉',
        'ta':'{name} இன்று {price}/குவி மற்றும் விழலாம். இப்போதே விற்கவும். 💰📉',
        'kn':'{name} ಇಂದು {price}/ಕ್ವಿ ಮತ್ತು ಇಳಿಯಬಹುದು. ಈಗ ಮಾರಿ. 💰📉',
        'mr':'{name} आज {price}/क्विंटल आहे व खाली येऊ शकतो. आत्ता विका. 💰📉',
        'gu':'{name} આજ {price}/ક્વિ અને ઘટી શકે. અત્યારે વેચો. 💰📉',
        'pa':'{name} ਅੱਜ {price}/ਕੁਇੰਟਲ ਅਤੇ ਘੱਟ ਸਕਦਾ ਹੈ। ਹੁਣੇ ਵੇਚੋ। 💰📉',
        'bn':'{name} আজ {price}/কুইন্টাল এবং নামতে পারে। এখনই বিক্রি করুন। 💰📉',
        'ml':'{name} ഇന്ന് {price}/ക്വി, കുറഞ്ഞേക്കാം. ഇപ്പോൾ വിൽക്കുക. 💰📉',
        'or':'{name} ଆଜି {price}/କ୍ୱି ଏବଂ ଘଟିପାରେ। ଏବେ ବିକ୍ରି କରନ୍ତୁ। 💰📉',
      };
      return (m[lang] ?? m['en']!).replaceAll('{name}', name).replaceAll('{price}', price);
    }
  }

  String _buildLivePriceAnswer(String commodity, String modal, String market, String state, String date, String lang) {
    final templates = {
      'hi': '$commodity का आज ($date) मोडल भाव $modal/क्विंटल है।\nमंडी: $market, $state 📊\n(स्रोत: Agmarknet)',
      'en': '$commodity modal price today ($date): $modal/quintal\nMarket: $market, $state 📊\n(Source: Agmarknet)',
      'te': '$commodity ఈరోజు ($date) మోడల్ ధర: $modal/క్వింటల్\nమార్కెట్: $market, $state 📊',
      'ta': '$commodity இன்று ($date) மோடல் விலை: $modal/குவிண்டால்\nசந்தை: $market, $state 📊',
      'kn': '$commodity ಇಂದು ($date) ಮೋಡಲ್ ಬೆಲೆ: $modal/ಕ್ವಿಂಟಾಲ್\nಮಾರ್ಕೆಟ್: $market, $state 📊',
      'mr': '$commodity आज ($date) मोडल भाव: $modal/क्विंटल\nबाजार: $market, $state 📊',
      'gu': '$commodity આજ ($date) મોડલ ભાવ: $modal/ક્વિ\nબજાર: $market, $state 📊',
      'pa': '$commodity ਅੱਜ ($date) ਮੋਡਲ ਭਾਅ: $modal/ਕੁਇੰਟਲ\nਮੰਡੀ: $market, $state 📊',
      'bn': '$commodity আজ ($date) মডেল দর: $modal/কুইন্টাল\nবাজার: $market, $state 📊',
      'ml': '$commodity ഇന്ന് ($date) മോഡൽ വില: $modal/ക്വിന്റൽ\nമാർക്കറ്റ്: $market, $state 📊',
      'or': '$commodity ଆଜି ($date) ମୋଡ଼ଲ ଦର: $modal/କ୍ୱିଣ୍ଟାଲ\nବଜାର: $market, $state 📊',
    };
    return templates[lang] ?? templates['en']!;
  }

  String _buildMarketOverview(List<dynamic> prices, String lang) {
    final lines = prices.take(3).map((p) => '• ${p.commodity}: ₹${p.modalPrice.toInt()}${_perQtlLabel(lang)} (${p.market})').join('\n');
    final headers = {
      'hi': 'आज के ताज़ा मंडी भाव:\n$lines\n(स्रोत: Agmarknet) 📊',
      'en': 'Today\'s live market prices:\n$lines\n(Source: Agmarknet) 📊',
      'te': 'నేటి మార్కెట్ ధరలు:\n$lines\n(మూలం: Agmarknet) 📊',
      'ta': 'இன்றைய சந்தை விலைகள்:\n$lines\n(ஆதாரம்: Agmarknet) 📊',
      'kn': 'ಇಂದಿನ ಮಾರ್ಕೆಟ್ ಬೆಲೆ:\n$lines\n(ಮೂಲ: Agmarknet) 📊',
      'mr': 'आजचे बाजारभाव:\n$lines\n(स्रोत: Agmarknet) 📊',
      'gu': 'આજના બજાર ભાવ:\n$lines\n(સ્ત્રોત: Agmarknet) 📊',
      'pa': 'ਅੱਜ ਦੇ ਮੰਡੀ ਭਾਅ:\n$lines\n(ਸਰੋਤ: Agmarknet) 📊',
      'bn': 'আজকের বাজার দর:\n$lines\n(উৎস: Agmarknet) 📊',
      'ml': 'ഇന്നത്തെ വിപണി വില:\n$lines\n(ഉറവിടം: Agmarknet) 📊',
      'or': 'ଆଜି ବଜାର ଦର:\n$lines\n(ଉତ୍ସ: Agmarknet) 📊',
    };
    return headers[lang] ?? headers['en']!;
  }

  String _perQtlLabel(String lang) {
    const m = {
      'hi':'/क्विंटल','en':'/qtl','te':'/క్వి','ta':'/குவி','kn':'/ಕ್ವಿ',
      'mr':'/क्विं','gu':'/ક્વિ','pa':'/ਕੁਇੰ','bn':'/কুই','ml':'/ക്വി','or':'/କ୍ୱି',
    };
    return m[lang] ?? '/qtl';
  }

  static const _weatherResponses = {
    'hi': 'आज का मौसम: 28°C, 72% नमी। अगले 3 दिन बारिश की संभावना है। फसल की सिंचाई कम करें। ⛅🌧️',
    'en': 'Today: 28°C, 72% humidity. Rain expected in next 3 days. Reduce irrigation accordingly. ⛅🌧️',
    'te': 'ఈరోజు: 28°C, 72% తేమ. వచ్చే 3 రోజుల్లో వర్షం అవకాశం. నీటి తడి తగ్గించండి. ⛅🌧️',
    'ta': 'இன்று: 28°C, 72% ஈரப்பதம். அடுத்த 3 நாட்களில் மழை வாய்ப்பு. நீர்ப்பாசனம் குறையுங்கள். ⛅🌧️',
    'kn': 'ಇಂದು: 28°C, 72% ತೇವ. ಮುಂದಿನ 3 ದಿನ ಮಳೆ ನಿರೀಕ್ಷೆ. ನೀರಾವರಿ ಕಡಿಮೆ ಮಾಡಿ. ⛅🌧️',
    'mr': 'आज: 28°C, 72% आर्द्रता. पुढील 3 दिवस पाऊस शक्य. सिंचन कमी करा. ⛅🌧️',
    'gu': 'આજ: 28°C, 72% ભેજ. આગામી 3 દિવસ વરસાદ. સિંચાઈ ઓછી કરો. ⛅🌧️',
    'pa': 'ਅੱਜ: 28°C, 72% ਨਮੀ। ਅਗਲੇ 3 ਦਿਨ ਮੀਂਹ ਦੀ ਸੰਭਾਵਨਾ। ਸਿੰਚਾਈ ਘੱਟ ਕਰੋ। ⛅🌧️',
    'bn': 'আজ: 28°C, 72% আর্দ্রতা। আগামী 3 দিন বৃষ্টির সম্ভাবনা। সেচ কমান। ⛅🌧️',
    'ml': 'ഇന്ന്: 28°C, 72% ഈർപ്പം. അടുത്ത 3 ദിവസം മഴ. ജലസേചനം കുറയ്ക്കുക. ⛅🌧️',
    'or': 'ଆଜି: 28°C, 72% ଆର୍ଦ୍ରତା। ଆଗାମୀ 3 ଦିନ ବର୍ଷା। ଜଳ ସଞ୍ଚୟ କରନ୍ତୁ। ⛅🌧️',
  };

  static const _sellResponses = {
    'hi': 'बेचने का सही समय: टमाटर अभी 11% ऊपर है। 2-3 दिन में और बढ़ सकता है। आज़ादपुर मंडी सबसे अच्छा दाम दे रही है। 💰',
    'en': 'Best time to sell: Tomato is up 11% now. May rise further in 2-3 days. Azadpur market offers best price. 💰',
    'te': 'అమ్మడానికి సరైన సమయం: టమాట ఇప్పుడు 11% పెరిగింది. 2-3 రోజుల్లో మరింత పెరగవచ్చు. 💰',
    'ta': 'விற்க சரியான நேரம்: தக்காளி இப்போது 11% அதிகம். 2-3 நாட்களில் மேலும் உயரலாம். 💰',
    'kn': 'ಮಾರಲು ಸರಿಯಾದ ಸಮಯ: ಟೊಮೆಟೊ ಈಗ 11% ಜಾಸ್ತಿ. 2-3 ದಿನದಲ್ಲಿ ಇನ್ನಷ್ಟು ಹೆಚ್ಚಬಹುದು. 💰',
    'mr': 'विकण्याची योग्य वेळ: टोमॅटो आता 11% वर आहे. 2-3 दिवसात आणखी वाढू शकतो. 💰',
    'gu': 'વેચવાનો સારો સમય: ટામેટા હવે 11% ઉપર છે. 2-3 દિવસમાં વધુ વધી શકે. 💰',
    'pa': 'ਵੇਚਣ ਦਾ ਸਹੀ ਸਮਾਂ: ਟਮਾਟਰ ਹੁਣ 11% ਉੱਪਰ ਹੈ। 2-3 ਦਿਨਾਂ ਵਿੱਚ ਹੋਰ ਵਧ ਸਕਦਾ ਹੈ। 💰',
    'bn': 'বিক্রির সঠিক সময়: টমেটো এখন 11% বেশি। 2-3 দিনে আরও বাড়তে পারে। 💰',
    'ml': 'വിൽക്കാൻ നല്ല സമയം: തക്കാളി ഇപ്പോൾ 11% കൂടുതൽ. 2-3 ദിവസം കൂടി കാത്തിരിക്കാം. 💰',
    'or': 'ବିକ୍ରି ପାଇଁ ଭଲ ସମୟ: ଟମାଟୋ ଏବେ 11% ଉପରେ। 2-3 ଦିନ ଅପେକ୍ଷା କରନ୍ତୁ। 💰',
  };

  static const _mspResponses = {
    'hi': 'MSP (न्यूनतम समर्थन मूल्य) 2024-25:\n🌾 गेहूं: ₹2,275/क्विंटल\n🌾 धान: ₹2,300/क्विंटल\n🫘 सोयाबीन: ₹4,892/क्विंटल\nसरकारी खरीद केंद्र पर सीधे बेचें। 🏛️',
    'en': 'MSP (Minimum Support Price) 2024-25:\n🌾 Wheat: ₹2,275/qtl\n🌾 Paddy: ₹2,300/qtl\n🫘 Soybean: ₹4,892/qtl\nSell directly at govt procurement centre. 🏛️',
    'te': 'MSP 2024-25:\n🌾 గోధుమ: ₹2,275/క్వి\n🌾 వరి: ₹2,300/క్వి\n🫘 సోయాబీన్: ₹4,892/క్వి\nప్రభుత్వ కొనుగోలు కేంద్రంలో అమ్మండి. 🏛️',
    'ta': 'MSP 2024-25:\n🌾 கோதுமை: ₹2,275/குவி\n🌾 நெல்: ₹2,300/குவி\nஅரசு கொள்முதல் மையத்தில் விற்கவும். 🏛️',
    'kn': 'MSP 2024-25:\n🌾 ಗೋಧಿ: ₹2,275/ಕ್ವಿ\n🌾 ಭತ್ತ: ₹2,300/ಕ್ವಿ\nಸರ್ಕಾರಿ ಖರೀದಿ ಕೇಂದ್ರದಲ್ಲಿ ಮಾರಿ. 🏛️',
    'mr': 'MSP 2024-25:\n🌾 गहू: ₹2,275/क्विंटल\n🌾 धान: ₹2,300/क्विंटल\nसरकारी खरेदी केंद्रावर विका. 🏛️',
    'gu': 'MSP 2024-25:\n🌾 ઘઉં: ₹2,275/ક્વિ\n🌾 ડાંગર: ₹2,300/ક્વિ\nસરકારી ખરીદ કેન્દ્ર પર વેચો. 🏛️',
    'pa': 'MSP 2024-25:\n🌾 ਕਣਕ: ₹2,275/ਕੁਇੰਟਲ\n🌾 ਝੋਨਾ: ₹2,300/ਕੁਇੰਟਲ\nਸਰਕਾਰੀ ਖਰੀਦ ਕੇਂਦਰ ਤੇ ਵੇਚੋ। 🏛️',
    'bn': 'MSP 2024-25:\n🌾 গম: ₹2,275/কুইন্টাল\n🌾 ধান: ₹2,300/কুইন্টাল\nসরকারি ক্রয় কেন্দ্রে বিক্রি করুন। 🏛️',
    'ml': 'MSP 2024-25:\n🌾 ഗോതമ്പ്: ₹2,275/ക്വി\n🌾 നെല്ല്: ₹2,300/ക്വി\nസർക്കാർ സംഭരണ കേന്ദ്രത്തിൽ വിൽക്കുക. 🏛️',
    'or': 'MSP 2024-25:\n🌾 ଗହମ: ₹2,275/କ୍ୱି\n🌾 ଧାନ: ₹2,300/କ୍ୱି\nସରକାରୀ କ୍ରୟ କେନ୍ଦ୍ରରେ ବିକ୍ରୟ କରନ୍ତୁ। 🏛️',
  };

  static const _fertilizerResponses = {
    'hi': 'खाद और उर्वरक सुझाव:\n• यूरिया: ₹266/बैग (45kg) — नाइट्रोजन के लिए\n• DAP: ₹1,350/बैग — फूलने के समय\n• जैविक खाद हर 6 महीने में डालें 🌿',
    'en': 'Fertilizer tips:\n• Urea: ₹266/bag (45kg) — for nitrogen\n• DAP: ₹1,350/bag — during flowering\n• Apply organic manure every 6 months 🌿',
    'te': 'ఎరువుల సూచన:\n• యూరియా: ₹266/బ్యాగ్ — నైట్రోజన్ కోసం\n• DAP: ₹1,350/బ్యాగ్ — పువ్వు వేళ\n• 6 నెలలకొకసారి కంపోస్ట్ వేయండి 🌿',
    'ta': 'உர குறிப்புகள்:\n• யூரியா: ₹266/பை — நைட்ரஜனுக்கு\n• DAP: ₹1,350/பை — பூக்கும் நேரம்\n• 6 மாதத்திற்கு ஒருமுறை கம்போஸ்ட் 🌿',
    'kn': 'ಗೊಬ್ಬರ ಸಲಹೆ:\n• ಯೂರಿಯಾ: ₹266/ಚೀಲ — ಸಾರಜನಕಕ್ಕೆ\n• DAP: ₹1,350/ಚೀಲ — ಹೂ ಬಿಡುವ ಸಮಯ 🌿',
    'mr': 'खत सूचना:\n• युरिया: ₹266/पोते — नायट्रोजनसाठी\n• DAP: ₹1,350/पोते — फुलोऱ्याच्या वेळी 🌿',
    'gu': 'ખાતર સૂચન:\n• યુરિયા: ₹266/બેગ — નાઈટ્રોજન\n• DAP: ₹1,350/બેગ — ફૂલ વખતે 🌿',
    'pa': 'ਖਾਦ ਸੁਝਾਅ:\n• ਯੂਰੀਆ: ₹266/ਬੋਰੀ — ਨਾਈਟ੍ਰੋਜਨ\n• DAP: ₹1,350/ਬੋਰੀ — ਫੁੱਲ ਵੇਲੇ 🌿',
    'bn': 'সার পরামর্শ:\n• ইউরিয়া: ₹266/ব্যাগ — নাইট্রোজেন\n• DAP: ₹1,350/ব্যাগ — ফুলের সময় 🌿',
    'ml': 'വളം നിർദ്ദേശം:\n• യൂറിയ: ₹266/ചാക്ക് — നൈട്രജൻ\n• DAP: ₹1,350/ചാക്ക് — പൂക്കൾ 🌿',
    'or': 'ସାର ପରାମର୍ଶ:\n• ୟୁରିଆ: ₹266/ବୋଝ — ଯବକ୍ଷାର\n• DAP: ₹1,350/ବୋଝ — ଫୁଲ ସମୟ 🌿',
  };

  static const _loanResponses = {
    'hi': 'किसान क्रेडिट कार्ड (KCC):\n• 3 लाख तक 4% ब्याज पर ऋण\n• PM Kisan: ₹6,000/साल सीधे खाते में\n• नजदीकी बैंक या CSC से आवेदन करें 🏦',
    'en': 'Kisan Credit Card (KCC):\n• Loan up to ₹3 lakh at 4% interest\n• PM Kisan: ₹6,000/year direct benefit\n• Apply at nearest bank or CSC 🏦',
    'te': 'కిసాన్ క్రెడిట్ కార్డ్ (KCC):\n• ₹3 లక్ష వరకు 4% వడ్డీకి రుణం\n• PM కిసాన్: ₹6,000/సంవత్సరం\n• సమీప బ్యాంకులో దరఖాస్తు చేయండి 🏦',
    'ta': 'கிசான் கிரெடிட் கார்டு:\n• ₹3 லட்சம் வரை 4% வட்டியில்\n• PM கிசான்: ₹6,000/ஆண்டு\n• அருகில் உள்ள வங்கியில் விண்ணப்பிக்கவும் 🏦',
    'kn': 'ಕಿಸಾನ್ ಕ್ರೆಡಿಟ್ ಕಾರ್ಡ್:\n• ₹3 ಲಕ್ಷ ವರೆಗೆ 4% ಬಡ್ಡಿ\n• PM ಕಿಸಾನ್: ₹6,000/ವರ್ಷ 🏦',
    'mr': 'किसान क्रेडिट कार्ड:\n• ₹3 लाख पर्यंत 4% व्याजावर\n• PM किसान: ₹6,000/वर्ष 🏦',
    'gu': 'કિસાન ક્રેડિટ કાર્ડ:\n• ₹3 લાખ સુધી 4% વ્યાજ\n• PM કિસાન: ₹6,000/વર્ષ 🏦',
    'pa': 'ਕਿਸਾਨ ਕ੍ਰੈਡਿਟ ਕਾਰਡ:\n• ₹3 ਲੱਖ ਤੱਕ 4% ਵਿਆਜ\n• PM ਕਿਸਾਨ: ₹6,000/ਸਾਲ 🏦',
    'bn': 'কিসান ক্রেডিট কার্ড:\n• ₹3 লাখ পর্যন্ত 4% সুদে\n• PM কিসান: ₹6,000/বছর 🏦',
    'ml': 'കിസാൻ ക്രെഡിറ്റ് കാർഡ്:\n• ₹3 ലക്ഷം വരെ 4% പലിശ\n• PM കിസാൻ: ₹6,000/വർഷം 🏦',
    'or': 'କିସାନ କ୍ରେଡ଼ିଟ କାର୍ଡ:\n• ₹3 ଲକ୍ଷ ପର୍ଯ୍ୟନ୍ତ 4% ସୁଧ\n• PM କିସାନ: ₹6,000/ବର୍ଷ 🏦',
  };

  static const _defaultResponses = {
    'hi': 'आपका सवाल समझ आया। 🤔\nAgriConnect पर आप पूछ सकते हैं:\n• भाव/दाम — मंडी भाव जानें\n• फसल/खेती — सलाह पाएं\n• मौसम — आज का मौसम\n• बेचना/कब बेचूं — बेचने का समय\n• MSP — सरकारी दाम\n• खाद/उर्वरक — खाद सलाह\n• लोन/किसान क्रेडिट — सरकारी योजनाएं',
    'en': 'I understood your question. 🤔\nYou can ask AgriConnect about:\n• Price/rate — market prices\n• Crop/farming — advice\n• Weather — today\'s forecast\n• Sell/when to sell — best time\n• MSP — government prices\n• Fertilizer/manure — tips\n• Loan/KCC — govt schemes',
    'te': 'మీ ప్రశ్న అర్థమైంది. 🤔\nAgriConnect లో అడగవచ్చు:\n• ధర/రేటు — మార్కెట్ ధరలు\n• పంట/వ్యవసాయం — సలహా\n• వాతావరణం — నేటి అంచనా\n• అమ్మడం — మంచి సమయం\n• MSP — ప్రభుత్వ ధర\n• ఎరువు — సూచనలు',
    'ta': 'உங்கள் கேள்வி புரிந்தது. 🤔\nAgriConnect இல் கேட்கலாம்:\n• விலை/தர — சந்தை விலை\n• பயிர்/விவசாயம் — ஆலோசனை\n• வானிலை — இன்றைய முன்னறிவிப்பு\n• விற்பனை — சரியான நேரம்\n• MSP — அரசு விலை',
    'kn': 'ನಿಮ್ಮ ಪ್ರಶ್ನೆ ಅರ್ಥವಾಯಿತು. 🤔\nAgriConnect ನಲ್ಲಿ ಕೇಳಬಹುದು:\n• ಬೆಲೆ/ದರ — ಮಾರುಕಟ್ಟೆ ಬೆಲೆ\n• ಬೆಳೆ/ಕೃಷಿ — ಸಲಹೆ\n• ಹವಾಮಾನ — ಇಂದಿನ ಮುನ್ಸೂಚನೆ\n• ಮಾರಾಟ — ಸರಿಯಾದ ಸಮಯ',
    'mr': 'तुमचा प्रश्न समजला. 🤔\nAgriConnect वर विचारा:\n• भाव/दर — बाजारभाव\n• पीक/शेती — सल्ला\n• हवामान — आजचा अंदाज\n• विक्री — योग्य वेळ\n• MSP — सरकारी दर',
    'gu': 'તમારો સવાલ સમજ્યો. 🤔\nAgriConnect માં પૂછો:\n• ભાવ/દર — બજાર ભાવ\n• પાક/ખેતી — સલાહ\n• હવામાન — આજનો અંદાજ\n• વેચવું — સારો સમય',
    'pa': 'ਤੁਹਾਡਾ ਸਵਾਲ ਸਮਝ ਆਇਆ। 🤔\nAgriConnect ਤੇ ਪੁੱਛੋ:\n• ਭਾਅ/ਦਰ — ਮੰਡੀ ਭਾਅ\n• ਫਸਲ/ਖੇਤੀ — ਸਲਾਹ\n• ਮੌਸਮ — ਅੱਜ ਦਾ ਅੰਦਾਜ਼ਾ\n• ਵੇਚਣਾ — ਸਹੀ ਸਮਾਂ',
    'bn': 'আপনার প্রশ্ন বুঝেছি। 🤔\nAgriConnect এ জিজ্ঞেস করুন:\n• দাম/ভাও — বাজার দর\n• ফসল/চাষ — পরামর্শ\n• আবহাওয়া — আজকের পূর্বাভাস\n• বিক্রি — সঠিক সময়',
    'ml': 'നിങ്ങളുടെ ചോദ്യം മനസ്സിലായി. 🤔\nAgriConnect ൽ ചോദിക്കാം:\n• വില/നിരക്ക് — വിപണി വില\n• വിള/കൃഷി — ഉപദേശം\n• കാലാവസ്ഥ — ഇന്നത്തെ പ്രവചനം\n• വിൽക്കൽ — നല്ല സമയം',
    'or': 'ଆପଣଙ୍କ ପ୍ରଶ୍ନ ବୁଝିଲି। 🤔\nAgriConnect ରେ ପଚାରନ୍ତୁ:\n• ଦର/ଭାଓ — ବଜାର ଦର\n• ଫସଲ/ଚାଷ — ପରାମର୍ଶ\n• ପାଣିପାଗ — ଆଜିର ଅନୁମାନ\n• ବିକ୍ରି — ସଠିକ ସମୟ',
  };

  String _getResponse(String q) {
    final ql = q.toLowerCase();

    // Price
    if (_containsAny(ql, ['भाव', 'दाम', 'price', 'rate', 'cost', 'ధర', 'రేటు', 'விலை', 'ಬೆಲೆ', 'ದರ', 'ভাও', 'দাম', 'ਭਾਅ', 'ਦਰ', 'ભાવ', 'ദില', 'വില', 'ଦର', 'किंमत', 'कितना'])) {
      return _priceResponses[_selectedLang] ?? _priceResponses['en']!;
    }
    // Crop recommendation
    if (_containsAny(ql, ['फसल', 'खेती', 'बोना', 'crop', 'grow', 'plant', 'sow', 'పంట', 'వేయాలి', 'பயிர்', 'ಬೆಳೆ', 'ಬೆಳೆಯ', 'ফসল', 'চাষ', 'ਫਸਲ', 'ਖੇਤੀ', 'ফসল', 'വിള', 'ଫସଲ', 'कोणती'])) {
      return _cropResponses[_selectedLang] ?? _cropResponses['en']!;
    }
    // Weather
    if (_containsAny(ql, ['मौसम', 'बारिश', 'weather', 'rain', 'temperature', 'humid', 'forecast', 'వాతావరణ', 'వర్షం', 'வானிலை', 'மழை', 'ಹವಾಮಾನ', 'ಮಳೆ', 'আবহাওয়া', 'বৃষ্টি', 'ਮੌਸਮ', 'ਬਾਰਿਸ਼', 'हवामान', 'पाऊस', 'കാലാവസ്ഥ', 'ਹਵਾ'])) {
      return _weatherResponses[_selectedLang] ?? _weatherResponses['en']!;
    }
    // Sell / when to sell
    if (_containsAny(ql, ['बेच', 'sell', 'when', 'कब', 'అమ்', 'అమ్మ', 'விற்', 'ಮಾರ', 'বিক্রি', 'ਵੇਚ', 'विक्री', 'വിൽ', 'ବିକ୍ର'])) {
      return _sellResponses[_selectedLang] ?? _sellResponses['en']!;
    }
    // MSP / government price
    if (_containsAny(ql, ['msp', 'minimum', 'support', 'government', 'सरकार', 'न्यूनतम', 'govt', 'pm kisan', 'kisan', 'ప్రభుత్వ', 'அரசு', 'ಸರ್ಕಾರ', 'সরকার', 'ਸਰਕਾਰ', 'सरकारी', 'सरकारे'])) {
      return _mspResponses[_selectedLang] ?? _mspResponses['en']!;
    }
    // Fertilizer / manure
    if (_containsAny(ql, ['खाद', 'उर्वरक', 'fertilizer', 'manure', 'urea', 'dap', 'ఎరువు', 'உரம்', 'ಗೊಬ್ಬರ', 'সার', 'ਖਾਦ', 'खत', 'വളം', 'ସାର'])) {
      return _fertilizerResponses[_selectedLang] ?? _fertilizerResponses['en']!;
    }
    // Loan / credit / scheme
    if (_containsAny(ql, ['loan', 'credit', 'लोन', 'ऋण', 'kcc', 'scheme', 'yojana', 'रण', 'రుణం', 'கடன்', 'ಸಾಲ', 'ঋণ', 'ਕਰਜ਼', 'borrows', 'finance', 'bank', 'ബാങ്ക്'])) {
      return _loanResponses[_selectedLang] ?? _loanResponses['en']!;
    }
    // Market report (default for market/mandi words)
    if (_containsAny(ql, ['mandi', 'market', 'मंडी', 'बाजार', 'మార్కెట్', 'மார்கெட்', 'ಮಾರುಕಟ್ಟೆ', 'বাজার', 'ਮੰਡੀ', 'बाजार', 'മാർക്കറ്റ്', 'ବଜାର'])) {
      return _marketResponses[_selectedLang] ?? _marketResponses['en']!;
    }

    // Unknown question — show helpful guide
    return _defaultResponses[_selectedLang] ?? _defaultResponses['en']!;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
    );
  }

  static const _langCodes = {
    'hi': 'hi_IN', 'en': 'en_IN', 'te': 'te_IN', 'ta': 'ta_IN',
    'kn': 'kn_IN', 'mr': 'mr_IN', 'gu': 'gu_IN', 'pa': 'pa_IN',
    'bn': 'bn_IN', 'ml': 'ml_IN', 'or': 'or_IN',
  };

  void _startListening() {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice not available. Type your question below.')),
      );
      return;
    }
    setState(() { _isListening = true; _response = ''; _transcribed = ''; });
    final localeId = _langCodes[_selectedLang] ?? 'en_IN';
    _speech.listen(
      onResult: (result) {
        setState(() => _transcribed = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          setState(() { _isListening = false; _isProcessing = true; });
          _speech.stop();
          _fetchRealResponse(result.recognizedWords).then((resp) {
            if (!mounted) return;
            setState(() { _response = resp; _isProcessing = false; });
          });
        }
      },
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
    );
    // Auto-stop after 8 seconds if no final result
    Future.delayed(const Duration(seconds: 8), () {
      if (_isListening && mounted) {
        _speech.stop();
        setState(() => _isListening = false);
        if (_transcribed.isNotEmpty) {
          setState(() => _isProcessing = true);
          _fetchRealResponse(_transcribed).then((resp) {
            if (!mounted) return;
            setState(() { _response = resp; _isProcessing = false; });
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    // Always sync voice language with app language
    final appLang = ref.watch(appLangProvider);
    if (_languages.containsKey(appLang) && appLang != _selectedLang) {
      _selectedLang = appLang;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(s.voiceTitle),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.background, Color(0xFFE8F5E9)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Language selector
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _languages.entries.map((e) {
                      final sel = e.key == _selectedLang;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: sel,
                          onSelected: (_) {
                            setState(() => _selectedLang = e.key);
                            ref.read(appLangProvider.notifier).state = e.key;
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textPrimary, fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mic button with animations
                    GestureDetector(
                      onTap: (!_isListening && !_isProcessing) ? _startListening : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isListening)
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, __) => Container(
                                width: 160 + _pulseCtrl.value * 40,
                                height: 160 + _pulseCtrl.value * 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1 - _pulseCtrl.value * 0.05),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          if (_isListening)
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, __) => Container(
                                width: 130 + _pulseCtrl.value * 20,
                                height: 130 + _pulseCtrl.value * 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15 - _pulseCtrl.value * 0.05),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isListening ? 110 : 90,
                            height: _isListening ? 110 : 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [Colors.red.shade400, Colors.red.shade700]
                                    : [AppColors.primaryLight, AppColors.primary],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: (_isListening ? Colors.red : AppColors.primary).withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isListening ? s.voiceListening : _isProcessing ? s.voiceProcessing : s.voiceTapSpeak,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isListening ? Colors.red : AppColors.textPrimary,
                      ),
                    ).animate(target: _isListening ? 1 : 0).fadeIn(),
                    if (_transcribed.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_transcribed, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2),
                    ],
                    if (_isProcessing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ).animate(onPlay: (c) => c.repeat()).moveY(begin: 0, end: -6, duration: 400.ms, delay: Duration(milliseconds: 150 * i), curve: Curves.easeInOut).then().moveY(begin: -6, end: 0, duration: 400.ms)),
                        ),
                      ),
                    if (_response.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.08), AppColors.primary.withOpacity(0.03)]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.smart_toy, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_response, style: const TextStyle(fontSize: 14, height: 1.5))),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                    ],
                  ],
                ),
              ),
              // Custom text input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: InputDecoration(
                        hintText: s.voiceTypeHint,
                        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: _submitText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _submitText(_textCtrl.text),
                    child: Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
              // Sample queries
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.voiceTrySaying, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_sampleQueries[_selectedLang] ?? []).map((q) => GestureDetector(
                            onTap: () {
                              setState(() { _transcribed = q; _isProcessing = true; _response = ''; });
                              _fetchRealResponse(q).then((resp) {
                                if (!mounted) return;
                                setState(() { _response = resp; _isProcessing = false; });
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                              ),
                              child: Text(q, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                            ),
                          )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
