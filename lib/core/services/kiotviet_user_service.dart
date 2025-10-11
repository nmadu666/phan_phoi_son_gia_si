import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';

class KiotVietUserService {
  final FirebaseFirestore _firestore;

  KiotVietUserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<KiotVietUser>> getUsers() async {
    try {
      // Sử dụng .withConverter để đảm bảo type-safety ngay từ câu truy vấn.
      final querySnapshot = await _firestore
          .collection('kiotviet_users')
          .withConverter<KiotVietUser>(
            fromFirestore: (snapshots, _) =>
                KiotVietUser.fromFirestore(snapshots),
            toFirestore: (user, _) => user.toJson(),
          )
          .get();
      // .data() bây giờ sẽ trả về một đối tượng KiotVietUser đã được định kiểu.
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('An unexpected error occurred while fetching users: $e');
      return [];
    }
  }

  /// Fetches a single user from Firestore by their KiotViet ID.
  ///
  /// Returns the [KiotVietUser] if found, otherwise returns null.
  Future<KiotVietUser?> getUserById(int userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('kiotviet_users')
          .where('id', isEqualTo: userId)
          .limit(1)
          .withConverter<KiotVietUser>(
            fromFirestore: (snapshots, _) =>
                KiotVietUser.fromFirestore(snapshots),
            toFirestore: (user, _) => user.toJson(),
          )
          .get();

      return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first.data() : null;
    } catch (e) {
      print('Error fetching user by ID $userId: $e');
      return null;
    }
  }
}
