import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_price_book.dart';

class KiotVietPriceBookService {
  final FirebaseFirestore _firestore;

  KiotVietPriceBookService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches a list of active price books.
  ///
  /// By default, it only fetches price books that are currently active.
  /// It also includes the "Bảng giá chung" which might be marked as inactive
  /// but is always available.
  Future<List<KiotVietPriceBook>> getPriceBooks() async {
    try {
      final querySnapshot = await _firestore
          .collection('kiotviet_pricebooks')
          .where('isActive', isEqualTo: true)
          .get();
      return querySnapshot.docs
          .map((doc) => KiotVietPriceBook.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('An unexpected error occurred while fetching price books: $e');
      return [];
    }
  }
}
