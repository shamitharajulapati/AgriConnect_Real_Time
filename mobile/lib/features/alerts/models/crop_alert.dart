enum AlertType { priceTarget, priceSpike, demandHigh, newBuyer, weather }

class CropAlert {
  final String id;
  final AlertType type;
  final String commodity;
  final String message;
  final bool isRead;
  final bool isActive;
  final DateTime createdAt;
  final double? targetPrice;
  final DateTime? triggeredAt;

  const CropAlert({
    required this.id,
    required this.type,
    required this.commodity,
    required this.message,
    required this.isRead,
    required this.isActive,
    required this.createdAt,
    this.targetPrice,
    this.triggeredAt,
  });

  static List<CropAlert> get mockAlerts => [
        CropAlert(id: 'a1', type: AlertType.priceSpike, commodity: 'Tomato', message: 'Tomato prices spiked 18% in Azadpur market! Current: ₹1,500/qtl', isRead: false, isActive: true, createdAt: DateTime.now().subtract(const Duration(hours: 1)), triggeredAt: DateTime.now().subtract(const Duration(hours: 1))),
        CropAlert(id: 'a2', type: AlertType.priceTarget, commodity: 'Onion', message: 'Onion reached your target price of ₹900/qtl at Lasalgaon', isRead: false, isActive: true, createdAt: DateTime.now().subtract(const Duration(hours: 3)), targetPrice: 900, triggeredAt: DateTime.now().subtract(const Duration(hours: 3))),
        CropAlert(id: 'a3', type: AlertType.demandHigh, commodity: 'Wheat', message: 'High demand detected for Wheat in Punjab. Consider selling now.', isRead: true, isActive: true, createdAt: DateTime.now().subtract(const Duration(days: 1))),
        CropAlert(id: 'a4', type: AlertType.newBuyer, commodity: 'Cotton', message: 'New buyer FreshMart Ltd interested in Cotton from Maharashtra', isRead: true, isActive: true, createdAt: DateTime.now().subtract(const Duration(days: 2))),
        CropAlert(id: 'a5', type: AlertType.weather, commodity: 'All Crops', message: 'Heavy rainfall forecast next 3 days in your region. Secure your harvest.', isRead: true, isActive: true, createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ];
}
