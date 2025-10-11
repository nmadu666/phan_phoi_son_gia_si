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

  List<String> _generateSearchKeywords(String name, String? contactNumber) {
    final nonDiacriticName = _removeDiacritics(name.toLowerCase());
    final keywords = <String>{};

    // Thêm các từ trong tên
    keywords.addAll(nonDiacriticName.split(' ').where((s) => s.isNotEmpty));

    // Thêm số điện thoại nếu có
    if (contactNumber != null && contactNumber.isNotEmpty) {
      keywords.add(contactNumber);
    }

    return keywords.toList();
  }

  Future<Map<String, dynamic>> searchCustomers(
    String query, {
    AppUser? currentUser,
    int? branchId,
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) async {
    try {
      // Start with a base query that can be built upon.
      // Using .withConverter ensures type safety from the start.
      Query<KiotVietCustomer> baseQuery = _firestore
          .collection('kiotviet_customers')
          .withConverter<KiotVietCustomer>(
            fromFirestore: (snapshots, _) =>
                KiotVietCustomer.fromFirestore(snapshots),
            toFirestore: (customer, _) => customer.toJson(),
          );

      final trimmedQuery = query.trim();
      if (trimmedQuery.isNotEmpty) {
        final lowerCaseQuery = _removeDiacritics(trimmedQuery.toLowerCase());
        // Firestore has limitations on combining 'array-contains' with other filters.
        // We apply the search keyword filter first.
        // Note: This might override other filters in complex scenarios.
        // For more advanced search, consider a dedicated search service like Algolia.
        baseQuery = baseQuery.where(
          'search_keywords',
          arrayContains: lowerCaseQuery,
        );
      }

      // Always apply branch filter if available. It can be combined with 'array-contains' or range filters.
      if (branchId != null) {
        baseQuery = baseQuery.where('branchId', isEqualTo: branchId);
      }

      // CRITICAL: Firestore does not allow combining 'array-contains' with range filters (e.g., >=, <).
      // Therefore, we only apply the user 'code' filter if there is NO search query.
      if (trimmedQuery.isEmpty &&
          currentUser != null &&
          currentUser.role != 'admin' &&
          currentUser.code != null &&
          currentUser.code!.isNotEmpty) {
        // This is a prefix search on the 'code' field, only applied when not searching.
        baseQuery = baseQuery
            .where('code', isGreaterThanOrEqualTo: currentUser.code)
            .where('code', isLessThan: '${currentUser.code}\uf8ff');
      }

      if (lastDoc != null) {
        baseQuery = baseQuery.startAfterDocument(lastDoc);
      }

      // Limit the results
      final finalQuery = baseQuery.limit(limit);

      final querySnapshot = await finalQuery.get();
      final customers = querySnapshot.docs
          .map(
            (doc) => doc.data(),
          ) // .data() now returns a typed KiotVietCustomer object
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
      // TODO: Trong tương lai, bạn sẽ gọi API KiotViet tại đây để tạo khách hàng
      // và nhận về ID, mã từ KiotViet.

      // Hiện tại, chúng ta giả lập ID và mã này.
      final kiotVietId = DateTime.now().millisecondsSinceEpoch;
      final kiotVietCode = 'KHT${kiotVietId.toString().substring(5)}';

      // Tạo đối tượng khách hàng mới
      final newCustomer = KiotVietCustomer(
        id: kiotVietId,
        code: kiotVietCode,
        name: name,
        contactNumber: contactNumber,
        address: address,
        branchId: branchId,
        createdDate:
            DateTime.now(), // Sẽ được thay thế bằng timestamp của server
        searchKeywords: _generateSearchKeywords(name, contactNumber),
      );

      // Chuyển đổi đối tượng thành Map để lưu vào Firestore
      final customerData = newCustomer.toJson();
      // Thêm/Cập nhật các trường đặc biệt của Firestore
      customerData['createdDate'] = FieldValue.serverTimestamp();
      // Firestore không lưu các trường null, nên ta có thể giữ chúng
      // hoặc loại bỏ nếu muốn. `toJson` đã xử lý việc này.

      // Lưu khách hàng mới vào collection 'kiotviet_customers' trên Firestore
      // Sử dụng `doc(kiotVietCode)` để đảm bảo mã khách hàng là duy nhất
      // và dễ dàng truy vấn sau này.
      await _firestore
          .collection('kiotviet_customers')
          .doc(kiotVietCode)
          .set(customerData);

      // Trả về đối tượng khách hàng đã được tạo
      return newCustomer;
    } catch (e) {
      print('Lỗi khi tạo khách hàng mới: $e');
      rethrow;
    }
  }

  /// Fetches a single customer from Firestore by their KiotViet ID.
  ///
  /// Returns the [KiotVietCustomer] if found, otherwise returns null.
  Future<KiotVietCustomer?> getCustomerById(int customerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('kiotviet_customers')
          .where('id', isEqualTo: customerId)
          .limit(1)
          .withConverter<KiotVietCustomer>(
            fromFirestore: (snapshots, _) =>
                KiotVietCustomer.fromFirestore(snapshots),
            toFirestore: (customer, _) => customer.toJson(),
          )
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error fetching customer by ID $customerId: $e');
      return null;
    }
  }
}
