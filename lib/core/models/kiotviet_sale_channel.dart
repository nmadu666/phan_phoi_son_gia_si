import 'package:cloud_firestore/cloud_firestore.dart';

class KiotVietSaleChannel {
  final int id;
  final String name;
  final bool isActive;
  final String? img;

  KiotVietSaleChannel({
    required this.id,
    required this.name,
    required this.isActive,
    this.img,
  });

  factory KiotVietSaleChannel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KiotVietSaleChannel(
      id: data['id'] ?? 0,
      name: data['name'] ?? 'N/A',
      isActive: data['isActive'] ?? false,
      img: data['img'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'isActive': isActive, 'img': img};
  }

  factory KiotVietSaleChannel.fromJson(Map<String, dynamic> json) {
    return KiotVietSaleChannel(
      id: json['id'],
      name: json['name'],
      isActive: json['isActive'],
      img: json['img'],
    );
  }
}
