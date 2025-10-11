import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/logic/kiotviet_orders_provider.dart';
import 'package:provider/provider.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_order.dart';

class KiotVietOrdersDialog extends StatefulWidget {
  const KiotVietOrdersDialog({super.key});

  @override
  State<KiotVietOrdersDialog> createState() => _KiotVietOrdersDialogState();
}

class _KiotVietOrdersDialogState extends State<KiotVietOrdersDialog> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isImporting = false;
  int? _importingOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders(isRefresh: true);
    });

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _fetchOrders(isRefresh: true, query: _searchController.text);
      });
    });

    _scrollController.addListener(() {
      final provider = context.read<KiotVietOrdersProvider>();
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent -
                  200 && // Tải thêm khi gần cuối danh sách
          provider.hasMore &&
          !provider.isLazyLoading) {
        _fetchOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({
    bool isRefresh = false,
    String? query,
    List<int>? status,
  }) async {
    final appState = context.read<AppStateService>();
    final selectedBranchId = appState.get<int>(
      AppStateService.selectedBranchIdKey,
    );

    if (selectedBranchId == null) {
      return;
    }

    // Gọi phương thức fetchOrders từ provider
    await context.read<KiotVietOrdersProvider>().fetchOrders(
      selectedBranchId,
      isRefresh: isRefresh,
      query: query,
      status: status,
    );
  }

  Future<void> _importOrder(KiotVietOrder order) async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
      _importingOrderId = order.id;
    });

    try {
      // Sử dụng context.read để lấy service một cách an toàn
      final orderService = context.read<KiotVietOrderService>();
      final temporaryOrderService = context.read<TemporaryOrderService>();

      // 1. Lấy chi tiết đơn hàng từ KiotViet
      final detailedOrder = await orderService.getOrderById(order.id);

      if (detailedOrder == null) {
        throw Exception('Không thể tải chi tiết đơn hàng.');
      }

      // 2. Import vào TemporaryOrderService
      await temporaryOrderService.importKiotVietOrder(detailedOrder);

      // 3. Đóng dialog và hiển thị thông báo thành công
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã import đơn hàng ${order.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Lỗi khi import đơn hàng'),
            content: SingleChildScrollView(child: SelectableText(e.toString())),
            actions: <Widget>[
              TextButton(
                child: const Text('Đóng'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final selectedBranchId = context.watch<AppStateService>().get<int>(
      AppStateService.selectedBranchIdKey,
    );
    final provider = context.watch<KiotVietOrdersProvider>();

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(flex: 2, child: Text('Danh sách đặt hàng KiotViet')),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã đơn, tên khách...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7, // 70% of screen width
        height:
            MediaQuery.of(context).size.height * 0.8, // 80% of screen height
        child: _buildContent(provider, currencyFormat, selectedBranchId),
      ),
      actions: <Widget>[
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại'),
          onPressed: provider.state == KiotVietOrdersState.loading
              ? null
              : () => _fetchOrders(isRefresh: true),
        ),
        TextButton(
          child: const Text('Đóng'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _onStatusFilterChanged(int status) {
    final provider = context.read<KiotVietOrdersProvider>();
    List<int> newStatus = List.from(provider.selectedStatus);

    if (newStatus.contains(status)) {
      // Không cho phép bỏ chọn nếu chỉ còn một trạng thái
      if (newStatus.length > 1) {
        newStatus.remove(status);
      }
    } else {
      newStatus.add(status);
    }
    _fetchOrders(status: newStatus);
  }

  Widget _buildContent(
    KiotVietOrdersProvider provider,
    NumberFormat currencyFormat,
    int? selectedBranchId,
  ) {
    if (provider.state == KiotVietOrdersState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedBranchId == null) {
      return const Center(
        child: Text('Vui lòng chọn một chi nhánh để xem đơn hàng.'),
      );
    }

    if (provider.state == KiotVietOrdersState.error) {
      return Center(child: Text(provider.errorMessage ?? 'Đã xảy ra lỗi.'));
    }

    if (provider.orders.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Không có đơn đặt hàng nào.'
              : 'Không tìm thấy đơn hàng phù hợp.',
        ),
      );
    }

    final orders = provider.orders;

    return ListView.builder(
      controller: _scrollController,
      itemCount: orders.length + (provider.isLazyLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final order = orders[index];
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
                  'Ngày đặt: ${order.purchaseDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(order.purchaseDate!.toLocal()) : 'N/A'}',
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
              _importOrder(order);
            },
            // Hiển thị loading indicator cho item đang được import
            leading: _isImporting && _importingOrderId == order.id
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : CircleAvatar(child: Text(order.status == 1 ? 'T' : 'G')),
          ),
        );
      },
    );
  }
}
