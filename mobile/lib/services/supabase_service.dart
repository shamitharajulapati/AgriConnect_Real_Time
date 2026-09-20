import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_config.dart';
import '../features/market/models/market_price.dart';
import '../features/prediction/models/price_prediction.dart';
import '../features/alerts/models/crop_alert.dart';
import '../features/chat/models/chat_models.dart';
import 'mock_api_service.dart';

/// Single entry point — uses Supabase when keys are configured, Mock otherwise
class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  SupabaseClient get _db => Supabase.instance.client;
  // Render's free tier sleeps after ~15 min idle and can take 30-60s to wake
  // on the next request — timeouts need enough headroom to survive that, or
  // every first call after a quiet spell would fail and silently fall to mock.
  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // Use mock when Supabase not configured OR when AUTH_MOCK flag is set
  bool get _useMock => !AppConfig.isSupabaseConfigured || AppConfig.isAuthMock;

  // ── Market Prices ─────────────────────────────────────────────────────────

  Future<List<MarketPrice>> fetchMarketPrices({
    String? state,
    String? commodity,
    int limit = 20,
  }) async {
    if (_useMock || AppConfig.isAuthMock) return MockApiService().fetchMarketPrices(state: state, commodity: commodity, limit: limit);

    try {
      var query = _db.from('market_prices').select();
      if (state != null && state != 'All States') query = query.eq('state', state);
      if (commodity != null && commodity != 'All') query = query.eq('commodity', commodity);

      // Fetch extra so dedup below still leaves `limit` distinct listings —
      // the table carries one row per (commodity, market) per arrival date,
      // and without this a market with several recent dates on file would
      // show as several near-identical duplicate cards.
      final data = await query.order('arrival_date', ascending: false).limit(limit * 3);
      final seen = <String>{};
      final result = <MarketPrice>[];
      for (final row in (data as List)) {
        final key = '${row['commodity']}_${row['market']}';
        if (!seen.add(key)) continue; // keep only the first (= latest date) row per market
        result.add(MarketPrice(
          id: row['id'],
          commodity: row['commodity'],
          market: row['market'],
          state: row['state'],
          district: row['district'] ?? '',
          minPrice: (row['min_price'] as num).toDouble(),
          maxPrice: (row['max_price'] as num).toDouble(),
          modalPrice: (row['modal_price'] as num).toDouble(),
          unit: row['unit'] ?? 'quintal',
          date: DateTime.parse(row['arrival_date']),
          source: row['source'] ?? 'agmarknet',
        ));
        if (result.length >= limit) break;
      }
      return result;
    } catch (e) {
      // Fallback to mock on error
      return MockApiService().fetchMarketPrices(state: state, commodity: commodity, limit: limit);
    }
  }

  Future<List<double>> fetchPriceHistory(String commodity, {int days = 30}) async {
    if (_useMock) return MockApiService().fetchPriceHistory(commodity, days: days);

    try {
      final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0];
      final data = await _db
          .from('market_prices')
          .select('modal_price, arrival_date')
          .eq('commodity', commodity)
          .gte('arrival_date', cutoff)
          .order('arrival_date');

      return (data as List).map((r) => (r['modal_price'] as num).toDouble()).toList();
    } catch (_) {
      return MockApiService().fetchPriceHistory(commodity, days: days);
    }
  }

  // ── ML Prediction (calls Railway ML service) ──────────────────────────────

  Future<PricePrediction> fetchPrediction(String commodity, String state, int days) async {
    if (_useMock || !AppConfig.isMlConfigured || AppConfig.isAuthMock) {
      return MockApiService().fetchPrediction(commodity, state, days);
    }

    try {
      // Check cache in Supabase first
      final cacheId = '${commodity}_${state}_${DateTime.now().toIso8601String().split('T')[0]}';
      final cached = await _db.from('price_predictions').select().eq('id', cacheId).maybeSingle();

      if (cached != null) {
        final pts = (cached['points'] as List).map((p) => PriceForecastPoint(
          date: DateTime.parse(p['date']),
          price: (p['price'] as num).toDouble(),
          lowerBound: (p['lowerBound'] as num).toDouble(),
          upperBound: (p['upperBound'] as num).toDouble(),
        )).toList();
        return PricePrediction(
          commodity: commodity, market: state,
          points: pts,
          confidence: (cached['confidence'] as num).toDouble(),
          unit: cached['unit'] ?? 'INR/quintal',
          generatedAt: DateTime.parse(cached['generated_at']),
        );
      }

      // Call ML service
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/predict',
        data: {'commodity': commodity, 'state': state, 'days': days},
        options: Options(headers: {'X-Secret': AppConfig.mlServiceSecret}),
      );

      final pts = (resp.data['points'] as List).map((p) => PriceForecastPoint(
        date: DateTime.parse(p['date']),
        price: (p['price'] as num).toDouble(),
        lowerBound: (p['lowerBound'] as num).toDouble(),
        upperBound: (p['upperBound'] as num).toDouble(),
      )).toList();

      final pred = PricePrediction(
        commodity: commodity,
        market: state,
        points: pts,
        confidence: (resp.data['confidence'] as num).toDouble(),
        unit: resp.data['unit'] ?? 'INR/quintal',
        generatedAt: DateTime.now(),
      );

      // Cache in Supabase
      await _db.from('price_predictions').upsert({
        'id': cacheId,
        'commodity': commodity,
        'state': state,
        'points': pts.map((p) => {'date': p.date.toIso8601String().split('T')[0], 'price': p.price, 'lowerBound': p.lowerBound, 'upperBound': p.upperBound}).toList(),
        'confidence': pred.confidence,
        'unit': pred.unit,
        'generated_at': pred.generatedAt.toIso8601String(),
      });

      return pred;
    } catch (_) {
      return MockApiService().fetchPrediction(commodity, state, days);
    }
  }

  // ── Profit Advice (calls ML service) ─────────────────────────────────────

  Future<ProfitAdvice> fetchProfitAdvice(String commodity) async {
    if (_useMock || !AppConfig.isMlConfigured || AppConfig.isAuthMock) {
      return MockApiService().fetchProfitAdvice(commodity);
    }

    try {
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/profit',
        data: {'commodity': commodity},
        options: Options(headers: {'X-Secret': AppConfig.mlServiceSecret}),
      );
      final d = resp.data;
      return ProfitAdvice(
        decision: ProfitDecision.values.firstWhere((e) => e.name == (d['decision'] ?? 'hold7'), orElse: () => ProfitDecision.hold7),
        currentPrice: (d['currentPrice'] as num).toDouble(),
        projectedPrice: (d['projectedPrice'] as num).toDouble(),
        roi: (d['roi'] as num).toDouble(),
        confidence: (d['confidence'] as num).toInt(),
        reason: d['reason'] ?? '',
        factors: List<String>.from(d['factors'] ?? []),
      );
    } catch (_) {
      return MockApiService().fetchProfitAdvice(commodity);
    }
  }

  // ── Demand (calls ML service) ─────────────────────────────────────────────

  Future<DemandResult> fetchDemand(String commodity) async {
    if (_useMock || !AppConfig.isMlConfigured || AppConfig.isAuthMock) {
      return MockApiService().fetchDemand(commodity);
    }

    try {
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/demand',
        data: {'commodity': commodity},
        options: Options(headers: {'X-Secret': AppConfig.mlServiceSecret}),
      );
      final d = resp.data;
      return DemandResult(
        commodity: commodity,
        demandLevel: d['demandLevel'],
        demandIndex: (d['demandIndex'] as num).toDouble(),
        trend: d['trend'],
        peakDays: (d['peakExpectedDays'] as num).toInt(),
        weeklyDemand: List<double>.from((d['weeklyDemand'] ?? []).map((v) => (v as num).toDouble())),
        regions: (d['regions'] as List? ?? []).map((r) => RegionDemand(r['region'], (r['demand'] as num).toDouble())).toList(),
      );
    } catch (_) {
      return MockApiService().fetchDemand(commodity);
    }
  }

  // ── Alerts (Supabase) ─────────────────────────────────────────────────────

  Future<List<CropAlert>> fetchAlerts() async {
    if (_useMock) return MockApiService().fetchAlerts();

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return [];
      final data = await _db
          .from('alerts')
          .select()
          .eq('farmer_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      return (data as List).map((row) => CropAlert(
        id: row['id'],
        type: _alertTypeFromString(row['type']),
        commodity: row['commodity'],
        message: row['message'] ?? '',
        isRead: row['is_read'] ?? false,
        isActive: row['is_active'] ?? true,
        createdAt: DateTime.parse(row['created_at']),
        targetPrice: row['target_price'] != null ? (row['target_price'] as num).toDouble() : null,
        triggeredAt: row['triggered_at'] != null ? DateTime.parse(row['triggered_at']) : null,
      )).toList();
    } catch (_) {
      return MockApiService().fetchAlerts();
    }
  }

  Future<CropAlert> createAlert(AlertType type, String commodity, double? targetPrice) async {
    if (_useMock) return MockApiService().createAlert(type, commodity, targetPrice);

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');
      final message = type == AlertType.priceTarget
          ? 'Alert when $commodity reaches ₹${targetPrice?.toStringAsFixed(0)}/qtl'
          : 'Alert for ${type.name} on $commodity';

      final data = await _db.from('alerts').insert({
        'farmer_id': uid,
        'type': type.name.toUpperCase(),
        'commodity': commodity,
        'target_price': targetPrice,
        'message': message,
        'is_read': false,
        'is_active': true,
      }).select().single();

      return CropAlert(
        id: data['id'], type: type, commodity: commodity,
        message: message, isRead: false, isActive: true,
        createdAt: DateTime.parse(data['created_at']),
        targetPrice: targetPrice,
      );
    } catch (_) {
      return MockApiService().createAlert(type, commodity, targetPrice);
    }
  }

  Future<void> deleteAlert(String id) async {
    if (_useMock) return;
    try {
      await _db.from('alerts').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> markAlertRead(String id) async {
    if (_useMock) return;
    try {
      await _db.from('alerts').update({'is_read': true}).eq('id', id);
    } catch (_) {}
  }

  Future<void> markAlertTriggered(String id) async {
    if (_useMock) return;
    try {
      await _db.from('alerts').update({'triggered_at': DateTime.now().toIso8601String()}).eq('id', id);
    } catch (_) {}
  }

  Future<void> markAllAlertsRead() async {
    if (_useMock) return;
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('alerts').update({'is_read': true}).eq('farmer_id', uid);
    } catch (_) {}
  }

  // ── Chat Rooms (Supabase) ─────────────────────────────────────────────────

  Future<List<ChatRoom>> fetchChatRooms() async {
    if (_useMock) return MockApiService().fetchChatRooms();

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return [];
      final data = await _db
          .from('chat_rooms')
          .select()
          .or('farmer_id.eq.$uid,buyer_id.eq.$uid')
          .order('last_message_time', ascending: false);

      return (data as List).map((row) {
        final isFarmer = row['farmer_id'] == uid;
        return ChatRoom(
          roomId: row['id'],
          otherUserId: isFarmer ? row['buyer_id'] : row['farmer_id'],
          otherUserName: row['other_user_name'] ?? 'Buyer',
          otherUserRole: 'Buyer',
          lastMessage: row['last_message'] ?? '',
          lastMessageTime: DateTime.parse(row['last_message_time'] ?? DateTime.now().toIso8601String()),
          unreadCount: isFarmer ? (row['farmer_unread'] ?? 0) : (row['buyer_unread'] ?? 0),
          cropTopic: row['crop_topic'],
        );
      }).toList();
    } catch (_) {
      return MockApiService().fetchChatRooms();
    }
  }

  // ── Messages (Supabase Realtime) ──────────────────────────────────────────

  Future<List<ChatMessage>> fetchMessages(String roomId, String myId) async {
    if (_useMock) return MockApiService().fetchMessages(roomId, myId);

    try {
      final data = await _db
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at');

      final uid = _db.auth.currentUser?.id ?? myId;
      return (data as List).map((row) => ChatMessage(
        id: row['id'],
        senderId: row['sender_id'] == uid ? 'me' : row['sender_id'],
        text: row['text'],
        timestamp: DateTime.parse(row['created_at']),
        isRead: row['is_read'] ?? false,
        status: _statusFromString(row['status']),
      )).toList();
    } catch (_) {
      return MockApiService().fetchMessages(roomId, myId);
    }
  }

  Future<ChatMessage> sendMessage(String roomId, String myId, String text) async {
    if (_useMock) return MockApiService().sendMessage(roomId, myId, text);

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');

      final data = await _db.from('messages').insert({
        'room_id': roomId,
        'sender_id': uid,
        'text': text,
        'is_read': false,
        'status': 'sent',
      }).select().single();

      // Update chat room's last message
      await _db.from('chat_rooms').update({
        'last_message': text,
        'last_message_time': DateTime.now().toIso8601String(),
        'buyer_unread': _db.rpc('increment', params: {'x': 1}),
      }).eq('id', roomId);

      return ChatMessage(
        id: data['id'], senderId: 'me', text: text,
        timestamp: DateTime.parse(data['created_at']),
        isRead: false, status: MessageStatus.sent,
      );
    } catch (_) {
      return MockApiService().sendMessage(roomId, myId, text);
    }
  }

  /// Subscribe to new messages in a room (Realtime)
  RealtimeChannel subscribeToMessages(String roomId, void Function(ChatMessage) onMessage) {
    final uid = _db.auth.currentUser?.id ?? 'me';
    return _db
        .channel('messages:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (payload) {
            final row = payload.newRecord;
            final msg = ChatMessage(
              id: row['id'],
              senderId: row['sender_id'] == uid ? 'me' : row['sender_id'],
              text: row['text'],
              timestamp: DateTime.parse(row['created_at']),
              isRead: row['is_read'] ?? false,
              status: _statusFromString(row['status']),
            );
            onMessage(msg);
          },
        )
        .subscribe();
  }

  // ── Crop Recommendation (ML service) ─────────────────────────────────────

  Future<List<CropRecoResult>> fetchCropRecommendation({
    required String soilType,
    required String season,
    required double temperature,
    required double rainfall,
  }) async {
    if (_useMock || !AppConfig.isMlConfigured || AppConfig.isAuthMock) {
      return MockApiService().fetchCropRecommendation(soilType: soilType, season: season, temperature: temperature, rainfall: rainfall);
    }

    try {
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/crop-reco',
        data: {'soilType': soilType, 'season': season, 'temperature': temperature, 'rainfall': rainfall},
        options: Options(headers: {'X-Secret': AppConfig.mlServiceSecret}),
      );
      return (resp.data['recommendations'] as List).map((r) => CropRecoResult(
        name: r['crop'] ?? r['name'],
        emoji: r['emoji'] ?? '🌱',
        matchScore: (r['matchScore'] as num).toDouble(),
        description: r['reason'] ?? r['description'] ?? '',
        duration: r['duration'] ?? '90-120 days',
        waterReq: r['waterRequirement'] ?? 'Medium',
      )).toList();
    } catch (_) {
      return MockApiService().fetchCropRecommendation(soilType: soilType, season: season, temperature: temperature, rainfall: rainfall);
    }
  }

  // ── Voice Query (ML service) ──────────────────────────────────────────────

  Future<VoiceResponse> processVoiceQuery(String query, String language) async {
    if (_useMock || !AppConfig.isMlConfigured) {
      return MockApiService().processVoiceQuery(query, language);
    }

    try {
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/voice',
        data: {'query': query, 'language': language},
        options: Options(headers: {'X-Secret': AppConfig.mlServiceSecret}),
      );
      return VoiceResponse(intent: resp.data['intent'], answer: resp.data['answer']);
    } catch (_) {
      return MockApiService().processVoiceQuery(query, language);
    }
  }

  // ── Weather (OpenWeather) ─────────────────────────────────────────────────

  Future<WeatherData> fetchWeather(String location) async {
    if (AppConfig.openWeatherKey.isEmpty || AppConfig.openWeatherKey.contains('YOUR_')) {
      return MockApiService().fetchWeather(location);
    }

    try {
      final resp = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {'q': '$location,IN', 'appid': AppConfig.openWeatherKey, 'units': 'metric'},
      );
      final d = resp.data;
      final icon = _weatherEmoji(d['weather'][0]['main']);
      return WeatherData(
        temperature: (d['main']['temp'] as num).round(),
        humidity: (d['main']['humidity'] as num).round(),
        description: d['weather'][0]['description'],
        icon: icon,
      );
    } catch (_) {
      return MockApiService().fetchWeather(location);
    }
  }

  // ── Farmer Profile ────────────────────────────────────────────────────────

  Future<void> saveProfile(Map<String, dynamic> data) async {
    if (_useMock) return;
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;
      await _db.from('farmers').upsert({
        'id': uid,
        'name': data['name'],
        'email': _db.auth.currentUser?.email,
        'state': data['state'],
        'district': data['district'],
        'crops': data['crops'],
        'language': data['language'],
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    if (_useMock) return null;
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return null;
      return await _db.from('farmers').select().eq('id', uid).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // ── Agmarknet Sync ────────────────────────────────────────────────────────

  Future<int> syncPricesForState(String state) async {
    if (AppConfig.agmarknetKey.isEmpty || AppConfig.agmarknetKey.contains('YOUR_')) return 0;

    try {
      const baseUrl = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070';
      final resp = await _dio.get(baseUrl, queryParameters: {
        'api-key': AppConfig.agmarknetKey,
        'format': 'json',
        'limit': 500,
        'filters[state]': state,
      });

      final records = resp.data['records'] as List? ?? [];
      if (records.isEmpty) return 0;

      // Batch upsert to Supabase
      const batchSize = 100;
      for (var i = 0; i < records.length; i += batchSize) {
        final batch = records.skip(i).take(batchSize).map((r) {
          final isoDate = _parseAgmarknetDate(r['arrival_date']?.toString());
          return {
            'id': '${r['state']}_${r['market']}_${r['commodity']}_$isoDate'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'),
            'commodity': r['commodity'],
            'market': r['market'],
            'state': r['state'],
            'district': r['district'] ?? '',
            'min_price': double.tryParse(r['min_price']?.toString() ?? '0') ?? 0,
            'max_price': double.tryParse(r['max_price']?.toString() ?? '0') ?? 0,
            'modal_price': double.tryParse(r['modal_price']?.toString() ?? '0') ?? 0,
            'unit': 'quintal',
            'arrival_date': isoDate,
            'source': 'agmarknet',
          };
        }).toList();
        await _db.from('market_prices').upsert(batch);
      }
      return records.length;
    } catch (_) {
      return 0;
    }
  }

  /// The Agmarknet API returns arrival_date as DD/MM/YYYY — Supabase's
  /// arrival_date column expects ISO YYYY-MM-DD.
  String _parseAgmarknetDate(String? raw) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (raw == null || raw.isEmpty) return today;
    final parts = raw.split('/');
    if (parts.length != 3) return today;
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$year-$month-$day';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AlertType _alertTypeFromString(String s) {
    switch (s.toUpperCase()) {
      case 'PRICE_SPIKE': return AlertType.priceSpike;
      case 'PRICE_TARGET': return AlertType.priceTarget;
      case 'DEMAND_HIGH': return AlertType.demandHigh;
      case 'NEW_BUYER': return AlertType.newBuyer;
      case 'WEATHER': return AlertType.weather;
      default: return AlertType.priceTarget;
    }
  }

  MessageStatus _statusFromString(String? s) {
    switch (s) {
      case 'read': return MessageStatus.read;
      case 'delivered': return MessageStatus.delivered;
      case 'sending': return MessageStatus.sending;
      default: return MessageStatus.sent;
    }
  }

  String _weatherEmoji(String main) {
    switch (main.toLowerCase()) {
      case 'clear': return '☀️';
      case 'clouds': return '⛅';
      case 'rain': return '🌧️';
      case 'drizzle': return '🌦️';
      case 'thunderstorm': return '⛈️';
      case 'snow': return '❄️';
      case 'mist': case 'haze': case 'fog': return '🌫️';
      default: return '🌤️';
    }
  }
}
