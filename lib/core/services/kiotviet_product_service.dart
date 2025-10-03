import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kiotviet_product.dart';

class KiotVietProductService {
  final FirebaseFirestore _firestore;

  KiotVietProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getRecentProducts({
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) async {
    try {
      Query query = _firestore
          .collection('kiotviet_products')
          .orderBy('createdDate', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final querySnapshot = await query.get();
      final products = querySnapshot.docs
          .map((doc) => KiotVietProduct.fromFirestore(doc))
          .toList();

      final lastDocument = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;

      return {'products': products, 'lastDoc': lastDocument};
    } catch (e) {
      print('An unexpected error occurred while fetching recent products: $e');
      return {'products': [], 'lastDoc': null};
    }
  }

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

  Future<Map<String, dynamic>> searchProducts(
    String query, {
    DocumentSnapshot? lastDoc,
    String? sortBy, // 'name_asc', 'name_desc', 'price_asc', 'price_desc'
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return {'products': [], 'lastDoc': null};
    }
    final lowerCaseQuery = _removeDiacritics(trimmedQuery.toLowerCase());

    print('--- DEBUG: Searching products with query: "$lowerCaseQuery" ---');

    try {
      Query baseQuery = _firestore
          .collection('kiotviet_products')
          .where('search_keywords', arrayContains: lowerCaseQuery);

      // Sắp xếp kết quả
      if (sortBy != null) {
        switch (sortBy) {
          case 'name_asc':
            baseQuery = baseQuery.orderBy('name');
            break;
          case 'name_desc':
            baseQuery = baseQuery.orderBy('name', descending: true);
            break;
          // Thêm các trường hợp sắp xếp khác nếu cần, ví dụ theo giá
        }
      }

      baseQuery = baseQuery.limit(15);

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
    } on FirebaseException catch (e) {
      print(
        'A Firebase error occurred while searching products: ${e.code} - ${e.message}',
      );
      return {'products': [], 'lastDoc': null};
    } catch (e) {
      print('An unexpected error occurred while searching products: $e');
      return {'products': [], 'lastDoc': null};
    }
  }
}
