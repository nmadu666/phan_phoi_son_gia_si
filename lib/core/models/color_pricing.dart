import 'package:cloud_firestore/cloud_firestore.dart';

class ColorPricing {
  final String id;
  final String name;
  final double pricePerMl;

  ColorPricing({required this.id, required this.name, required this.pricePerMl});

  factory ColorPricing.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ColorPricing(
      id: doc.id,
      name: data['name'] ?? '',
      pricePerMl: (data['pricePerMl'] ?? 0).toDouble(),
    );
  }
}