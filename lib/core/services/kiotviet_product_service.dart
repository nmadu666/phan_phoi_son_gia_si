import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kiotviet_product.dart';

class KiotVietProductService {
  final FirebaseFirestore _firestore;

  // Sử dụng Dependency Injection: giúp class dễ test và quản lý hơn.
  KiotVietProductService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
      // Xây dựng truy vấn cơ sở
      Query nameBaseQuery = _firestore
          .collection('kiotviet_products')
          .where('name_lowercase', isGreaterThanOrEqualTo: lowerCaseQuery)
          .where('name_lowercase', isLessThan: '$lowerCaseQuery\uf8ff')
          .limit(10);

      Query codeBaseQuery = _firestore
          .collection('kiotviet_products')
          .where('code_lowercase', isGreaterThanOrEqualTo: lowerCaseQuery)
          .where('code_lowercase', isLessThan: '$lowerCaseQuery\uf8ff')
          .limit(10);

      // Nếu có `lastDoc`, bắt đầu truy vấn từ sau tài liệu đó
      if (lastDoc != null) {
        nameBaseQuery = nameBaseQuery.startAfterDocument(lastDoc);
        codeBaseQuery = codeBaseQuery.startAfterDocument(lastDoc);
      }

      final nameQuery = nameBaseQuery;
      final codeQuery = codeBaseQuery;

      // Thực thi cả hai truy vấn song song để tăng hiệu suất.
      final results = await Future.wait([nameQuery.get(), codeQuery.get()]);

      final nameResults = results[0].docs;
      final codeResults = results[1].docs;

      // Sử dụng Map để tự động loại bỏ các sản phẩm trùng lặp
      // (trường hợp sản phẩm khớp cả tên và mã).
      final allDocs = <String, KiotVietProduct>{};

      for (var doc in nameResults) {
        allDocs[doc.id] = KiotVietProduct.fromFirestore(doc);
      }
      for (var doc in codeResults) {
        allDocs[doc.id] = KiotVietProduct.fromFirestore(doc);
      }

      return allDocs.values.toList();
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
