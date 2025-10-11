import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a KiotViet Price Book.
/// This model stores the main information about a price book, such as its name,
/// status, and applicability dates.
class KiotVietPriceBook {
  final int id;
  final String name;
  final bool isActive;
  final bool isGlobal;
  final DateTime? startDate;
  final DateTime? endDate;

  KiotVietPriceBook({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isGlobal,
    this.startDate,
    this.endDate,
  });

  factory KiotVietPriceBook.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return KiotVietPriceBook(
      id: data['id'] ?? 0,
      name: data['name'] ?? 'N/A',
      isActive: data['isActive'] ?? false,
      isGlobal: data['isGlobal'] ?? false,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
      'isGlobal': isGlobal,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }
}
