import 'dart:math';

class PriceForecastPoint {
  final DateTime date;
  final double price;
  final double lowerBound;
  final double upperBound;

  const PriceForecastPoint({
    required this.date,
    required this.price,
    required this.lowerBound,
    required this.upperBound,
  });
}

class PricePrediction {
  final String commodity;
  final String market;
  final List<PriceForecastPoint> points;
  final double confidence;
  final String unit;
  final DateTime generatedAt;
  final bool isDemo;
  final DateTime? sourceDate;
  final bool isEstimate;

  const PricePrediction({
    required this.commodity,
    required this.market,
    required this.points,
    required this.confidence,
    required this.unit,
    required this.generatedAt,
    this.isDemo = false,
    this.sourceDate,
    this.isEstimate = false,
  });

  static PricePrediction mock(String commodity, double basePrice) {
    final rng = Random(commodity.hashCode);
    final pts = List.generate(14, (i) {
      final trend = basePrice * (1 + (i * 0.005));
      final noise = (rng.nextDouble() - 0.5) * basePrice * 0.08;
      final price = trend + noise;
      return PriceForecastPoint(
        date: DateTime.now().add(Duration(days: i + 1)),
        price: price,
        lowerBound: price * 0.88,
        upperBound: price * 1.12,
      );
    });
    return PricePrediction(
      commodity: commodity,
      market: 'Multiple Markets',
      points: pts,
      confidence: 0.82 + rng.nextDouble() * 0.15,
      unit: 'INR/quintal',
      generatedAt: DateTime.now(),
      isDemo: true,
    );
  }
}
