import 'package:phan_phoi_son_gia_si/core/models/kiotviet_partner_delivery.dart';

class KiotVietOrder {
  final int id;
  final String code;
  final DateTime? purchaseDate;
  final int? branchId;
  final int? customerId;
  final String? customerName;
  final int? soldById;
  final int? priceBookId;
  final double total;
  final double totalPayment;
  final int status;
  final String? statusValue;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final String? description;
  final double? discount;
  final double? discountRatio;
  final KiotVietOrderDelivery? orderDelivery;
  final List<KiotVietOrderDetail> orderDetails;

  KiotVietOrder({
    required this.id,
    required this.code,
    this.purchaseDate,
    this.branchId,
    this.customerId,
    this.customerName,
    this.soldById,
    this.priceBookId,
    required this.total,
    required this.totalPayment,
    required this.status,
    this.statusValue,
    required this.createdDate,
    this.modifiedDate,
    this.description,
    this.discount,
    this.discountRatio,
    this.orderDelivery,
    required this.orderDetails,
  });

  factory KiotVietOrder.fromJson(Map<String, dynamic> json) {
    return KiotVietOrder(
      id: json['id'],
      code: json['code'],
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.tryParse(json['purchaseDate'])
          : null,
      branchId: json['branchId'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      soldById: json['soldById'],
      priceBookId: json['priceBookId'],
      total: (json['total'] ?? 0).toDouble(),
      totalPayment: (json['totalPayment'] ?? 0).toDouble(),
      status: json['status'],
      statusValue: json['statusValue'] ?? 'N/A',
      createdDate: DateTime.parse(json['createdDate']),
      modifiedDate: json['modifiedDate'] != null
          ? DateTime.tryParse(json['modifiedDate'])
          : null,
      description: json['description'],
      discount: (json['discount'] as num?)?.toDouble(),
      discountRatio: (json['discountRatio'] as num?)?.toDouble(),
      orderDelivery: json['orderDelivery'] != null
          ? KiotVietOrderDelivery.fromJson(json['orderDelivery'])
          : null,
      orderDetails: (json['orderDetails'] as List)
          .map((detail) => KiotVietOrderDetail.fromJson(detail))
          .toList(),
    );
  }
}

class KiotVietOrderDetail {
  final int productId;
  final String? productCode;
  final String? productName;
  final double quantity;
  final double price;
  final double? discount;
  final double? discountRatio;
  final bool? isMaster;
  final String? note;

  KiotVietOrderDetail({
    required this.productId,
    this.productCode,
    this.productName,
    required this.quantity,
    required this.price,
    this.discount,
    this.discountRatio,
    this.isMaster,
    this.note,
  });

  factory KiotVietOrderDetail.fromJson(Map<String, dynamic> json) {
    return KiotVietOrderDetail(
      productId: json['productId'],
      productCode: json['productCode'], // Can be null
      productName: json['productName'], // Can be null
      quantity: (json['quantity'] ?? 0).toDouble(),
      price: (json['price'] ?? 0).toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      discountRatio: (json['discountRatio'] as num?)?.toDouble(),
      isMaster: json['isMaster'],
      note: json['note'],
    );
  }
}

class KiotVietOrderDelivery {
  final String? deliveryCode;
  final double? price;
  final String? receiver;
  final String? contactNumber;
  final String? address;
  final KiotVietPartnerDelivery? partnerDelivery;

  KiotVietOrderDelivery({
    this.deliveryCode,
    this.price,
    this.receiver,
    this.contactNumber,
    this.address,
    this.partnerDelivery,
  });

  factory KiotVietOrderDelivery.fromJson(Map<String, dynamic> json) {
    return KiotVietOrderDelivery(
      deliveryCode: json['deliveryCode'],
      price: (json['price'])?.toDouble(),
      receiver: json['receiver'],
      contactNumber: json['contactNumber'],
      address: json['address'],
      partnerDelivery: json['partnerDelivery'] != null
          ? KiotVietPartnerDelivery.fromJson(json['partnerDelivery'])
          : null,
    );
  }
}
