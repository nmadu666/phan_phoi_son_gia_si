import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_order.dart';
import 'package:phan_phoi_son_gia_si/core/models/paginated_result.dart';

class KiotVietOrdersDialog extends StatefulWidget {
  const KiotVietOrdersDialog({super.key});

  @override
  State<KiotVietOrdersDialog> createState() => _KiotVietOrdersDialogState();
}

class _KiotVietOrdersDialogState extends State<KiotVietOrdersDialog> {
  final KiotVietOrderService _orderService = KiotVietOrderService();
  Future<PaginatedResult<KiotVietOrder>?>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    // Lấy danh sách đơn hàng, sắp xếp theo ngày gần nhất (mặc định của service)
    _ordersFuture = _orderService.getOrders();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return AlertDialog(
      title: const Text('Danh sách đặt hàng KiotViet'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7, // 70% of screen width
        height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
        child: FutureBuilder<PaginatedResult<KiotVietOrder>?>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text('Không thể tải danh sách đơn hàng.'),
              );
            }

            final orders = snapshot.data!.data;

            if (orders.isEmpty) {
              return const Center(child: Text('Không có đơn đặt hàng nào.'));
            }

            return ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
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
                          'Ngày đặt: ${order.purchaseDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(order.purchaseDate!) : 'N/A'}',
                        ),
                        Text(
                          'Trạng thái: ${order.statusValue}',
                          style: TextStyle(
                            color: order.status == 1
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      currencyFormat.format(order.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      // TODO: Implement logic when an order is tapped
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Đóng'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
