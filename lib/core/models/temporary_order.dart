/// Represents a single item in the cart/temporary order.
/// NOTE: This is a simplified model. In a real app, it would be more complex,
/// potentially linking to the full Product and Color models.
class CartItem {
  final String productId;
  final String productName;
  final String productCode;
  double quantity;
  double unitPrice;
  double discount; // The value of the discount
  bool
  isDiscountPercentage; // True if discount is a percentage, false for fixed amount
  double?
  overriddenLineTotal; // If not null, this value overrides the calculated total

  CartItem({
    required this.productId,
    required this.productName,
    required this.productCode,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0,
    this.isDiscountPercentage = false,
    this.overriddenLineTotal,
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

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'productCode': productCode,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discount': discount,
    'isDiscountPercentage': isDiscountPercentage,
    'overriddenLineTotal': overriddenLineTotal,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['productId'],
    productName: json['productName'],
    productCode: json['productCode'] ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    isDiscountPercentage: json['isDiscountPercentage'] ?? false,
    overriddenLineTotal: (json['overriddenLineTotal'] as num?)?.toDouble(),
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
}
