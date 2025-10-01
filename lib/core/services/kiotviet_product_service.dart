import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kiotviet_product.dart';

class KiotVietProductService {
  final FirebaseFirestore _firestore;

  // Sử dụng Dependency Injection: giúp class dễ test và quản lý hơn.
  KiotVietProductService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<KiotVietProduct>> getRecentProducts({
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
      return querySnapshot.docs
          .map((doc) => KiotVietProduct.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('An unexpected error occurred while fetching recent products: $e');
      return [];
    }
  }

  Future<List<KiotVietProduct>> searchProducts(
    String query, {
    DocumentSnapshot? lastDoc,
  }) async {
    // Bỏ qua khoảng trắng thừa và kiểm tra nếu query rỗng.
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    // Chuyển query sang chữ thường để tìm kiếm không phân biệt hoa/thường.
    final lowerCaseQuery = trimmedQuery.toLowerCase();

    try {
      // Ưu tiên tìm kiếm theo mã sản phẩm trước, sau đó đến tên.
      // Điều này giúp đơn giản hóa việc phân trang.
      Query baseQuery = _firestore
          .collection('kiotviet_products')
          .where('search_keywords', arrayContains: lowerCaseQuery)
          .orderBy('createdDate', descending: true) // Sắp xếp để phân trang nhất quán
          .limit(15);

      // Nếu có `lastDoc`, bắt đầu truy vấn từ sau tài liệu đó
      if (lastDoc != null) {
        baseQuery = baseQuery.startAfterDocument(lastDoc);
      }

      final querySnapshot = await baseQuery.get();

      // Để tìm kiếm hiệu quả hơn trên nhiều trường, bạn nên xem xét
      // việc tạo một trường `search_keywords` trong document Firestore.
      // Trường này là một mảng chứa các từ khóa đã được chuẩn hóa (chữ thường).
      // Ví dụ: ['sp001', 'son', 'mau', 'xanh']
      // Sau đó, bạn có thể dùng `array-contains` để truy vấn.
      // Điều này đòi hỏi bạn phải cập nhật dữ liệu trên Firestore.
      return querySnapshot.docs
          .map((doc) => KiotVietProduct.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      print(
        'A Firebase error occurred while searching products: ${e.code} - ${e.message}',
      );
      return [];
    } catch (e) {
      print('An unexpected error occurred while searching products: $e');
      return []; // Return an empty list in case of an error
    }
  }
}
