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

  /// Tạo một khách hàng mới trên KiotViet và lưu vào Firestore.
  ///
  /// [name]: Tên khách hàng (bắt buộc).
  /// [contactNumber]: Số điện thoại.
  /// [address]: Địa chỉ.
  /// [branchId]: ID chi nhánh.
  /// Trả về đối tượng [KiotVietCustomer] đã được tạo thành công.
  Future<KiotVietCustomer> createCustomer({
    required String name,
    String? contactNumber,
    String? address,
    required int branchId,
  }) async {
    try {
      // TODO: Tích hợp gọi API KiotViet để tạo khách hàng
      // Dưới đây là logic giả lập
      print('Gọi API KiotViet để tạo khách hàng: $name');

      // Giả sử API KiotViet trả về một ID và mã khách hàng mới
      final kiotVietId = DateTime.now().millisecondsSinceEpoch;
      final kiotVietCode = 'KHT${kiotVietId.toString().substring(5)}';

      final newCustomerData = {
        'id': kiotVietId,
        'code': kiotVietCode,
        'name': name,
        'contactNumber': contactNumber,
        'address': address,
        'branchId': branchId,
        'createdDate': FieldValue.serverTimestamp(),
      };

      // TODO: Lưu khách hàng mới vào collection 'kiotviet_customers' trên Firestore
      // await _firestore.collection('kiotviet_customers').add(newCustomerData);

      return KiotVietCustomer.fromJson(newCustomerData);
    } catch (e) {
      print('Lỗi khi tạo khách hàng mới: $e');
      rethrow;
    }
  }
}
