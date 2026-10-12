import 'dart:convert';
import 'dart:math' as math;
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
  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // Use mock when Supabase not configured OR when AUTH_MOCK flag is set
  bool get _useMock => !AppConfig.isSupabaseConfigured || AppConfig.isAuthMock;

  String _commodityKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '')
      .replaceAll('chillies', 'chilli')
      .replaceAll('chilis', 'chilli')
      .replaceAll('potatoes', 'potato')
      .replaceAll('tomatoes', 'tomato');

  Options get _mlOptions {
    final session = _db.auth.currentSession;
    if (session == null)
      throw StateError('Sign in is required to use this service.');
    return Options(headers: {'Authorization': 'Bearer ${session.accessToken}'});
  }

  Future<List<Map<String, dynamic>>> _storedMarketRows(
    String commodity, {
    String? state,
  }) async {
    var query = _db
        .from('market_prices')
        .select('commodity,state,district,market,modal_price,arrival_date,unit')
        ;
    if (state != null && state != 'All States')
      query = query.eq('state', state);
    var rows = List<Map<String, dynamic>>.from(
      (await query.order('arrival_date', ascending: false).limit(5000))
          .where((row) => _commodityKey('${row['commodity']}') == _commodityKey(commodity))
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
    );
    if (rows.isEmpty && state != null && state != 'All States') {
      final allRows = await _db
          .from('market_prices')
          .select(
            'commodity,state,district,market,modal_price,arrival_date,unit',
          )
          .order('arrival_date', ascending: false)
          .limit(5000);
      rows = List<Map<String, dynamic>>.from(allRows)
          .where((row) => _commodityKey('${row['commodity']}') == _commodityKey(commodity))
          .toList();
    }
    return rows;
  }

  PricePrediction _estimateFromRows(
    String commodity,
    String state,
    int days,
    List<Map<String, dynamic>> rows,
  ) {
    final byDate = <String, List<double>>{};
    for (final row in rows) {
      final date = row['arrival_date']?.toString().substring(0, 10);
      final price = (row['modal_price'] as num?)?.toDouble();
      if (date != null && price != null && price > 0) {
        (byDate[date] ??= []).add(price);
      }
    }
    final dates = byDate.keys.toList()..sort();
    if (dates.isEmpty) throw StateError('No market prices are available.');
    final series = dates
        .map(
          (d) => (
            DateTime.parse(d),
            byDate[d]!.reduce((a, b) => a + b) / byDate[d]!.length,
          ),
        )
        .toList();
    final latest = series.last.$2;
    final xMean =
        series
            .map((p) => p.$1.difference(series.first.$1).inDays.toDouble())
            .reduce((a, b) => a + b) /
        series.length;
    final yMean =
        series.map((p) => p.$2).reduce((a, b) => a + b) / series.length;
    final denominator = series.fold<double>(
      0,
      (sum, p) =>
          sum + math.pow(p.$1.difference(series.first.$1).inDays - xMean, 2),
    );
    final slope = series.length < 2 || denominator == 0
        ? 0.0
        : series.fold<double>(
                0,
                (sum, p) =>
                    sum +
                    (p.$1.difference(series.first.$1).inDays - xMean) *
                        (p.$2 - yMean),
              ) /
              denominator;
    final dailyRate = (slope / latest).clamp(-0.02, 0.02);
    final points = List.generate(days, (i) {
      final price = latest * math.pow(1 + dailyRate, i + 1);
      final band = math.min(0.25, 0.08 + (i + 1) * 0.005);
      return PriceForecastPoint(
        date: DateTime.now().add(Duration(days: i + 1)),
        price: price.toDouble(),
        lowerBound: price * (1 - band),
        upperBound: price * (1 + band),
      );
    });
    return PricePrediction(
      commodity: commodity,
      market: state,
      points: points,
      confidence: series.length > 1 ? 0.45 : 0.20,
      unit: rows.first['unit'] == null
          ? 'INR/quintal'
          : '${rows.first['unit']}',
      generatedAt: DateTime.now(),
      sourceDate: series.last.$1,
      isEstimate: true,
    );
  }

  // ── Market Prices ─────────────────────────────────────────────────────────

  Future<List<MarketPrice>> fetchMarketPrices({
    String? state,
    String? commodity,
    int limit = 20,
  }) async {
    if (_useMock || AppConfig.isAuthMock)
      return MockApiService().fetchMarketPrices(
        state: state,
        commodity: commodity,
        limit: limit,
      );

    try {
      var query = _db.from('market_prices').select();
      if (state != null && state != 'All States')
        query = query.eq('state', state);

      // The table carries one row per (commodity, market) per arrival date.
      // Keep enough history to return the latest row per market and its prior
      // price, which is needed to calculate real price changes and spike alerts.
      final data = await query
          .order('arrival_date', ascending: false)
          .limit(math.max(limit * 10, 1000));
      final seen = <String>{};
      final result = <MarketPrice>[];
      final previousPrices = <String, double>{};
      for (final row in (data as List)) {
        if (commodity != null &&
            commodity != 'All' &&
            _commodityKey('${row['commodity']}') != _commodityKey(commodity)) {
          continue;
        }
        final key = '${row['commodity']}_${row['state']}_${row['market']}';
        final modalPrice = (row['modal_price'] as num).toDouble();
        if (!seen.add(key)) {
          // Rows are newest first, so the second row for a market is its prior
          // available price. Update the latest record already in the result.
          if (!previousPrices.containsKey(key)) {
            previousPrices[key] = modalPrice;
            final index = result.indexWhere(
              (price) =>
                  '${price.commodity}_${price.state}_${price.market}' == key,
            );
            if (index >= 0) {
              final latest = result[index];
              result[index] = MarketPrice(
                id: latest.id,
                commodity: latest.commodity,
                market: latest.market,
                state: latest.state,
                district: latest.district,
                minPrice: latest.minPrice,
                maxPrice: latest.maxPrice,
                modalPrice: latest.modalPrice,
                unit: latest.unit,
                date: latest.date,
                source: latest.source,
                previousModalPrice: modalPrice,
              );
            }
          }
          continue;
        }
        if (result.length >= limit) continue;
        result.add(
          MarketPrice(
            id: row['id'],
            commodity: row['commodity'],
            market: row['market'],
            state: row['state'],
            district: row['district'] ?? '',
            minPrice: (row['min_price'] as num).toDouble(),
            maxPrice: (row['max_price'] as num).toDouble(),
            modalPrice: modalPrice,
            unit: row['unit'] ?? 'quintal',
            date: DateTime.parse(row['arrival_date']),
            source: row['source'] ?? 'agmarknet',
          ),
        );
        if (result.length >= limit) break;
      }
      return result;
    } catch (_) {
      // Surface live-data failures so they aren't mistaken for real prices.
      rethrow;
    }
  }

  Future<List<double>> fetchPriceHistory(
    String commodity, {
    int days = 30,
  }) async {
    if (_useMock)
      return MockApiService().fetchPriceHistory(commodity, days: days);

    try {
      final data = await _db
          .from('market_prices')
          .select('commodity, modal_price, arrival_date')
          .order('arrival_date', ascending: false)
          .limit(5000);
      final byDate = <String, List<double>>{};
      for (final row in (data as List)) {
        if (_commodityKey('${row['commodity']}') != _commodityKey(commodity)) {
          continue;
        }
        (byDate[row['arrival_date'] as String] ??= <double>[]).add(
          (row['modal_price'] as num).toDouble(),
        );
      }
      final dates = byDate.keys.toList()..sort();
      return dates.skip(dates.length > days ? dates.length - days : 0).map((
        date,
      ) {
        final values = byDate[date]!;
        return values.reduce((a, b) => a + b) / values.length;
      }).toList();
    } catch (_) {
      rethrow;
    }
  }

  // ── ML Prediction (calls Railway ML service) ──────────────────────────────

  Future<PricePrediction> fetchPrediction(
    String commodity,
    String state,
    int days,
  ) async {
    if (_useMock) {
      return MockApiService().fetchPrediction(commodity, state, days);
    }
    try {
      if (!AppConfig.isMlConfigured)
        throw StateError('ML service is not configured.');
      final cacheId =
          '${commodity}_${state}_${days}_${DateTime.now().toIso8601String().split('T')[0]}';
      // Call ML service
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/predict',
        data: {'commodity': commodity, 'state': state, 'days': days},
        options: _mlOptions,
      );

      final pts = (resp.data['points'] as List)
          .map(
            (p) => PriceForecastPoint(
              date: DateTime.parse(p['date']),
              price: (p['price'] as num).toDouble(),
              lowerBound: (p['lowerBound'] as num).toDouble(),
              upperBound: (p['upperBound'] as num).toDouble(),
            ),
          )
          .toList();

      if (pts.isEmpty)
        throw const FormatException(
          'Forecast service returned no prediction points.',
        );

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
        'points': pts
            .map(
              (p) => {
                'date': p.date.toIso8601String().split('T')[0],
                'price': p.price,
                'lowerBound': p.lowerBound,
                'upperBound': p.upperBound,
              },
            )
            .toList(),
        'confidence': pred.confidence,
        'unit': pred.unit,
        'generated_at': pred.generatedAt.toIso8601String(),
      });

      return pred;
    } catch (_) {
      if (AppConfig.mlDemoFallback) {
        return MockApiService().fetchPrediction(commodity, state, days);
      }
      return _estimateFromRows(
        commodity,
        state,
        days,
        await _storedMarketRows(commodity, state: state),
      );
    }
  }

  // ── Profit Advice (calls ML service) ─────────────────────────────────────

  Future<ProfitAdvice> fetchProfitAdvice(String commodity) async {
    if (_useMock) {
      return MockApiService().fetchProfitAdvice(commodity);
    }
    try {
      if (!AppConfig.isMlConfigured)
        throw StateError('ML service is not configured.');
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/profit',
        data: {'commodity': commodity},
        options: _mlOptions,
      );
      final d = resp.data;
      return ProfitAdvice(
        decision: ProfitDecision.values.firstWhere(
          (e) => e.name == (d['decision'] ?? 'hold7'),
          orElse: () => ProfitDecision.hold7,
        ),
        currentPrice: (d['currentPrice'] as num).toDouble(),
        projectedPrice: (d['projectedPrice'] as num).toDouble(),
        roi: (d['roi'] as num).toDouble(),
        confidence: (d['confidence'] as num).toInt(),
        reason: d['reason'] ?? '',
        factors: List<String>.from(d['factors'] ?? []),
      );
    } catch (_) {
      if (AppConfig.mlDemoFallback)
        return MockApiService().fetchProfitAdvice(commodity);
      final rows = await _storedMarketRows(commodity);
      final forecast = _estimateFromRows(commodity, 'All States', 14, rows);
      final byDate = <String, List<double>>{};
      for (final row in rows) {
        final day = row['arrival_date']?.toString().substring(0, 10);
        final price = (row['modal_price'] as num?)?.toDouble();
        if (day != null && price != null) (byDate[day] ??= []).add(price);
      }
      final latestDay = (byDate.keys.toList()..sort()).last;
      final current =
          byDate[latestDay]!.reduce((a, b) => a + b) /
          byDate[latestDay]!.length;
      final projected = forecast.points[6].price;
      final roi = (projected - current) / current * 100;
      return ProfitAdvice(
        decision: roi > 3 ? ProfitDecision.hold7 : ProfitDecision.sellNow,
        currentPrice: current,
        projectedPrice: projected,
        roi: roi,
        confidence: (forecast.confidence * 100).round(),
        reason: roi > 3
            ? 'The available price trend points upward.'
            : 'The available price trend is steady; compare current offers before selling.',
        factors: [
          'Calculated from recorded market prices',
          'Estimate based on the available price history',
        ],
        sourceDate: forecast.sourceDate,
        isEstimate: true,
      );
    }
  }

  // ── Demand (calls ML service) ─────────────────────────────────────────────

  Future<DemandResult> fetchDemand(
    String commodity, {
    String state = 'All States',
  }) async {
    if (_useMock) {
      return MockApiService().fetchDemand(commodity);
    }
    try {
      if (!AppConfig.isMlConfigured)
        throw StateError('ML service is not configured.');
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/demand',
        data: {'commodity': commodity, 'state': state},
        options: _mlOptions,
      );
      final d = resp.data;
      return DemandResult(
        commodity: commodity,
        demandLevel: d['demandLevel'],
        demandIndex: (d['demandIndex'] as num).toDouble(),
        trend: d['trend'],
        peakDays: (d['peakExpectedDays'] as num).toInt(),
        weeklyDemand: List<double>.from(
          (d['weeklyDemand'] ?? []).map((v) => (v as num).toDouble()),
        ),
        regions: (d['regions'] as List? ?? [])
            .map(
              (r) => RegionDemand(r['region'], (r['demand'] as num).toDouble()),
            )
            .toList(),
      );
    } catch (_) {
      if (AppConfig.mlDemoFallback)
        return MockApiService().fetchDemand(commodity);
      final rows = await _storedMarketRows(commodity, state: state);
      if (rows.isEmpty) throw StateError('No market activity is available.');
      final byDate = <String, Set<String>>{};
      final regions = <String, Set<String>>{};
      for (final row in rows) {
        final day = row['arrival_date']?.toString().substring(0, 10);
        final market = row['market']?.toString() ?? '';
        if (day == null || market.isEmpty) continue;
        (byDate[day] ??= <String>{}).add(market);
      }
      final latestDay = (byDate.keys.toList()..sort()).last;
      for (final row in rows.where(
        (r) => r['arrival_date'].toString().startsWith(latestDay),
      )) {
        final region =
            row['district']?.toString() ?? row['state']?.toString() ?? '';
        final market = row['market']?.toString() ?? '';
        if (region.isNotEmpty && market.isNotEmpty)
          (regions[region] ??= <String>{}).add(market);
      }
      final maxMarkets = byDate.values
          .map((v) => v.length)
          .fold<int>(1, math.max);
      final index = (byDate[latestDay]!.length / maxMarkets).clamp(0.0, 1.0);
      final rankedRegions = regions.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      return DemandResult(
        commodity: commodity,
        demandLevel: index >= 0.7
            ? 'HIGH'
            : index >= 0.4
            ? 'MEDIUM'
            : 'LOW',
        demandIndex: index,
        trend: 'STABLE',
        peakDays: 7,
        weeklyDemand: List<double>.filled(7, index),
        regions: rankedRegions
            .take(5)
            .map(
              (e) => RegionDemand(
                e.key,
                (e.value.length /
                        (rankedRegions.isEmpty
                            ? 1
                            : rankedRegions.first.value.length))
                    .clamp(0.0, 1.0),
              ),
            )
            .toList(),
        sourceDate: DateTime.parse(latestDay),
        isEstimate: true,
      );
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

      return (data as List)
          .map(
            (row) => CropAlert(
              id: row['id'],
              type: _alertTypeFromString(row['type']),
              commodity: row['commodity'],
              message: row['message'] ?? '',
              isRead: row['is_read'] ?? false,
              isActive: row['is_active'] ?? true,
              createdAt: DateTime.parse(row['created_at']),
              targetPrice: row['target_price'] != null
                  ? (row['target_price'] as num).toDouble()
                  : null,
              triggeredAt: row['triggered_at'] != null
                  ? DateTime.parse(row['triggered_at'])
                  : null,
            ),
          )
          .toList();
    } catch (_) {
      return MockApiService().fetchAlerts();
    }
  }

  Future<CropAlert> createAlert(
    AlertType type,
    String commodity,
    double? targetPrice,
  ) async {
    if (_useMock)
      return MockApiService().createAlert(type, commodity, targetPrice);

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');
      final message = type == AlertType.priceTarget
          ? 'Alert when $commodity reaches ₹${targetPrice?.toStringAsFixed(0)}/qtl'
          : 'Alert for ${type.name} on $commodity';

      final data = await _db
          .from('alerts')
          .insert({
            'farmer_id': uid,
            'type': type.name.toUpperCase(),
            'commodity': commodity,
            'target_price': targetPrice,
            'message': message,
            'is_read': false,
            'is_active': true,
          })
          .select()
          .single();

      return CropAlert(
        id: data['id'],
        type: type,
        commodity: commodity,
        message: message,
        isRead: false,
        isActive: true,
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
      await _db
          .from('alerts')
          .update({'triggered_at': DateTime.now().toIso8601String()})
          .eq('id', id);
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
          lastMessageTime: DateTime.parse(
            row['last_message_time'] ?? DateTime.now().toIso8601String(),
          ),
          unreadCount: isFarmer
              ? (row['farmer_unread'] ?? 0)
              : (row['buyer_unread'] ?? 0),
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
      return (data as List)
          .map(
            (row) => ChatMessage(
              id: row['id'],
              senderId: row['sender_id'] == uid ? 'me' : row['sender_id'],
              text: row['text'],
              timestamp: DateTime.parse(row['created_at']),
              isRead: row['is_read'] ?? false,
              status: _statusFromString(row['status']),
            ),
          )
          .toList();
    } catch (_) {
      return MockApiService().fetchMessages(roomId, myId);
    }
  }

  Future<ChatMessage> sendMessage(
    String roomId,
    String myId,
    String text,
  ) async {
    if (_useMock) return MockApiService().sendMessage(roomId, myId, text);

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');

      final data = await _db
          .from('messages')
          .insert({
            'room_id': roomId,
            'sender_id': uid,
            'text': text,
            'is_read': false,
            'status': 'sent',
          })
          .select()
          .single();

      // Update room preview separately. Metadata failure must not replace an
      // already-persisted message with a mock response.
      try {
        final room = await _db
            .from('chat_rooms')
            .select('farmer_id, farmer_unread, buyer_unread')
            .eq('id', roomId)
            .maybeSingle();
        final recipientUnreadField = room != null && room['farmer_id'] == uid
            ? 'buyer_unread'
            : 'farmer_unread';
        final currentUnread =
            (room?[recipientUnreadField] as num?)?.toInt() ?? 0;
        await _db
            .from('chat_rooms')
            .update({
              'last_message': text,
              'last_message_time': DateTime.now().toIso8601String(),
              if (room != null) recipientUnreadField: currentUnread + 1,
            })
            .eq('id', roomId);
      } catch (_) {
        // The message is already saved; the room preview can refresh later.
      }

      return ChatMessage(
        id: data['id'],
        senderId: 'me',
        text: text,
        timestamp: DateTime.parse(data['created_at']),
        isRead: false,
        status: MessageStatus.sent,
      );
    } catch (_) {
      rethrow;
    }
  }

  /// Subscribe to new messages in a room (Realtime)
  RealtimeChannel subscribeToMessages(
    String roomId,
    void Function(ChatMessage) onMessage,
  ) {
    final uid = _db.auth.currentUser?.id ?? 'me';
    return _db
        .channel('messages:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
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
    if (_useMock) {
      return MockApiService().fetchCropRecommendation(
        soilType: soilType,
        season: season,
        temperature: temperature,
        rainfall: rainfall,
      );
    }
    try {
      if (!AppConfig.isMlConfigured)
        throw StateError('ML service is not configured.');
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/crop-reco',
        data: {
          'soilType': soilType,
          'season': season,
          'temperature': temperature,
          'rainfall': rainfall,
        },
        options: _mlOptions,
      );
      final recommendations = (resp.data['recommendations'] as List)
          .map(
            (r) => CropRecoResult(
              name: r['crop'] ?? r['name'],
              emoji: r['emoji'] ?? '🌱',
              matchScore: (r['matchScore'] as num).toDouble(),
              description: r['reason'] ?? r['description'] ?? '',
              duration: r['duration'] ?? '90-120 days',
              waterReq: r['waterRequirement'] ?? 'Medium',
            ),
          )
          .toList();
      if (recommendations.isEmpty)
        throw const FormatException(
          'Crop recommendation service returned no results.',
        );
      return recommendations;
    } catch (_) {
      if (AppConfig.mlDemoFallback) {
        return MockApiService().fetchCropRecommendation(
          soilType: soilType,
          season: season,
          temperature: temperature,
          rainfall: rainfall,
        );
      }
      // Recommendation rules are local and deterministic; they need no
      // network or historical price data, so they remain usable offline.
      final results = await MockApiService().fetchCropRecommendation(
        soilType: soilType,
        season: season,
        temperature: temperature,
        rainfall: rainfall,
      );
      return results
          .map(
            (r) => CropRecoResult(
              name: r.name,
              emoji: r.emoji,
              matchScore: r.matchScore,
              description: r.description,
              duration: r.duration,
              waterReq: r.waterReq,
              isRuleBased: true,
            ),
          )
          .toList();
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
        options: _mlOptions,
      );
      return VoiceResponse(
        intent: resp.data['intent'],
        answer: resp.data['answer'],
      );
    } catch (_) {
      return MockApiService().processVoiceQuery(query, language);
    }
  }

  // ── Weather (OpenWeather) ─────────────────────────────────────────────────

  Future<WeatherData> fetchWeather(String location) async {
    try {
      if (AppConfig.openWeatherKey.isNotEmpty &&
          !AppConfig.openWeatherKey.contains('YOUR_')) {
        final resp = await _dio.get(
          'https://api.openweathermap.org/data/2.5/weather',
          queryParameters: {
            'q': '$location,IN',
            'appid': AppConfig.openWeatherKey,
            'units': 'metric',
          },
        );
        final d = resp.data;
        return WeatherData(
          temperature: (d['main']['temp'] as num).round(),
          humidity: (d['main']['humidity'] as num).round(),
          description: d['weather'][0]['description'],
          icon: _weatherEmoji(d['weather'][0]['main']),
        );
      }
      return await _fetchOpenMeteoWeather(location);
    } catch (_) {
      try {
        return await _fetchOpenMeteoWeather(location);
      } catch (_) {
        if (!_useMock) rethrow;
        return MockApiService().fetchWeather(location);
      }
    }
  }

  Future<WeatherData> _fetchOpenMeteoWeather(String location) async {
    final name = location.split(',').first.trim();
    final geo = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': '$name, India',
        'count': 1,
        'language': 'en',
        'format': 'json',
      },
    );
    final results = geo.data['results'] as List? ?? [];
    if (results.isEmpty)
      throw StateError('Could not find weather coordinates for $location.');
    final place = results.first;
    final weather = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': place['latitude'],
        'longitude': place['longitude'],
        'current': 'temperature_2m,relative_humidity_2m,weather_code',
        'timezone': 'auto',
      },
    );
    final current = weather.data['current'];
    final code = (current['weather_code'] as num).toInt();
    final condition = _openMeteoCondition(code);
    return WeatherData(
      temperature: (current['temperature_2m'] as num).round(),
      humidity: (current['relative_humidity_2m'] as num).round(),
      description: condition,
      icon: _weatherEmoji(condition),
    );
  }

  String _openMeteoCondition(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Clouds';
    if (code == 45 || code == 48) return 'Mist';
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 95) return 'Thunderstorm';
    return 'Clouds';
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

  Future<int> syncPricesForState(
    String state, {
    String commodity = 'All',
  }) async {
    if (!AppConfig.isMlConfigured)
      throw StateError('Live market service is not configured.');

    try {
      final resp = await _dio.post(
        '${AppConfig.mlServiceUrl}/market/prices',
        data: {'state': state, 'commodity': commodity, 'limit': 500},
        options: _mlOptions,
      );

      final latestArrival = DateTime.tryParse(
        resp.data['latestArrivalDate']?.toString() ?? '',
      );
      if (latestArrival == null ||
          DateTime.now().difference(latestArrival) > const Duration(days: 3)) {
        throw StateError('Market source has no recent observation.');
      }
      return (resp.data['records'] as num?)?.toInt() ?? 0;
    } catch (_) {
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AlertType _alertTypeFromString(String s) {
    switch (s.toUpperCase()) {
      case 'PRICE_SPIKE':
        return AlertType.priceSpike;
      case 'PRICE_TARGET':
        return AlertType.priceTarget;
      case 'DEMAND_HIGH':
        return AlertType.demandHigh;
      case 'NEW_BUYER':
        return AlertType.newBuyer;
      case 'WEATHER':
        return AlertType.weather;
      default:
        return AlertType.priceTarget;
    }
  }

  MessageStatus _statusFromString(String? s) {
    switch (s) {
      case 'read':
        return MessageStatus.read;
      case 'delivered':
        return MessageStatus.delivered;
      case 'sending':
        return MessageStatus.sending;
      default:
        return MessageStatus.sent;
    }
  }

  String _weatherEmoji(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '⛅';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'haze':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}
