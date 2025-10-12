import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class KiotVietUser extends Equatable {
  final int id;
  final String userName;
  final String givenName;
  final String? phoneNumber;

  const KiotVietUser({
    required this.id,
    required this.userName,
    required this.givenName,
    this.phoneNumber,
  });

  factory KiotVietUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KiotVietUser(
      id: data['id'] ?? 0,
      userName: data['userName'] ?? '',
      givenName: data['givenName'] ?? 'N/A',
      phoneNumber: data['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'givenName': givenName,
      'phoneNumber': phoneNumber,
    };
  }

  factory KiotVietUser.fromJson(Map<String, dynamic> json) {
    return KiotVietUser(
      id: json['id'],
      userName: json['userName'],
      givenName: json['givenName'],
      phoneNumber: json['phoneNumber'],
    );
  }

  @override
  List<Object?> get props => [id, userName, givenName, phoneNumber];
}
