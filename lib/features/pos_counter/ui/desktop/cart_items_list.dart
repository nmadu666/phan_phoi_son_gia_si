import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:provider/provider.dart';

/// A widget that displays the list of items for the currently active temporary order.
class CartItemsList extends StatelessWidget {
  const CartItemsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TemporaryOrderService>(
      builder: (context, orderService, child) {
        // Find the currently active order.
        // Using a try-catch block is safer than firstWhere with orElse
        // if the list could be empty during initialization.
        TemporaryOrder? activeOrder;
        try {
          activeOrder = orderService.orders
              .firstWhere((order) => order.id == orderService.activeOrderId);
        } catch (e) {
          activeOrder = null;
        }

        if (activeOrder == null || activeOrder.items.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có sản phẩm trong giỏ hàng',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: activeOrder.items.length,
          itemBuilder: (context, index) {
            final item = activeOrder!.items[index];
            // TODO: In a real app, you would pass the orderId and itemId to the tile
            // to perform actions like increasing/decreasing quantity.
            return _CartItemTile(item: item);
          },
        );
      },
    );
  }
}

/// A single row representing a cart item.
class _CartItemTile extends StatelessWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Text(
            (item.quantity).toString(),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer),
          ),
        ),
        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Đơn giá: ${item.unitPrice.toStringAsFixed(0)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (item.quantity * item.unitPrice).toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                // TODO: Implement decrease quantity logic
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                // TODO: Implement increase quantity logic
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                // TODO: Implement remove item logic
              },
            ),
          ],
        ),
      ),
    );
  }
}