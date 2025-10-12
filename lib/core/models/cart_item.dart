import 'package:equatable/equatable.dart';

/// Represents a single item in the cart/temporary order.
/// NOTE: This is a simplified model. In a real app, it would be more complex,
/// potentially linking to the full Product and Color models.
class CartItem extends Equatable {
  final String productId;
  final String id;
  final String productFullName;
  final String productName;
  final String productCode;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double discount;
  final bool isMaster;
  final bool isDiscountPercentage;
  final String? note;
  final double? overriddenLineTotal;

  CartItem({
    required this.productId,
    required this.id,
    required this.productFullName,
    required this.productName,
    required this.productCode,
    this.unit = 'Cái',
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0,
    this.isMaster = true,
    this.isDiscountPercentage = false,
    this.overriddenLineTotal,
    this.note,
  });

  /// Tổng tiền trước khi áp dụng giảm giá.
  double get totalBeforeDiscount => unitPrice * quantity;

  /// Số tiền được giảm giá (tính toán từ % hoặc giá trị cố định).
  double get discountAmount {
    if (isDiscountPercentage) {
      final effectiveDiscount = discount.clamp(0.0, 100.0);
      return totalBeforeDiscount * (effectiveDiscount / 100);
    }
    // Đảm bảo giảm giá không vượt quá tổng tiền
    return discount.clamp(0.0, totalBeforeDiscount);
  }

  /// Calculates the final total for this line item after discount.
  /// Renamed from `lineTotal` for clarity.
  double get totalAfterDiscount {
    if (overriddenLineTotal != null) {
      return overriddenLineTotal!;
    }
    return (totalBeforeDiscount - discountAmount);
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    productFullName,
    quantity,
    unitPrice,
    discount,
    isDiscountPercentage,
    overriddenLineTotal,
    note,
  ];

  @override
  String toString() {
    return 'CartItem(id: $id, name: $productFullName, qty: $quantity, '
        'price: $unitPrice, discount: $discount, '
        'isPercentage: $isDiscountPercentage, total: $totalAfterDiscount, '
        'note: $note)';
  }

  CartItem copyWith({
    String? id,
    String? productId,
    String? productFullName,
    String? productName,
    String? productCode,
    String? unit,
    double? quantity,
    double? unitPrice,
    double? discount,
    bool? isMaster,
    bool? isDiscountPercentage,
    double? overriddenLineTotal,
    String? note,
    bool clearOverriddenLineTotal = false,
    bool clearNote = false,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productFullName: productFullName ?? this.productFullName,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      isMaster: isMaster ?? this.isMaster,
      isDiscountPercentage: isDiscountPercentage ?? this.isDiscountPercentage,
      overriddenLineTotal: clearOverriddenLineTotal
          ? null
          : overriddenLineTotal ?? this.overriddenLineTotal,
      note: clearNote ? null : note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productFullName': productFullName,
    'productName': productName,
    'productCode': productCode,
    'unit': unit,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discount': discount,
    'isMaster': isMaster,
    'isDiscountPercentage': isDiscountPercentage,
    'overriddenLineTotal': overriddenLineTotal,
    'note': note,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'] as String? ?? '',
    productId: json['productId'] as String? ?? '',
    productFullName:
        json['productFullName'] as String? ??
        json['productName'] as String? ??
        '',
    productName: json['productName'] as String? ?? '',
    productCode: json['productCode'] as String? ?? '',
    unit: json['unit'] as String? ?? 'Cái',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    isMaster: json['isMaster'] as bool? ?? true,
    isDiscountPercentage: json['isDiscountPercentage'] as bool? ?? false,
    overriddenLineTotal: (json['overriddenLineTotal'] as num?)?.toDouble(),
    note: json['note'] as String?,
  );
}
