import 'dart:math';
import '../features/market/models/market_price.dart';
import '../features/prediction/models/price_prediction.dart';
import '../features/alerts/models/crop_alert.dart';
import '../features/chat/models/chat_models.dart';

/// Simulates network latency
Future<T> _delay<T>(T value, {int ms = 150}) async {
  await Future.delayed(Duration(milliseconds: ms + Random().nextInt(150)));
  return value;
}

class MockApiService {
  static final MockApiService _instance = MockApiService._();
  factory MockApiService() => _instance;
  MockApiService._();

  // ── Market Prices ────────────────────────────────────────────────────────────

  Future<List<MarketPrice>> fetchMarketPrices({
    String? state,
    String? commodity,
    int limit = 20,
  }) async {
    final all = _allPrices();
    final filtered = all.where((p) {
      final matchState = state == null || state == 'All States' || p.state == state;
      final matchCommodity = commodity == null || commodity == 'All' || p.commodity == commodity;
      return matchState && matchCommodity;
    }).take(limit).toList();
    return _delay(filtered);
  }

  Future<List<double>> fetchPriceHistory(String commodity, {int days = 30}) async {
    final base = _basePrices[commodity] ?? 1000.0;
    final rng = Random(commodity.hashCode);
    final history = List.generate(days, (i) {
      return base * (0.85 + rng.nextDouble() * 0.3) + (i * base * 0.003);
    });
    return _delay(history);
  }

  // ── Predictions ──────────────────────────────────────────────────────────────

  Future<PricePrediction> fetchPrediction(String commodity, String state, int days) async {
    final base = _basePrices[commodity] ?? 1000.0;
    return _delay(PricePrediction.mock(commodity, base));
  }

  // ── Profit Advice ────────────────────────────────────────────────────────────

  Future<ProfitAdvice> fetchProfitAdvice(String commodity) async {
    final advice = _profitAdviceMap[commodity] ??
        ProfitAdvice(
          decision: ProfitDecision.hold7,
          currentPrice: 1000,
          projectedPrice: 1080,
          roi: 8.0,
          confidence: 72,
          reason: 'Market conditions suggest holding for better returns.',
          factors: ['Stable demand', 'No major supply disruptions'],
        );
    return _delay(advice);
  }

  // ── Demand ───────────────────────────────────────────────────────────────────

  Future<DemandResult> fetchDemand(String commodity) async {
    final rng = Random(commodity.hashCode);
    final idx = 0.35 + rng.nextDouble() * 0.55;
    final weekly = List.generate(7, (_) => 35.0 + rng.nextDouble() * 60);
    final regions = [
      RegionDemand('Maharashtra', 0.3 + rng.nextDouble() * 0.65),
      RegionDemand('Karnataka', 0.3 + rng.nextDouble() * 0.65),
      RegionDemand('Delhi NCR', 0.3 + rng.nextDouble() * 0.65),
      RegionDemand('Tamil Nadu', 0.3 + rng.nextDouble() * 0.65),
      RegionDemand('Gujarat', 0.3 + rng.nextDouble() * 0.65),
    ];
    return _delay(DemandResult(
      commodity: commodity,
      demandLevel: idx > 0.7 ? 'HIGH' : idx > 0.45 ? 'MEDIUM' : 'LOW',
      demandIndex: idx,
      trend: rng.nextBool() ? 'RISING' : 'FALLING',
      peakDays: rng.nextInt(18) + 3,
      weeklyDemand: weekly,
      regions: regions,
    ));
  }

  // ── Alerts ───────────────────────────────────────────────────────────────────

  Future<List<CropAlert>> fetchAlerts() async {
    return _delay(List.from(CropAlert.mockAlerts));
  }

  Future<CropAlert> createAlert(AlertType type, String commodity, double? targetPrice) async {
    final alert = CropAlert(
      id: 'a_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      commodity: commodity,
      message: type == AlertType.priceTarget
          ? 'Alert: $commodity reaches ₹${targetPrice?.toStringAsFixed(0)}/qtl'
          : 'Alert: Price spike detected for $commodity',
      isRead: false,
      isActive: true,
      createdAt: DateTime.now(),
      targetPrice: targetPrice,
    );
    return _delay(alert, ms: 400);
  }

  Future<void> markAlertTriggered(String id) async {}

  // ── Chat ─────────────────────────────────────────────────────────────────────

  Future<List<ChatRoom>> fetchChatRooms() async {
    return _delay(ChatRoom.mockRooms);
  }

  Future<List<ChatMessage>> fetchMessages(String roomId, String myId) async {
    return _delay(List.from(ChatRoom.mockMessages(myId)));
  }

