import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kiotviet_product.dart';

class KiotVietProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<KiotVietProduct>> searchProducts(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // Query by name
      final nameQuery = _firestore
          .collection('kiotviet_products')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .limit(10);

      // Query by code
      final codeQuery = _firestore
          .collection('kiotviet_products')
          .where('code', isGreaterThanOrEqualTo: query)
          .where('code', isLessThan: '${query}z')
          .limit(10);

      final results = await Future.wait([
        nameQuery.get(),
        codeQuery.get(),
      ]);

      final nameResults = results[0].docs;
      final codeResults = results[1].docs;

      final allDocs = <String, KiotVietProduct>{};

      for (var doc in nameResults) {
        allDocs[doc.id] = KiotVietProduct.fromFirestore(doc);
      }

      for (var doc in codeResults) {
        allDocs[doc.id] = KiotVietProduct.fromFirestore(doc);
      }

      return allDocs.values.toList();
    } catch (e) {
      print('Error searching products: $e');
      return []; // Return an empty list in case of an error
    }
  }
}