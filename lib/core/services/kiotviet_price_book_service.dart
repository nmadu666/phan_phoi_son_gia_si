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
      // 1. Fetch the general price book (id: 0) first.
      final generalPriceBookQuery = await _firestore
          .collection('kiotviet_pricebooks')
          .where('id', isEqualTo: 0)
          .limit(1)
          .get();

      final priceBooks = <KiotVietPriceBook>[];
      if (generalPriceBookQuery.docs.isNotEmpty) {
        priceBooks.add(
          KiotVietPriceBook.fromFirestore(generalPriceBookQuery.docs.first),
        );
      }

      // 2. Fetch other active price books, excluding the one with id 0 to avoid duplicates.
      final otherActivePriceBooksQuery = await _firestore
          .collection('kiotviet_pricebooks')
          .where('isActive', isEqualTo: true)
          .where('id', isNotEqualTo: 0)
          .get();

      final otherActivePriceBooks = otherActivePriceBooksQuery.docs
          .map((doc) => KiotVietPriceBook.fromFirestore(doc))
          .toList();

      priceBooks.addAll(otherActivePriceBooks);
      priceBooks.sort((a, b) => a.id.compareTo(b.id));
      return priceBooks;
    } catch (e) {
      print('An unexpected error occurred while fetching price books: $e');
      return [];
    }
  }
}