  Future<ChatMessage> sendMessage(String roomId, String myId, String text) async {
    final msg = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
      status: MessageStatus.sent,
    );
    return _delay(msg, ms: 200);
  }

  // ── Crop Recommendation ───────────────────────────────────────────────────────

  Future<List<CropRecoResult>> fetchCropRecommendation({
    required String soilType,
    required String season,
    required double temperature,
    required double rainfall,
  }) async {
    final all = _cropDb.map((c) {
      double score = 0;
      if (c.soils.contains(soilType)) score += 0.35;
      if (temperature >= c.tempMin && temperature <= c.tempMax) score += 0.25;
      if (rainfall >= c.rainMin && rainfall <= c.rainMax) score += 0.25;
      if (c.seasons.contains(season)) score += 0.15;
      return CropRecoResult(
        name: c.name, emoji: c.emoji,
        matchScore: score,
        description: c.description,
        duration: c.duration,
        waterReq: c.waterReq,
      );
    }).toList()
      ..sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return _delay(all.take(5).toList(), ms: 1800);
  }

  // ── Voice Query ───────────────────────────────────────────────────────────────

  Future<VoiceResponse> processVoiceQuery(String query, String language) async {
    final q = query.toLowerCase();
    String intent, answer;
    if (q.contains('भाव') || q.contains('price') || q.contains('ధర') ||
        q.contains('விலை') || q.contains('ಬೆಲೆ') || q.contains('rate')) {
      intent = 'GET_PRICE';
      answer = _priceAnswer(q, language);
    } else if (q.contains('फसल') || q.contains('crop') || q.contains('పంట') || q.contains('பயிர்')) {
      intent = 'CROP_RECOMMENDATION';
      answer = _cropAnswer(language);
    } else {
      intent = 'MARKET_OVERVIEW';
      answer = _marketAnswer(language);
    }
    return _delay(VoiceResponse(intent: intent, answer: answer), ms: 1200);
  }

  // ── Weather ───────────────────────────────────────────────────────────────────

  Future<WeatherData> fetchWeather(String location) async {
    return _delay(WeatherData(
      temperature: 26 + Random(location.hashCode).nextInt(8),
      humidity: 60 + Random(location.hashCode + 1).nextInt(20),
      description: ['Partly Cloudy', 'Sunny', 'Overcast', 'Light Rain'][Random(location.hashCode).nextInt(4)],
      icon: ['⛅', '☀️', '🌥️', '🌧️'][Random(location.hashCode).nextInt(4)],
    ));
  }

  // ── Private Helpers ──────────────────────────────────────────────────────────

  static const _basePrices = {
    'Tomato': 1500.0, 'Onion': 950.0, 'Potato': 750.0,
    'Wheat': 2250.0, 'Rice': 3000.0, 'Cotton': 6500.0,
    'Chillies': 10000.0, 'Soybean': 4500.0, 'Maize': 1700.0, 'Sugarcane': 300.0,
  };

  static final _profitAdviceMap = {
    'Tomato': ProfitAdvice(decision: ProfitDecision.hold7, currentPrice: 1500, projectedPrice: 1720, roi: 14.7, confidence: 78, reason: 'Prices trending up due to reduced supply. Hold 7 days for maximum returns.', factors: ['Price rising +14.7%', 'High buyer demand (83%)', 'Low market competition', 'Harvest season ending soon']),
    'Onion': ProfitAdvice(decision: ProfitDecision.sellNow, currentPrice: 950, projectedPrice: 820, roi: -13.7, confidence: 82, reason: 'New arrivals from Maharashtra expected. Sell immediately to avoid price drop.', factors: ['New arrivals incoming', 'Price forecast -13.7%', 'High current supply', 'Storage cost exceeds holding benefit']),
    'Wheat': ProfitAdvice(decision: ProfitDecision.hold14, currentPrice: 2250, projectedPrice: 2580, roi: 14.7, confidence: 71, reason: 'Government procurement season approaching. Prices expected to rise over 14 days.', factors: ['Govt procurement season', 'Export demand rising', 'Low inventory levels', 'MSP price support strong']),
    'Cotton': ProfitAdvice(decision: ProfitDecision.hold14, currentPrice: 6500, projectedPrice: 7200, roi: 10.8, confidence: 68, reason: 'Textile export orders increasing. Cotton prices expected to rise steadily.', factors: ['Export demand high', 'Limited supply', 'Textile season starting', 'International prices rising']),
    'Rice': ProfitAdvice(decision: ProfitDecision.sellNow, currentPrice: 3000, projectedPrice: 2850, roi: -5.0, confidence: 75, reason: 'New kharif harvest arriving. Sell current stock before market gets flooded.', factors: ['New harvest incoming', 'Storage cost high', 'Competitive pricing', 'Export restrictions in place']),
  };

  List<MarketPrice> _allPrices() {
    // Use today's date as seed so prices vary each day but are stable within a session
    final seed = DateTime.now().day * 31 + DateTime.now().month;
    final rng = Random(seed);
    double vary(double base) => (base * (0.92 + rng.nextDouble() * 0.16)).roundToDouble();

    final data = [
      ('Tomato', 'Azadpur', 'Delhi', 1200.0, 1800.0),
      ('Onion', 'Lasalgaon', 'Maharashtra', 800.0, 1100.0),
      ('Potato', 'Agra', 'Uttar Pradesh', 600.0, 900.0),
      ('Wheat', 'Chandigarh', 'Punjab', 2100.0, 2400.0),
      ('Rice', 'Amritsar', 'Punjab', 2800.0, 3200.0),
      ('Cotton', 'Yavatmal', 'Maharashtra', 6000.0, 7000.0),
      ('Chillies', 'Guntur', 'Andhra Pradesh', 8000.0, 12000.0),
      ('Soybean', 'Indore', 'Madhya Pradesh', 4200.0, 4800.0),
      ('Maize', 'Davangere', 'Karnataka', 1500.0, 1900.0),
      ('Sugarcane', 'Kolhapur', 'Maharashtra', 280.0, 320.0),
      ('Tomato', 'Kolar', 'Karnataka', 1100.0, 1700.0),
      ('Onion', 'Nashik', 'Maharashtra', 700.0, 1000.0),
      ('Potato', 'Shimla', 'Himachal Pradesh', 700.0, 1000.0),
      ('Wheat', 'Ludhiana', 'Punjab', 2050.0, 2350.0),
      ('Rice', 'Patna', 'Bihar', 2600.0, 3100.0),
      ('Groundnut', 'Junagadh', 'Gujarat', 5500.0, 6500.0),
      ('Chillies', 'Warangal', 'Telangana', 7500.0, 11000.0),
      ('Maize', 'Nizamabad', 'Telangana', 1400.0, 1800.0),
    ];
    return data.asMap().entries.map((e) {
      final min = vary(e.value.$4);
      final max = vary(e.value.$5);
      final modal = ((min + max) / 2).roundToDouble();
      final prevModal = (modal * (0.88 + rng.nextDouble() * 0.24)).roundToDouble();
      return MarketPrice(
        id: 'p${e.key}', commodity: e.value.$1, market: e.value.$2,
        state: e.value.$3, minPrice: min, maxPrice: max,
        modalPrice: modal, unit: 'quintal', date: DateTime.now(),
        source: 'agmarknet', previousModalPrice: prevModal,
      );
    }).toList();
  }

  String _priceAnswer(String q, String lang) {
    final answers = {
      'hi': 'टमाटर का मोडल भाव आज ₹1,500/क्विंटल है। आज़ादपुर मंडी में। कल से 11% ऊपर। 📈',
      'en': "Today's modal price for Tomato is ₹1,500/quintal at Azadpur market. Up 11% from yesterday. 📈",
      'te': 'ఈరోజు టమాట ధర ₹1,500/క్వింటాల్. నిన్నటి కంటే 11% పెరిగింది. 📈',
      'ta': 'இன்று தக்காளி விலை ₹1,500/குவிண்டால். நேற்றை விட 11% அதிகம். 📈',
      'kn': 'ಇಂದು ಟೊಮೆಟೊ ಬೆಲೆ ₹1,500/ಕ್ವಿಂಟಾಲ್. ನಿನ್ನೆಗಿಂತ 11% ಹೆಚ್ಚು. 📈',
    };
    return answers[lang] ?? answers['en']!;
  }

  String _cropAnswer(String lang) {
    final answers = {
      'hi': 'आपकी जमीन और मौसम के अनुसार: टमाटर, प्याज, और गेहूं सबसे अच्छे रहेंगे। 🌾',
      'en': 'Based on your location and season: Tomato, Onion, and Wheat are best suited. 🌾',
      'te': 'మీ నేల మరియు వాతావరణానికి: టమాట, ఉల్లిపాయ, గోధుమ సూచించబడింది. 🌾',
      'ta': 'உங்கள் நிலம் மற்றும் பருவத்திற்கு: தக்காளி, வெங்காயம், கோதுமை பரிந்துரைக்கப்படுகிறது. 🌾',
      'kn': 'ನಿಮ್ಮ ಮಣ್ಣು ಮತ್ತು ಋತುವಿಗೆ: ಟೊಮೆಟೊ, ಈರುಳ್ಳಿ, ಗೋಧಿ ಶಿಫಾರಸು ಮಾಡಲಾಗಿದೆ. 🌾',
    };
    return answers[lang] ?? answers['en']!;
  }

  String _marketAnswer(String lang) {
    final answers = {
      'hi': 'आज की मंडी रिपोर्ट:\n🍅 टमाटर: ₹1,500 (+11%)\n🧅 प्याज: ₹950 (-13%)\n🥔 आलू: ₹750 (+4%)',
      'en': "Today's market report:\n🍅 Tomato: ₹1,500 (+11%)\n🧅 Onion: ₹950 (-13%)\n🥔 Potato: ₹750 (+4%)",
      'te': 'నేటి మార్కెట్ నివేదిక:\n🍅 టమాట: ₹1,500 (+11%)\n🧅 ఉల్లి: ₹950 (-13%)\n🥔 బంగాళదుంప: ₹750 (+4%)',
      'ta': 'இன்றைய சந்தை அறிக்கை:\n🍅 தக்காளி: ₹1,500 (+11%)\n🧅 வெங்காயம்: ₹950 (-13%)',
      'kn': 'ಇಂದಿನ ಮಾರುಕಟ್ಟೆ ವರದಿ:\n🍅 ಟೊಮೆಟೊ: ₹1,500 (+11%)\n🧅 ಈರುಳ್ಳಿ: ₹950 (-13%)',
    };
    return answers[lang] ?? answers['en']!;
  }

  static final _cropDb = [
    _CropDef('Tomato', '🍅', ['Loamy', 'Sandy', 'Silt'], ['Kharif', 'Rabi'], 18, 35, 600, 1200, 'High returns, regular irrigation needed', '90-120 days', 'Medium'),
    _CropDef('Wheat', '🌾', ['Loamy', 'Clay', 'Silt'], ['Rabi'], 10, 25, 450, 750, 'Staple crop, assured MSP support', '120-150 days', 'Low'),
    _CropDef('Rice', '🌾', ['Clay', 'Silt'], ['Kharif'], 22, 37, 1000, 2000, 'High water requirement, clay soil ideal', '90-150 days', 'Very High'),
    _CropDef('Cotton', '🌿', ['Black Cotton', 'Loamy'], ['Kharif'], 21, 37, 500, 850, 'Cash crop, good export demand', '150-180 days', 'Medium'),
    _CropDef('Soybean', '🫘', ['Loamy', 'Black Cotton'], ['Kharif'], 20, 32, 600, 1000, 'Nitrogen fixer, rising food demand', '90-120 days', 'Low'),
    _CropDef('Maize', '🌽', ['Sandy', 'Loamy', 'Silt'], ['Kharif', 'Rabi', 'Zaid'], 18, 33, 500, 900, 'Multi-use crop: food, feed, ethanol', '80-110 days', 'Low'),
    _CropDef('Onion', '🧅', ['Sandy', 'Loamy'], ['Rabi'], 13, 28, 400, 700, 'High market demand and export potential', '90-120 days', 'Medium'),
    _CropDef('Chillies', '🌶️', ['Loamy', 'Sandy', 'Silt'], ['Kharif', 'Rabi'], 20, 35, 600, 1200, 'High value spice, strong domestic demand', '90-150 days', 'Medium'),
  ];
}

