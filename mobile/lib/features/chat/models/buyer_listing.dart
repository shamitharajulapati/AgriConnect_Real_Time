class BuyerListing {
  final String id;
  final String buyerId;
  final String buyerName;
  final String commodity;
  final double? quantityNeeded;
  final double? priceOffered;
  final String? state;
  final String? district;
  final String? description;
  final DateTime createdAt;

  const BuyerListing({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.commodity,
    this.quantityNeeded,
    this.priceOffered,
    this.state,
    this.district,
    this.description,
    required this.createdAt,
  });

  // Mock buyers for demo when no real buyers exist
  static List<BuyerListing> get mockListings => [
    BuyerListing(id: 'b1', buyerId: 'buyer_001', buyerName: 'Rajesh Gupta Traders', commodity: 'Tomato', quantityNeeded: 50, priceOffered: 1600, state: 'Delhi', district: 'Azadpur', description: 'Need Grade A tomatoes. Regular buyer. Quick payment.', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    BuyerListing(id: 'b2', buyerId: 'buyer_002', buyerName: 'Priya Fresh Exports', commodity: 'Onion', quantityNeeded: 100, priceOffered: 1000, state: 'Maharashtra', district: 'Nashik', description: 'Export quality onions needed. Premium price for good quality.', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
    BuyerListing(id: 'b3', buyerId: 'buyer_003', buyerName: 'FreshMart Retail Ltd', commodity: 'Wheat', quantityNeeded: 200, priceOffered: 2300, state: 'Punjab', district: 'Ludhiana', description: 'Wholesale wheat purchase. MSP or above. Immediate payment.', createdAt: DateTime.now().subtract(const Duration(hours: 8))),
    BuyerListing(id: 'b4', buyerId: 'buyer_004', buyerName: 'Karnataka Agro Buyer', commodity: 'Maize', quantityNeeded: 75, priceOffered: 1800, state: 'Karnataka', district: 'Davangere', description: 'Poultry feed requirement. Regular monthly purchase needed.', createdAt: DateTime.now().subtract(const Duration(days: 1))),
    BuyerListing(id: 'b5', buyerId: 'buyer_005', buyerName: 'Spice World Exports', commodity: 'Chillies', quantityNeeded: 30, priceOffered: 11000, state: 'Andhra Pradesh', district: 'Guntur', description: 'Premium dry chillies for export. Need certification documents.', createdAt: DateTime.now().subtract(const Duration(days: 1))),
    BuyerListing(id: 'b6', buyerId: 'buyer_006', buyerName: 'Potato Palace Traders', commodity: 'Potato', quantityNeeded: 150, priceOffered: 820, state: 'Uttar Pradesh', district: 'Agra', description: 'Regular potato purchase for chips manufacturing unit.', createdAt: DateTime.now().subtract(const Duration(days: 2))),
    BuyerListing(id: 'b7', buyerId: 'buyer_007', buyerName: 'Cotton King Mills', commodity: 'Cotton', quantityNeeded: 80, priceOffered: 6800, state: 'Maharashtra', district: 'Yavatmal', description: 'Long staple cotton required for textile mill. Quality premium paid.', createdAt: DateTime.now().subtract(const Duration(days: 2))),
    BuyerListing(id: 'b8', buyerId: 'buyer_008', buyerName: 'Rice Bowl Traders', commodity: 'Rice', quantityNeeded: 120, priceOffered: 3100, state: 'Punjab', district: 'Amritsar', description: 'Basmati and non-basmati rice purchase. Direct mill pricing.', createdAt: DateTime.now().subtract(const Duration(days: 3))),
  ];
}
