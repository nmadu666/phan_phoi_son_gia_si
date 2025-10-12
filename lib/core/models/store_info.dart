import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class StoreInfo extends Equatable {
  final String id;
  final String name;
  final String address;
  final String hotline;
  final String email;
  final String? logoUrl;

  const StoreInfo({
    required this.id,
    this.name = 'Phân Phối Sơn Giá Sỉ',
    this.address = 'Thửa đất số 2599,Tờ bản đồ 11,Đường DE1,Khu phố 1, Phường Thới Hòa, Thị xã Bến Cát, Tỉnh Bình Dương, Việt Nam',
    this.hotline = '02835350330',
    this.email = 'contact@phanphoison.com',
    this.logoUrl,
  });

  factory StoreInfo.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return StoreInfo(
      id: snapshot.id,
      name: data?['name'] ?? 'Tên cửa hàng',
      address: data?['address'] ?? 'Địa chỉ cửa hàng',
      hotline: data?['hotline'] ?? 'N/A',
      email: data?['email'] ?? 'N/A',
      logoUrl: data?['logoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'hotline': hotline,
      'email': email,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }

  @override
  List<Object?> get props => [id, name, address, hotline, email, logoUrl];

  StoreInfo copyWith({
    String? id,
    String? name,
    String? address,
    String? hotline,
    String? email,
    String? logoUrl,
  }) {
    return StoreInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      hotline: hotline ?? this.hotline,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
