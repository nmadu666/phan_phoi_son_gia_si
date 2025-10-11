import 'package:equatable/equatable.dart';
import 'package:phan_phoi_son_gia_si/core/models/cart_item.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_sale_channel.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';

/// Represents a temporary order that can be saved and restored.
class TemporaryOrder extends Equatable {
  final String id;
  String name;
  List<CartItem> items;
  String? description;
  final DateTime createdAt;
  KiotVietCustomer? customer;
  KiotVietUser? seller;
  KiotVietSaleChannel? saleChannel;
  // Thêm các trường để lưu thông tin đơn hàng gốc từ KiotViet
  final int? kiotvietOrderId;
  final String? kiotvietOrderCode;
  int? priceBookId;

  TemporaryOrder({
    required this.id,
    required this.name,
    List<CartItem>? items,
    this.description,
    DateTime? createdAt,
    this.customer,
    this.seller,
    this.saleChannel,
    this.kiotvietOrderId,
    this.kiotvietOrderCode,
    this.priceBookId,
  }) : items = items ?? [],
       createdAt = createdAt ?? DateTime.now();

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
    String? description, // Allow null to clear description
    DateTime? createdAt,
    KiotVietCustomer? customer, // Allow null to clear customer
    KiotVietUser? seller, // Allow null to clear seller
    KiotVietSaleChannel? saleChannel,
    int? kiotvietOrderId,
    String? kiotvietOrderCode,
    int? priceBookId,
  }) {
    return TemporaryOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      seller: seller ?? this.seller,
      saleChannel: saleChannel ?? this.saleChannel,
      kiotvietOrderId: kiotvietOrderId ?? this.kiotvietOrderId,
      kiotvietOrderCode: kiotvietOrderCode ?? this.kiotvietOrderCode,
      priceBookId: priceBookId ?? this.priceBookId,
    );
  }
}
