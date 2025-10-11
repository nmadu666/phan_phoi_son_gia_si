import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_order.dart';
import 'package:phan_phoi_son_gia_si/core/models/paginated_result.dart';

enum KiotVietOrdersState { initial, loading, success, error }

class KiotVietOrdersProvider with ChangeNotifier {
  final KiotVietOrderService _orderService = KiotVietOrderService();

  final List<KiotVietOrder> _orders = [];
  KiotVietOrdersState _state = KiotVietOrdersState.initial;
  String? _errorMessage;
  bool _hasMore = true;
  bool _isLazyLoading = false;
  int _currentItem = 0;
  final int _pageSize = 30;
  String _searchQuery = '';
  // Mặc định lọc theo cả Phiếu tạm (1) và Đang giao hàng (2)
  List<int> _selectedStatus = [1, 2];

  List<KiotVietOrder> get orders => _orders;
  KiotVietOrdersState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLazyLoading => _isLazyLoading;

  List<int> get selectedStatus => _selectedStatus;

  Future<void> fetchOrders(
    int branchId, {
    bool isRefresh = false,
    String? query,
    List<int>? status,
  }) async {
    // Coi việc tìm kiếm mới như một lần làm mới (refresh)
    final isNewSearch = query != null && query != _searchQuery;
    // Coi việc thay đổi bộ lọc trạng thái như một lần làm mới
    final isNewFilter = status != null && status != _selectedStatus;

    if (isRefresh || isNewSearch || isNewFilter) {
      _currentItem = 0;
      _orders.clear();
      _hasMore = true;
      _state = KiotVietOrdersState.loading;
      _searchQuery = query ?? '';
    } else {
      if (_isLazyLoading || !_hasMore) return;
      _isLazyLoading = true;
    }
    notifyListeners();

    try {
      final PaginatedResult<KiotVietOrder>? result = await _orderService
          .getOrders(
            branchIds: [branchId],
            status: _selectedStatus, // Sử dụng trạng thái đã chọn
            pageSize: _pageSize,
            currentItem: _currentItem,
            query: _searchQuery, // Truyền query xuống service
          );

      if (result != null) {
        _orders.addAll(result.data);
        _currentItem += result.data.length;
        _hasMore = result.data.length == _pageSize;
        _state = KiotVietOrdersState.success;
      } else {
        // Trường hợp service trả về null mà không throw exception
        _errorMessage = 'Không thể tải dữ liệu đơn hàng.';
        _state = KiotVietOrdersState.error;
      }
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi: $e';
      _state = KiotVietOrdersState.error;
    } finally {
      _isLazyLoading = false;
      notifyListeners();
    }
  }
}
