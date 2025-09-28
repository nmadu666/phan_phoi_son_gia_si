import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_variant.dart';

class Product {
  final String id;
  final String name;
  final List<ProductVariant> variants;

  Product({required this.id, required this.name, required this.variants});

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var variantsData = data['variants'] as List<dynamic>? ?? [];
    List<ProductVariant> variants = variantsData.map((v) => ProductVariant.fromMap(v)).toList();
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      variants: variants,
    );
  }
}