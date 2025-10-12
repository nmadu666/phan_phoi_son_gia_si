import 'package:equatable/equatable.dart';
import 'package:phan_phoi_son_gia_si/core/models/cart_item.dart';
import 'package:collection/collection.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_sale_channel.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';

/// Represents a temporary order that can be saved and restored.
class TemporaryOrder extends Equatable {
  final String id;
  final String name;
  final List<CartItem> items;
  final String? description;
  final DateTime createdAt;
  final KiotVietCustomer? customer;
  final KiotVietUser? seller;
  final KiotVietSaleChannel? saleChannel;
  // Thêm các trường để lưu thông tin đơn hàng gốc từ KiotViet
  final int? kiotvietOrderId;
  final String? kiotvietOrderCode;
  final int? priceBookId;

  TemporaryOrder({
    required this.id,
    required this.name,
    this.items = const [],
    this.description,
    DateTime? createdAt,
    this.customer,
    this.seller,
    this.saleChannel,
    this.kiotvietOrderId,
    this.kiotvietOrderCode,
    this.priceBookId,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isImportedFromKiotViet => kiotvietOrderId != null;

  /// Calculates the grand total for this order after all line-item discounts.
  double get total => items.fold(
    0.0,
    (previousValue, item) => previousValue + item.totalAfterDiscount,
  );

  /// Calculates the total before any line-item discounts.
  double get totalBeforeDiscount => items.fold(
    0.0,
    (previousValue, item) => previousValue + item.totalBeforeDiscount,
  );

  /// Calculates the total discount amount for the entire order.
  double get totalDiscount => items.fold(
        0.0,
        (previousValue, item) => previousValue + item.discountAmount,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    items,
    description,
    createdAt,
    customer,
    seller,
    saleChannel,
    kiotvietOrderId,
    kiotvietOrderCode,
    priceBookId,
  ];

  TemporaryOrder copyWith({
    String? id,
    String? name,
    List<CartItem>? items,
    String? description,
    DateTime? createdAt,
    KiotVietCustomer? customer,
    KiotVietUser? seller,
    KiotVietSaleChannel? saleChannel,
    int? kiotvietOrderId,
    String? kiotvietOrderCode,
    int? priceBookId,
    // Flags to explicitly set fields to null
    bool clearDescription = false,
    bool clearCustomer = false,
    bool clearSeller = false,
    bool clearSaleChannel = false,
    bool clearPriceBookId = false,
  }) {
    return TemporaryOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      description: clearDescription ? null : description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      customer: clearCustomer ? null : customer ?? this.customer,
      seller: clearSeller ? null : seller ?? this.seller,
      saleChannel: clearSaleChannel ? null : saleChannel ?? this.saleChannel,
      kiotvietOrderId: kiotvietOrderId ?? this.kiotvietOrderId,
      kiotvietOrderCode: kiotvietOrderCode ?? this.kiotvietOrderCode,
      priceBookId: clearPriceBookId ? null : priceBookId ?? this.priceBookId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'customer': customer?.toJson(),
      'seller': seller?.toJson(),
      'saleChannel': saleChannel?.toJson(),
      'kiotvietOrderId': kiotvietOrderId,
      'kiotvietOrderCode': kiotvietOrderCode,
      'priceBookId': priceBookId,
    };
  }

  factory TemporaryOrder.fromJson(Map<String, dynamic> json) {
    final itemsList =
        (json['items'] as List<dynamic>?)
            ?.map(
              (cartItem) => CartItem.fromJson(cartItem as Map<String, dynamic>),
            )
            .toList() ??
        [];

    final customerData = json['customer'] as Map<String, dynamic>?;
    final sellerData = json['seller'] as Map<String, dynamic>?;
    final saleChannelData = json['saleChannel'] as Map<String, dynamic>?;

    return TemporaryOrder(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: itemsList,
      customer: customerData != null
          ? KiotVietCustomer.fromJson(customerData)
          : null,
      seller: sellerData != null ? KiotVietUser.fromJson(sellerData) : null,
      saleChannel: saleChannelData != null
          ? KiotVietSaleChannel.fromJson(saleChannelData)
          : null,
      kiotvietOrderId: json['kiotvietOrderId'] as int?,
      kiotvietOrderCode: json['kiotvietOrderCode'] as String?,
      priceBookId: json['priceBookId'] as int?,
    );
  }

  /// Finds an item in the order by its unique cart item ID.
  CartItem? findItem(String cartItemId) {
    // Using .firstWhereOrNull from collection package is cleaner.
    return items.firstWhereOrNull((item) => item.id == cartItemId);
  }
}
