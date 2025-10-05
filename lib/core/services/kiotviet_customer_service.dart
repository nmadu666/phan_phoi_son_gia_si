import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';

class KiotVietCustomerService {
  final FirebaseFirestore _firestore;

  KiotVietCustomerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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

  Future<Map<String, dynamic>> searchCustomers(
    String query, {
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return {'customers': [], 'lastDoc': null};
    }
    final lowerCaseQuery = _removeDiacritics(trimmedQuery.toLowerCase());

    try {
      Query baseQuery = _firestore
          .collection('kiotviet_customers')
          .where('search_keywords', arrayContains: lowerCaseQuery)
          .limit(limit);

      if (lastDoc != null) {
        baseQuery = baseQuery.startAfterDocument(lastDoc);
      }

      final querySnapshot = await baseQuery.get();
      final customers = querySnapshot.docs
          .map((doc) => KiotVietCustomer.fromFirestore(doc))
          .toList();

      final lastDocument = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;

      return {'customers': customers, 'lastDoc': lastDocument};
    } catch (e) {
      print('An unexpected error occurred while searching customers: $e');
      return {'customers': [], 'lastDoc': null};
    }
  }
}
