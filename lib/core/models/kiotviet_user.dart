import 'package:cloud_firestore/cloud_firestore.dart';

class KiotVietUser {
  final int id;
  final String userName;
  final String givenName;

  KiotVietUser({
    required this.id,
    required this.userName,
    required this.givenName,
  });

  factory KiotVietUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KiotVietUser(
      id: data['id'] ?? 0,
      userName: data['userName'] ?? '',
      givenName: data['givenName'] ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'userName': userName, 'givenName': givenName};
  }

  factory KiotVietUser.fromJson(Map<String, dynamic> json) {
    return KiotVietUser(
      id: json['id'],
      userName: json['userName'],
      givenName: json['givenName'],
    );
  }
}
