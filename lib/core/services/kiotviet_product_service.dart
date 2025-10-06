import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kiotviet_product.dart';

class KiotVietProductService {
  final FirebaseFirestore _firestore;
  final int _limit = 15;

  KiotVietProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Removes diacritics from a string for searching.
  String _removeDiacritics(String str) {
    const withDia =
        'àáãạảăắằẳẵặâấầẩẫậèéẹẻẽêềếểễệđìíịỉĩòóọỏõôồốổỗộơờớởỡợùúụủũưừứửữựỳýỵỷỹ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeediiiiiooooooooooooooooouuuuuuuuuuuyyyyy';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Fetches recently modified products.
  Future<Map<String, dynamic>> getRecentProducts({
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _firestore
        .collection('kiotviet_products')
        .orderBy('modifiedDate', descending: true)
        .limit(_limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final querySnapshot = await query.get();
    final products = querySnapshot.docs
        .map((doc) => KiotVietProduct.fromFirestore(doc))
        .toList();

    return {
      'products': products,
      'lastDoc': querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
    };
  }

  /// Searches for products using prefix search on the `search_prefixes` field.
  Future<Map<String, dynamic>> searchProducts(
    String query, {
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) {
        // If query is empty, return recent products instead.
        return getRecentProducts(lastDoc: lastDoc);
      }

      // Normalize the query for prefix search
      final lowerCaseQuery = _removeDiacritics(trimmedQuery.toLowerCase());

      Query baseQuery = _firestore.collection('kiotviet_products');

      // Use `array-contains` on the new `search_prefixes` field.
      // This enables efficient prefix matching.
      baseQuery = baseQuery.where(
        'search_prefixes',
        arrayContains: lowerCaseQuery,
      );

      // We cannot order by 'modifiedDate' when using an array-contains filter.
      // Firestore limitations require the orderBy field to be the same as the
      // inequality/array-contains field. We accept the default ordering.
      // If relevance-based sorting is needed, a dedicated search service
      // like Algolia or Typesense would be the next step.

      baseQuery = baseQuery.limit(_limit);

      if (lastDoc != null) {
        baseQuery = baseQuery.startAfterDocument(lastDoc);
      }

      final querySnapshot = await baseQuery.get();
      final products = querySnapshot.docs
          .map((doc) => KiotVietProduct.fromFirestore(doc))
          .toList();

      final lastDocument = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;

      return {'products': products, 'lastDoc': lastDocument};
    } catch (e) {
      print('An unexpected error occurred while searching products: $e');
      return {'products': [], 'lastDoc': null};
    }
  }
}
