import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:provider/provider.dart';

class KiotVietOrdersDialog extends StatefulWidget {
  const KiotVietOrdersDialog({super.key});

  @override
  State<KiotVietOrdersDialog> createState() => _KiotVietOrdersDialogState();
}

class _KiotVietOrdersDialogState extends State<KiotVietOrdersDialog> {
  final KiotVietOrderService _orderService = KiotVietOrderService();
  final ScrollController _scrollController = ScrollController();

  // State for lazy loading
  final List<KiotVietOrder> _orders = [];
  bool _isLoading = false; // For initial load
  bool _isLazyLoading = false; // For subsequent loads
  bool _hasMore = true;
  int _currentItem = 0;
  final int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    // Sử dụng addPostFrameCallback để truy cập context một cách an toàn
    // sau khi frame đầu tiên được build xong.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialOrders();
    });

    _scrollController.addListener(() {
      // Trigger fetch more when user scrolls to the end of the list
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent -
                  200 && // Add a buffer
          _hasMore &&
          !_isLoading &&
          !_isLazyLoading) {
        _fetchMoreOrders();
      }
    });
  }

  Future<void> _fetchInitialOrders() async {
    // Lấy branchId từ AppStateService
    final appState = context.read<AppStateService>(); // Safe to use here
    final selectedBranchId = appState.get<int>(
      AppStateService.selectedBranchIdKey,
    );

    if (selectedBranchId == null) {
      // Nếu không có chi nhánh nào được chọn, không tải dữ liệu
      setState(() {
        _isLoading = false;
        _orders.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _orders.clear();
      _currentItem = 0;
      _hasMore = true;
    });

    // Lấy danh sách đơn hàng theo chi nhánh và trạng thái
    // Status: 1 (Phiếu tạm), 2 (Đang giao hàng - cần xác nhận lại mã này)
    final result = await _orderService.getOrders(
      branchIds: [selectedBranchId],
      status: [1, 2],
      pageSize: _pageSize,
      currentItem: _currentItem,
    );

    if (mounted) {
      setState(() {
        if (result != null) {
          _orders.addAll(result.data);
          _currentItem += result.data.length;
          _hasMore = result.data.length == _pageSize;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreOrders() async {
    if (_isLazyLoading || !_hasMore || _isLoading) return;

    setState(() {
      _isLazyLoading = true;
    });

    final appState = context.read<AppStateService>();
    final selectedBranchId = appState.get<int>(
      AppStateService.selectedBranchIdKey,
    );

    if (selectedBranchId == null) {
      setState(() => _isLazyLoading = false);
      return;
    }

    final result = await _orderService.getOrders(
      branchIds: [selectedBranchId],
      status: [1, 2],
      pageSize: _pageSize,
      currentItem: _currentItem,
    );

    if (mounted) {
      setState(() {
        if (result != null) {
          _orders.addAll(result.data);
          _currentItem += result.data.length;
          _hasMore = result.data.length == _pageSize;
        }
        _isLazyLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final selectedBranchId = context.watch<AppStateService>().get<int>(
      AppStateService.selectedBranchIdKey,
    );

    return AlertDialog(
      title: const Text('Danh sách đặt hàng KiotViet'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7, // 70% of screen width
        height:
            MediaQuery.of(context).size.height * 0.8, // 80% of screen height
        child: _buildContent(context, currencyFormat, selectedBranchId),
      ),
      actions: <Widget>[
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại'),
          onPressed: _fetchInitialOrders,
        ),
        TextButton(
          child: const Text('Đóng'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    NumberFormat currencyFormat,
    int? selectedBranchId,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedBranchId == null) {
      return const Center(
        child: Text('Vui lòng chọn một chi nhánh để xem đơn hàng.'),
      );
    }

    if (_orders.isEmpty) {
      return const Center(child: Text('Không có đơn đặt hàng nào.'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _orders.length + (_isLazyLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final order = _orders[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              '${order.code} - ${order.customerName ?? 'Khách lẻ'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngày đặt: ${order.purchaseDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(order.purchaseDate!) : 'N/A'}',
                ),
                Text(
                  'Trạng thái: ${order.statusValue}',
                  style: TextStyle(
                    color: order.status == 1 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            trailing: Text(
              currencyFormat.format(order.total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onTap: () {
              // TODO: Implement logic when an order is tapped
            },
          ),
        );
      },
    );
  }
}
