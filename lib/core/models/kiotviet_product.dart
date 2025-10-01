import 'package:cloud_firestore/cloud_firestore.dart';

class KiotVietProduct {
  final String id;
  final String code;
  final String name;
  final String unit;
  final double basePrice;

  KiotVietProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.basePrice,
  });

  factory KiotVietProduct.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KiotVietProduct(
      id: doc.id,
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      unit: data['unit'] ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
