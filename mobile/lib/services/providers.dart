import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_config.dart';
import '../core/l10n/app_strings.dart';
import 'supabase_service.dart';
import 'mock_api_service.dart';
import '../features/market/models/market_price.dart';
import '../features/prediction/models/price_prediction.dart';
import '../features/alerts/models/crop_alert.dart';
import '../features/chat/models/chat_models.dart';

// ── Language / Localisation ───────────────────────────────────────────────────
final appLangProvider = StateProvider<String>((ref) => 'en');
final appStringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(ref.watch(appLangProvider)),
);

// Single API provider — auto-selects Supabase or Mock
final apiProvider = Provider((ref) => ApiService());

// ── Market ────────────────────────────────────────────────────────────────────

final marketFilterProvider = StateProvider((ref) => MarketFilter());

class MarketFilter {
  final String state;
  final String commodity;
  MarketFilter({this.state = 'All States', this.commodity = 'All'});
  MarketFilter copyWith({String? state, String? commodity}) => MarketFilter(
    state: state ?? this.state,
    commodity: commodity ?? this.commodity,
  );
}

final marketPricesProvider = FutureProvider.autoDispose<List<MarketPrice>>((
  ref,
) {
  final filter = ref.watch(marketFilterProvider);
  return ref
      .read(apiProvider)
      .fetchMarketPrices(
        state: filter.state,
        commodity: filter.commodity,
        limit: 30,
      );
});

// States already synced with the live Agmarknet feed this session — avoids re-syncing on every rebuild.
final syncedStatesProvider = StateProvider<Set<String>>((ref) => {});
// Timestamp of the last successful source fetch, kept per selected market filter.
final marketSyncTimesProvider = StateProvider<Map<String, DateTime>>((ref) => {});

// The signed-in farmer's home district, used to prioritize their local market.
final userDistrictProvider = StateProvider<String>((ref) => '');

class PriceHistory {
  final List<double> values;
  final bool isDemo;
  const PriceHistory(this.values, {this.isDemo = false});
}

final priceHistoryProvider = FutureProvider.autoDispose
    .family<PriceHistory, String>((ref, commodity) async {
      final liveValues = await ref
          .read(apiProvider)
          .fetchPriceHistory(commodity);
      return PriceHistory(liveValues);
    });

// All current market prices, unfiltered — used by the Analytics dashboard.
final analyticsMarketPricesProvider =
    FutureProvider.autoDispose<List<MarketPrice>>((ref) {
      return ref.read(apiProvider).fetchMarketPrices(limit: 200);
    });

// ── Prediction ────────────────────────────────────────────────────────────────

final selectedCommodityProvider = StateProvider((ref) => 'Tomato');
final selectedHorizonProvider = StateProvider((ref) => 7);

final predictionProvider = FutureProvider.autoDispose<PricePrediction>((ref) {
  final commodity = ref.watch(selectedCommodityProvider);
  final days = ref.watch(selectedHorizonProvider);
  final location = ref.watch(userLocationProvider);
  return ref.read(apiProvider).fetchPrediction(commodity, location, days);
});

// ── Profit ────────────────────────────────────────────────────────────────────

final profitCommodityProvider = StateProvider((ref) => 'Tomato');

final profitAdviceProvider = FutureProvider.autoDispose<ProfitAdvice>((ref) {
  final commodity = ref.watch(profitCommodityProvider);
  return ref.read(apiProvider).fetchProfitAdvice(commodity);
});

// ── Demand ────────────────────────────────────────────────────────────────────

final demandCropProvider = StateProvider((ref) => 'Tomato');

final demandProvider = FutureProvider.autoDispose<DemandResult>((ref) {
  final crop = ref.watch(demandCropProvider);
  final location = ref.watch(userLocationProvider);
  return ref.read(apiProvider).fetchDemand(crop, state: location);
});

// ── Alerts ────────────────────────────────────────────────────────────────────

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, AsyncValue<List<CropAlert>>>((ref) {
      return AlertsNotifier(ref.read(apiProvider));
    });

