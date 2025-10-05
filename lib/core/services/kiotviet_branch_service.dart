import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';

class KiotVietBranchService {
  final FirebaseFirestore _firestore;

  KiotVietBranchService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<KiotVietBranch>> getBranches() async {
    try {
      final querySnapshot = await _firestore
          .collection('kiotviet_branches')
          .get();
      final branches = querySnapshot.docs
          .map((doc) => KiotVietBranch.fromFirestore(doc))
          .toList();
      return branches;
    } catch (e) {
      print('An unexpected error occurred while fetching branches: $e');
      return [];
    }
  }
}
