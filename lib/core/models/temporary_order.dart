import 'dart:convert';

/// Represents a single item in the cart/temporary order.
/// NOTE: This is a simplified model. In a real app, it would be more complex,
/// potentially linking to the full Product and Color models.
class CartItem {
  final String productId;
  final String productName;
  int quantity;
  double unitPrice;

  CartItem({
    required this.productId,
    required this.productName,
    this.quantity = 1,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'],
        productName: json['productName'],
        quantity: json['quantity'],
        unitPrice: json['unitPrice'],
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
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  // In a real app, you would add toJson/fromJson for persistence.
}