class _CropDef {
  final String name, emoji, description, duration, waterReq;
  final List<String> soils, seasons;
  final double tempMin, tempMax, rainMin, rainMax;
  const _CropDef(this.name, this.emoji, this.soils, this.seasons, this.tempMin, this.tempMax, this.rainMin, this.rainMax, this.description, this.duration, this.waterReq);
}

// ── Result models ─────────────────────────────────────────────────────────────

enum ProfitDecision { sellNow, hold7, hold14 }

class ProfitAdvice {
  final ProfitDecision decision;
  final double currentPrice, projectedPrice, roi;
  final int confidence;
  final String reason;
  final List<String> factors;
  const ProfitAdvice({required this.decision, required this.currentPrice, required this.projectedPrice, required this.roi, required this.confidence, required this.reason, required this.factors});
}

class DemandResult {
  final String commodity, demandLevel, trend;
  final double demandIndex;
  final int peakDays;
  final List<double> weeklyDemand;
  final List<RegionDemand> regions;
  const DemandResult({required this.commodity, required this.demandLevel, required this.demandIndex, required this.trend, required this.peakDays, required this.weeklyDemand, required this.regions});
}

class RegionDemand {
  final String region;
  final double demand;
  const RegionDemand(this.region, this.demand);
}

class CropRecoResult {
  final String name, emoji, description, duration, waterReq;
  final double matchScore;
  const CropRecoResult({required this.name, required this.emoji, required this.matchScore, required this.description, required this.duration, required this.waterReq});
}

class VoiceResponse {
  final String intent, answer;
  const VoiceResponse({required this.intent, required this.answer});
}

class WeatherData {
  final int temperature, humidity;
  final String description, icon;
  const WeatherData({required this.temperature, required this.humidity, required this.description, required this.icon});
}
