import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a KiotViet Price Book.
/// This model stores the main information about a price book, such as its name,
/// status, and applicability dates.
class KiotVietPriceBook extends Equatable {
  final int id;
  final String name;
  final bool isActive;
  final bool isGlobal;
  final DateTime? startDate;
  final DateTime? endDate;

  const KiotVietPriceBook({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isGlobal,
    this.startDate,
    this.endDate,
  });

  /// Creates a KiotVietPriceBook from a Firestore document.
  factory KiotVietPriceBook.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return KiotVietPriceBook.fromJson(data);
  }

  /// Creates a KiotVietPriceBook from a JSON map.
  factory KiotVietPriceBook.fromJson(Map<String, dynamic> json) {
    return KiotVietPriceBook(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'N/A',
      isActive: json['isActive'] ?? false,
      isGlobal: json['isGlobal'] ?? false,
      // Handle both Timestamp (from Firestore) and String (from other JSON sources)
      startDate: json['startDate'] is Timestamp
          ? (json['startDate'] as Timestamp).toDate()
          : (json['startDate'] != null
                ? DateTime.tryParse(json['startDate'])
                : null),
      endDate: json['endDate'] is Timestamp
          ? (json['endDate'] as Timestamp).toDate()
          : (json['endDate'] != null
                ? DateTime.tryParse(json['endDate'])
                : null),
    );
  }

  /// Converts this KiotVietPriceBook object into a JSON map.
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

  /// Creates a copy of this KiotVietPriceBook but with the given fields replaced with the new values.
  KiotVietPriceBook copyWith({
    int? id,
    String? name,
    bool? isActive,
    bool? isGlobal,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return KiotVietPriceBook(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      isGlobal: isGlobal ?? this.isGlobal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  String toString() {
    return 'KiotVietPriceBook(id: $id, name: $name, isActive: $isActive, isGlobal: $isGlobal)';
  }

  @override
  List<Object?> get props => [id, name, isActive, isGlobal, startDate, endDate];
}