class AlertsNotifier extends StateNotifier<AsyncValue<List<CropAlert>>> {
  AlertsNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }
  final ApiService _api;

  static const _spikeThresholdPct = 10.0;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final alerts = await _api.fetchAlerts();
      state = AsyncValue.data(alerts);
      unawaited(_evaluateAgainstLivePrices(alerts));
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  /// Checks every active, not-yet-triggered alert against current market
  /// prices, and fires (persists + updates local state) any that now match.
  Future<void> _evaluateAgainstLivePrices(List<CropAlert> alerts) async {
    final pending = alerts.where(
      (a) =>
          a.isActive &&
          a.triggeredAt == null &&
          (a.type == AlertType.priceTarget || a.type == AlertType.priceSpike),
    );
    if (pending.isEmpty) return;

    List<MarketPrice> prices;
    try {
      prices = await _api.fetchMarketPrices(limit: 100);
    } catch (_) {
      return;
    }

    for (final alert in pending) {
      final matches = prices.where((p) => p.commodity == alert.commodity);
      if (matches.isEmpty) continue;

      final fires = alert.type == AlertType.priceTarget
          ? matches.any(
              (p) =>
                  alert.targetPrice != null &&
                  p.modalPrice >= alert.targetPrice!,
            )
          : matches.any(
              (p) => (p.deltaPercent ?? 0).abs() >= _spikeThresholdPct,
            );

      if (!fires || !mounted) continue;

      await _api.markAlertTriggered(alert.id);
      state = state.whenData(
        (list) => list
            .map(
              (a) => a.id == alert.id
                  ? CropAlert(
                      id: a.id,
                      type: a.type,
                      commodity: a.commodity,
                      message: a.message,
                      isRead: a.isRead,
                      isActive: a.isActive,
                      createdAt: a.createdAt,
                      targetPrice: a.targetPrice,
                      triggeredAt: DateTime.now(),
                    )
                  : a,
            )
            .toList(),
      );
    }
  }

  Future<void> addAlert(
    AlertType type,
    String commodity,
    double? targetPrice,
  ) async {
    final alert = await _api.createAlert(type, commodity, targetPrice);
    state = state.whenData((list) => [alert, ...list]);
  }

  void markRead(String id) {
    _api.markAlertRead(id);
    state = state.whenData(
      (list) => list
          .map(
            (a) => a.id == id
                ? CropAlert(
                    id: a.id,
                    type: a.type,
                    commodity: a.commodity,
                    message: a.message,
                    isRead: true,
                    isActive: a.isActive,
                    createdAt: a.createdAt,
                    targetPrice: a.targetPrice,
                    triggeredAt: a.triggeredAt,
                  )
                : a,
          )
          .toList(),
    );
  }

  void markAllRead() {
    _api.markAllAlertsRead();
    state = state.whenData(
      (list) => list
          .map(
            (a) => CropAlert(
              id: a.id,
              type: a.type,
              commodity: a.commodity,
              message: a.message,
              isRead: true,
              isActive: a.isActive,
              createdAt: a.createdAt,
              targetPrice: a.targetPrice,
              triggeredAt: a.triggeredAt,
            ),
          )
          .toList(),
    );
  }

  void delete(String id) {
    _api.deleteAlert(id);
    state = state.whenData((list) => list.where((a) => a.id != id).toList());
  }

  Future<void> refresh() => _load();
}

// ── Chat ──────────────────────────────────────────────────────────────────────

final chatRoomsProvider = FutureProvider.autoDispose<List<ChatRoom>>((ref) {
  return ref.read(apiProvider).fetchChatRooms();
});

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, List<ChatMessage>, String>((ref, roomId) {
      return ChatNotifier(ref.read(apiProvider), roomId);
    });

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier(this._api, this._roomId) : super([]) {
    _load();
  }
  final ApiService _api;
  final String _roomId;
  static const _myId = 'me';

  Future<void> _load() async {
    final msgs = await _api.fetchMessages(_roomId, _myId);
    if (mounted) state = msgs;

    // Subscribe to realtime if Supabase is configured
    _api.subscribeToMessages(_roomId, (msg) {
      if (msg.senderId != _myId && mounted) {
        state = [...state, msg];
      }
    });
  }

  Future<bool> send(String text) async {
    // Optimistic update
    final optimistic = ChatMessage(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
      status: MessageStatus.sending,
    );
    state = [...state, optimistic];

    late final ChatMessage sent;
    try {
      sent = await _api.sendMessage(_roomId, _myId, text);
    } catch (_) {
      if (mounted) {
        state = state.where((message) => message.id != optimistic.id).toList();
      }
      return false;
    }

    // Replace optimistic with real
    state = state.map((m) => m.id == optimistic.id ? sent : m).toList();

    // Mock auto-reply when no Supabase
    if (!AppConfig.isSupabaseConfigured || AppConfig.isAuthMock) {
      Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1000)), () {
        if (!mounted) return;
        final replies = [
          'That sounds good! What quantity do you have available?',
          'We can arrange pick up from your farm.',
          'Can you send photos of the produce?',
          'What is the best price you can offer?',
          'We are interested. Let\'s finalize the deal.',
        ];
        state = [
          ...state,
          ChatMessage(
            id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
            senderId: 'buyer_1',
            text: replies[DateTime.now().second % replies.length],
            timestamp: DateTime.now(),
            isRead: false,
            status: MessageStatus.delivered,
          ),
        ];
      });
    }
    return true;
  }
}

// ── Crop Reco ─────────────────────────────────────────────────────────────────

class CropRecoParams {
  final String soilType, season;
  final double temperature, rainfall;
  const CropRecoParams({
    required this.soilType,
    required this.season,
    required this.temperature,
    required this.rainfall,
  });
}

final cropRecoParamsProvider = StateProvider<CropRecoParams?>((ref) => null);

final cropRecoProvider = FutureProvider.autoDispose<List<CropRecoResult>>((
  ref,
) async {
  final params = ref.watch(cropRecoParamsProvider);
  if (params == null) return [];
  return ref
      .read(apiProvider)
      .fetchCropRecommendation(
        soilType: params.soilType,
        season: params.season,
        temperature: params.temperature,
        rainfall: params.rainfall,
      );
});

// ── Weather ───────────────────────────────────────────────────────────────────

final userLocationProvider = StateProvider<String>((ref) => 'Karnataka');

final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) {
  final location = ref.watch(userLocationProvider);
  return ref.read(apiProvider).fetchWeather(location);
});

// ── App Status ────────────────────────────────────────────────────────────────

final backendStatusProvider = Provider<BackendStatus>((ref) {
  return BackendStatus(
    isSupabaseConnected: AppConfig.isSupabaseConfigured,
    isMlConnected: AppConfig.isMlConfigured,
  );
});

class BackendStatus {
  final bool isSupabaseConnected;
  final bool isMlConnected;
  const BackendStatus({
    required this.isSupabaseConnected,
    required this.isMlConnected,
  });
  bool get isFullyConnected => isSupabaseConnected && isMlConnected;
  String get modeLabel => isSupabaseConnected ? '🟢 Live' : '🟡 Demo Mode';
}
