import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';

class KiotVietUserService {
  final FirebaseFirestore _firestore;

  KiotVietUserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<KiotVietUser>> getUsers() async {
    try {
      final querySnapshot = await _firestore.collection('kiotviet_users').get();
      final users = querySnapshot.docs
          .map((doc) => KiotVietUser.fromFirestore(doc))
          .toList();
      return users;
    } catch (e) {
      print('An unexpected error occurred while fetching users: $e');
      return [];
    }
  }
}
