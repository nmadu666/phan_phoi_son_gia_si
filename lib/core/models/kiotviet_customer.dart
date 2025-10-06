import 'package:cloud_firestore/cloud_firestore.dart';

class KiotVietCustomer {
  final int id;
  final String code;
  final String name;
  final String? contactNumber;
  final String? address;
  final String? email;
  final num totalDebt;
  final DateTime? createdDate;
  final DateTime? birthDate;

  KiotVietCustomer({
    required this.id,
    required this.code,
    required this.name,
    this.contactNumber,
    this.address,
    this.email,
    this.totalDebt = 0,
    this.createdDate,
    this.birthDate,
  });

  factory KiotVietCustomer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KiotVietCustomer(
      id: data['id'] ?? 0,
      code: data['code'] ?? '',
      name: data['name'] ?? 'N/A',
      contactNumber: data['contactNumber'],
      address: data['address'],
      email: data['email'],
      totalDebt: data['totalDebt'] ?? 0,
      createdDate: data['createdDate'] != null
          ? (data['createdDate'] as Timestamp).toDate()
          : null,
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'contactNumber': contactNumber,
      'address': address,
      'email': email,
      'totalDebt': totalDebt,
      'createdDate': createdDate?.toIso8601String(),
      'birthDate': birthDate?.toIso8601String(),
    };
  }

  factory KiotVietCustomer.fromJson(Map<String, dynamic> json) {
    return KiotVietCustomer(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      contactNumber: json['contactNumber'],
      address: json['address'],
      email: json['email'],
      totalDebt: json['totalDebt'] ?? 0,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'])
          : null,
      birthDate:
          json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
    );
  }
}
