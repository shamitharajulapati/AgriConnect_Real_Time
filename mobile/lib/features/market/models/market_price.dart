class MarketPrice {
  final String id;
  final String commodity;
  final String market;
  final String state;
  final String district;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String unit;
  final DateTime date;
  final String source;
  final double? previousModalPrice;

  const MarketPrice({
    required this.id,
    required this.commodity,
    required this.market,
    required this.state,
    this.district = '',
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    required this.unit,
    required this.date,
    required this.source,
    this.previousModalPrice,
  });

  double? get deltaPercent {
    if (previousModalPrice == null || previousModalPrice == 0) return null;
    return (modalPrice - previousModalPrice!) / previousModalPrice! * 100;
  }

  bool get isUp => (deltaPercent ?? 0) > 0;
}

class MockMarketData {
  static List<MarketPrice> get prices => [
        MarketPrice(id: '1', commodity: 'Tomato', market: 'Azadpur', state: 'Delhi', district: 'North Delhi', minPrice: 1200, maxPrice: 1800, modalPrice: 1500, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 1350),
        MarketPrice(id: '2', commodity: 'Onion', market: 'Lasalgaon', state: 'Maharashtra', district: 'Nashik', minPrice: 800, maxPrice: 1200, modalPrice: 950, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 1100),
        MarketPrice(id: '3', commodity: 'Potato', market: 'Agra', state: 'Uttar Pradesh', district: 'Agra', minPrice: 600, maxPrice: 900, modalPrice: 750, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 720),
        MarketPrice(id: '4', commodity: 'Wheat', market: 'Chandigarh', state: 'Punjab', district: 'Sahibzada Ajit Singh Nagar', minPrice: 2100, maxPrice: 2400, modalPrice: 2250, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 2200),
        MarketPrice(id: '5', commodity: 'Rice', market: 'Amritsar', state: 'Punjab', district: 'Amritsar', minPrice: 2800, maxPrice: 3200, modalPrice: 3000, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 2900),
        MarketPrice(id: '6', commodity: 'Cotton', market: 'Yavatmal', state: 'Maharashtra', district: 'Yavatmal', minPrice: 6000, maxPrice: 7000, modalPrice: 6500, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 6200),
        MarketPrice(id: '7', commodity: 'Chillies', market: 'Guntur', state: 'Andhra Pradesh', district: 'Guntur', minPrice: 8000, maxPrice: 12000, modalPrice: 10000, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 9500),
        MarketPrice(id: '8', commodity: 'Soybean', market: 'Indore', state: 'Madhya Pradesh', district: 'Indore', minPrice: 4200, maxPrice: 4800, modalPrice: 4500, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 4600),
        MarketPrice(id: '9', commodity: 'Maize', market: 'Davangere', state: 'Karnataka', district: 'Davanagere', minPrice: 1500, maxPrice: 1900, modalPrice: 1700, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 1650),
        MarketPrice(id: '10', commodity: 'Sugarcane', market: 'Kolhapur', state: 'Maharashtra', district: 'Kolhapur', minPrice: 280, maxPrice: 320, modalPrice: 300, unit: 'quintal', date: DateTime.now(), source: 'agmarknet', previousModalPrice: 310),
      ];

  static List<String> get commodities => ['All', 'Tomato', 'Onion', 'Potato', 'Wheat', 'Rice', 'Cotton', 'Chillies', 'Soybean', 'Maize', 'Sugarcane'];
  static List<String> get states => ['All States', 'Delhi', 'Maharashtra', 'Uttar Pradesh', 'Punjab', 'Karnataka', 'Andhra Pradesh', 'Madhya Pradesh'];
}
