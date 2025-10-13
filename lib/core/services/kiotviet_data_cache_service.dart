// lib/core/services/kiotviet_data_cache_service.dart

import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_price_book.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_sale_channel.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_price_book_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_sale_channel_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_user_service.dart';

/// A service to fetch and cache relatively static KiotViet data like
/// users, sale channels, and price books to avoid redundant network calls.
class KiotVietDataCacheService with ChangeNotifier {
  final KiotVietUserService _userService = KiotVietUserService();
  final KiotVietSaleChannelService _saleChannelService = KiotVietSaleChannelService();
  final KiotVietPriceBookService _priceBookService = KiotVietPriceBookService();

  List<KiotVietUser>? _users;
  List<KiotVietSaleChannel>? _saleChannels;
  List<KiotVietPriceBook>? _priceBooks;

  List<KiotVietUser>? get users => _users;
  List<KiotVietSaleChannel>? get saleChannels => _saleChannels;
  List<KiotVietPriceBook>? get priceBooks => _priceBooks;

  bool get isInitialized => _users != null && _saleChannels != null && _priceBooks != null;

  /// Fetches all necessary data from KiotViet.
  /// This should be called once during app startup.
  Future<void> init() async {
    // Fetch all data in parallel for faster initialization.
    final results = await Future.wait([
      _userService.getUsers(),
      _saleChannelService.getSaleChannels(),
      _priceBookService.getPriceBooks(),
    ]);

    _users = results[0] as List<KiotVietUser>;
    _saleChannels = results[1] as List<KiotVietSaleChannel>;
    _priceBooks = results[2] as List<KiotVietPriceBook>;

    // Add the default "General Price Book" if it doesn't exist.
    if (!_priceBooks!.any((pb) => pb.id == 0)) {
      _priceBooks!.insert(
        0,
        const KiotVietPriceBook(id: 0, name: 'Bảng giá chung', isActive: true, isGlobal: true),
      );
    }

    notifyListeners();
  }
}
