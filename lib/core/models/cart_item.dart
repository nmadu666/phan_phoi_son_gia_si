import 'package:equatable/equatable.dart';

/// Represents a single item in the cart/temporary order.
/// NOTE: This is a simplified model. In a real app, it would be more complex,
/// potentially linking to the full Product and Color models.
class CartItem extends Equatable {
  final String productId;
  final String id; // Unique identifier for this specific cart item instance
  final String
  productFullName; // Tên đầy đủ của sản phẩm (bao gồm cả thuộc tính)
  final String productName;
  final String productCode;
  final String unit;
  double quantity;
  double unitPrice;
  double discount; // The value of the discount
  final bool
  isMaster; // True if this is the original item, false if it's a duplicate
  bool
  isDiscountPercentage; // True if discount is a percentage, false for fixed amount
  String? note;
  double?
  overriddenLineTotal; // If not null, this value overrides the calculated total

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
    // 'id' might be null in older saved data, so we need a fallback.
    // New items should always have a UUID.
    // For simplicity, we'll require it and handle migration if necessary.
    id: json['id'] ?? '',
    productId: json['productId'] ?? '',
    productFullName: json['productFullName'] ?? json['productName'] ?? '',
    productName: json['productName'] ?? '',
    productCode: json['productCode'] ?? '',
    unit: json['unit'] ?? 'Cái',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    isMaster: json['isMaster'] ?? true,
    isDiscountPercentage: json['isDiscountPercentage'] ?? false,
    overriddenLineTotal: (json['overriddenLineTotal'] as num?)?.toDouble(),
    note: json['note'],
  );
}
