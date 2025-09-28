class ProductVariant {
  final String kiotVietId;
  final double volumeLiters;
  final double basePrice;
  final String baseType;

  ProductVariant({
    required this.kiotVietId,
    required this.volumeLiters,
    required this.basePrice,
    required this.baseType,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      kiotVietId: map['kiotVietId'] ?? '',
      volumeLiters: (map['volumeLiters'] ?? 0).toDouble(),
      basePrice: (map['basePrice'] ?? 0).toDouble(),
      baseType: map['baseType'] ?? '',
    );
  }
}