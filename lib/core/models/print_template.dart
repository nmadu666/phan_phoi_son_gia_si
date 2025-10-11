import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum để xác định loại tài liệu của mẫu in.
enum PrintTemplateType {
  invoice, // Hóa đơn
  receipt, // Phiếu thu
  deliveryNote, // Phiếu giao hàng
  unknown,
}

/// Đại diện cho một mẫu in được lưu trữ trên Firestore.
class PrintTemplate extends Equatable {
  final String id;
  final String name;
  final PrintTemplateType type;
  final String content; // Nội dung template (ví dụ: HTML, Liquid,...)
  final bool isDefault;

  const PrintTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    this.isDefault = false,
  });

  /// Chuyển đổi một DocumentSnapshot từ Firestore thành đối tượng PrintTemplate.
  factory PrintTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PrintTemplate(
      id: doc.id,
      name: data['name'] ?? 'Không tên',
      type: _stringToTemplateType(data['type']),
      content: data['content'] ?? '',
      isDefault: data['isDefault'] ?? false,
    );
  }

  /// Chuyển đổi chuỗi thành enum PrintTemplateType.
  static PrintTemplateType _stringToTemplateType(String? typeString) {
    switch (typeString) {
      case 'invoice':
        return PrintTemplateType.invoice;
      case 'receipt':
        return PrintTemplateType.receipt;
      case 'deliveryNote':
        return PrintTemplateType.deliveryNote;
      default:
        return PrintTemplateType.unknown;
    }
  }

  @override
  List<Object?> get props => [id, name, type, content, isDefault];

  @override
  String toString() {
    return 'PrintTemplate(id: $id, name: "$name", type: $type)';
  }
}
