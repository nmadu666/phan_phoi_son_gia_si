/// Represents a single item in the cart/temporary order.
/// NOTE: This is a simplified model. In a real app, it would be more complex,
/// potentially linking to the full Product and Color models.
class CartItem {
  final String productId;
  final String id; // Unique identifier for this specific cart item instance
  final String productFullName;
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

  /// Calculates the final total for this line item.
  double get lineTotal {
    if (overriddenLineTotal != null) {
      return overriddenLineTotal!;
    }
    final double totalBeforeDiscount = unitPrice * quantity;
    if (isDiscountPercentage) {
      // Ensure discount doesn't exceed 100%
      final effectiveDiscount = discount.clamp(0, 100);
      return totalBeforeDiscount * (1 - (effectiveDiscount / 100));
    } else {
      // Ensure discount doesn't exceed the total price
      return (totalBeforeDiscount - discount).clamp(0, double.infinity);
    }
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
      note: note ?? this.note,
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
    // However, new items should always have a UUID.
    // For simplicity, we'll require it and handle migration if necessary.
    id: json['id'] ?? '',
    productId: json['productId'] ?? '',
    productFullName: json['productFullName'] ?? json['productName'],
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

/// Represents a temporary order that can be saved and restored.
class TemporaryOrder {
  final String id;
  String name;
  List<CartItem> items;
  String description;
  final DateTime createdAt;

  TemporaryOrder({
    required this.id,
    required this.name,
    List<CartItem>? items,
    this.description = '',
    DateTime? createdAt,
  }) : items = items ?? [],
       createdAt = createdAt ?? DateTime.now();

  // In a real app, you would add toJson/fromJson for persistence.

  TemporaryOrder copyWith({
    String? id,
    String? name,
    List<CartItem>? items,
    String? description,
    DateTime? createdAt,
  }) {
    return TemporaryOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
}
}
