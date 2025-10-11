import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/print_template.dart';

/// Service để quản lý và truy vấn các mẫu in từ Firestore.
class PrintTemplateService {
  final FirebaseFirestore _firestore;

  PrintTemplateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Lấy danh sách các mẫu in dựa trên loại tài liệu.
  ///
  /// Ví dụ: lấy tất cả các mẫu in cho 'hóa đơn'.
  Future<List<PrintTemplate>> getTemplates({
    required PrintTemplateType type,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('print_templates')
          .where('type', isEqualTo: type.name)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      final templates = querySnapshot.docs
          .map((doc) => PrintTemplate.fromFirestore(doc))
          .toList();

      return templates;
    } catch (e) {
      debugPrint('Lỗi khi lấy mẫu in: $e');
      return [];
    }
  }
}
