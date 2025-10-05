import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/app_user.dart';
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
    AppUser? currentUser,
    int? branchId,
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) async {
    try {
      Query baseQuery = _firestore
          .collection('kiotviet_customers');

      // Lọc theo chi nhánh nếu branchId được cung cấp
      if (branchId != null) {
        baseQuery = baseQuery.where('branchId', isEqualTo: branchId);
      }

      // Lọc theo mã nhân viên nếu người dùng không phải là admin và có mã
      if (currentUser != null &&
          currentUser.role != 'admin' &&
          currentUser.code != null &&
          currentUser.code!.isNotEmpty) {
        baseQuery = baseQuery.where('code', isGreaterThanOrEqualTo: currentUser.code)
                               .where('code', isLessThan: '${currentUser.code}\uf8ff');
      }

      final trimmedQuery = query.trim();
      if (trimmedQuery.isNotEmpty) {
        final lowerCaseQuery = _removeDiacritics(trimmedQuery.toLowerCase());
        // Chỉ áp dụng bộ lọc từ khóa tìm kiếm nếu có truy vấn
        baseQuery = baseQuery.where('search_keywords', arrayContains: lowerCaseQuery);
      }

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
