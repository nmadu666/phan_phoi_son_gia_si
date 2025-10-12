import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_product.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_product_service.dart';

enum SearchState { idle, loading, success, error }

class ProductSearchProvider with ChangeNotifier {
  final KiotVietProductService _productService = KiotVietProductService();

  List<KiotVietProduct> _searchResults = [];
  DocumentSnapshot? _lastDocument;
  SearchState _state = SearchState.idle;
  bool _isLazyLoading = false;
  bool _hasMore = true;
  Timer? _debounce;
  String _currentQuery = '';

  List<KiotVietProduct> get searchResults => _searchResults;
  SearchState get state => _state;
  bool get isLazyLoading => _isLazyLoading;
  bool get hasMore => _hasMore;
  String get currentQuery => _currentQuery;

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchInitialData(query);
    });
  }

  Future<void> _fetchInitialData([String query = '']) async {
    if (_state == SearchState.loading) return;

    _currentQuery = query;
    _state = SearchState.loading;
    notifyListeners();

    try {
      final result = query.isEmpty
          ? await _productService.getRecentProducts()
          : await _productService.searchProducts(query);

      final newProducts = result['products'] as List<KiotVietProduct>;
      _lastDocument = result['lastDoc'];
      _searchResults = newProducts;
      _hasMore = newProducts.length >= 15; // Giả sử page size là 15
      _state = SearchState.success;
    } catch (e) {
      debugPrint('Error fetching initial product data: $e');
      _state = SearchState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchMoreData() async {
    if (_isLazyLoading || !_hasMore || _lastDocument == null) return;

    _isLazyLoading = true;
    notifyListeners();

    try {
      final result = _currentQuery.isEmpty
          ? await _productService.getRecentProducts(lastDoc: _lastDocument)
          : await _productService.searchProducts(
              _currentQuery,
              lastDoc: _lastDocument,
            );

      final moreProducts = result['products'] as List<KiotVietProduct>;
      _lastDocument = result['lastDoc'];
      _searchResults.addAll(moreProducts);
      _hasMore = moreProducts.length >= 15;
    } catch (e) {
      debugPrint('Error fetching more product data: $e');
      // Có thể set một state lỗi riêng cho lazy loading nếu cần
    } finally {
      _isLazyLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _currentQuery = '';
    _searchResults = [];
    _state = SearchState.idle;
    _debounce?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
