import 'package:cloud_firestore/cloud_firestore.dart';

class KiotVietBranch {
  final int id;
  final String branchName;
  final String? branchCode;
  final String? contactNumber;
  final String? email;
  final String? address;
  final int? retailerId;
  final DateTime? modifiedDate;
  final DateTime? createdDate;

  KiotVietBranch({
    required this.id,
    required this.branchName,
    this.branchCode,
    this.contactNumber,
    this.email,
    this.address,
    this.retailerId,
    this.modifiedDate,
    this.createdDate,
  });

  factory KiotVietBranch.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KiotVietBranch(
      id: data['id'] ?? 0,
      branchName: data['branchName'] ?? 'N/A',
      branchCode: data['branchCode'],
      contactNumber: data['contactNumber'],
      email: data['email'],
      address: data['address'],
      retailerId: data['retailerId'],
      modifiedDate: data['modifiedDate'] != null
          ? (data['modifiedDate'] as Timestamp).toDate()
          : null,
      createdDate: data['createdDate'] != null
          ? (data['createdDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branchName': branchName,
      'branchCode': branchCode,
      'contactNumber': contactNumber,
      'email': email,
      'address': address,
      'retailerId': retailerId,
      'modifiedDate': modifiedDate?.toIso8601String(),
      'createdDate': createdDate?.toIso8601String(),
    };
  }

  factory KiotVietBranch.fromJson(Map<String, dynamic> json) {
    return KiotVietBranch(
      id: json['id'],
      branchName: json['branchName'],
      branchCode: json['branchCode'],
      contactNumber: json['contactNumber'],
      email: json['email'],
      address: json['address'],
      retailerId: json['retailerId'],
      modifiedDate: json['modifiedDate'] != null
          ? DateTime.parse(json['modifiedDate'])
          : null,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'])
          : null,
    );
  }
}
