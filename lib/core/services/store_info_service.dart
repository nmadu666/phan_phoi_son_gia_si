import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';

class StoreInfoService with ChangeNotifier {
  final FirebaseFirestore _firestore;
  List<StoreInfo> _stores = []; // Bắt đầu với danh sách rỗng
  bool _isInitialized = false;

  List<StoreInfo> get stores => _stores;
  bool get isInitialized => _isInitialized;
  StoreInfo get defaultStore =>
      _stores.isNotEmpty ? _stores.first : StoreInfo(id: 'default');

  StoreInfoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> init() async {
    if (_isInitialized) return;
    await _fetchStoreInfo();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _fetchStoreInfo() async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .orderBy('name')
          .get();
      final fetchedStores = snapshot.docs
          .map((doc) => StoreInfo.fromFirestore(doc))
          .toList();

      if (fetchedStores.isNotEmpty) {
        _stores = fetchedStores;
      } else {
        // Nếu không có cửa hàng nào trên Firestore, tạo một cửa hàng mặc định
        _stores = [StoreInfo(id: 'default_local')];
      }
    } catch (e) {
      debugPrint('Error fetching stores info: $e');
      // Giữ lại giá trị mặc định nếu có lỗi
    }
  }

  Future<void> addStore(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('stores').add(data);
      await _fetchStoreInfo(); // Tải lại danh sách
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding store: $e');
      rethrow;
    }
  }

  Future<void> updateStore(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('stores').doc(id).update(data);
      await _fetchStoreInfo(); // Tải lại danh sách
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating store: $e');
      rethrow;
    }
  }

  Future<void> deleteStore(String id) async {
    try {
      // Ngăn chặn xóa cửa hàng cuối cùng
      if (_stores.length <= 1) {
        throw Exception('Không thể xóa cửa hàng cuối cùng.');
      }
      await _firestore.collection('stores').doc(id).delete();
      await _fetchStoreInfo(); // Tải lại danh sách
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting store: $e');
      rethrow;
    }
  }
}
