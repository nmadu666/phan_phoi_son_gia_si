import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/pos_settings_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/pos_settings.dart';

/// A widget that displays the list of items for the currently active temporary order.
class CartItemsList extends StatefulWidget {
  const CartItemsList({super.key});

  @override
  State<CartItemsList> createState() => _CartItemsListState();
}

class _CartItemsListState extends State<CartItemsList> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TemporaryOrderService>(
      builder: (context, orderService, child) {
        // Find the currently active order.
        // Using a try-catch block is safer than firstWhere with orElse
        // if the list could be empty during initialization.
        TemporaryOrder? activeOrder;
        try {
          activeOrder = orderService.orders.firstWhere(
            (order) => order.id == orderService.activeOrderId,
          );
        } catch (e) {
          activeOrder = null;
        }

        if (activeOrder == null || activeOrder!.items.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có sản phẩm trong giỏ hàng',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Use another Consumer for settings to rebuild when settings change.
        return Consumer<PosSettingsService>(
          builder: (context, settingsService, child) {
            final settings = settingsService.settings;

            // Using a DataTable for a better column-based layout.
            return SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                columns: _buildColumns(context, settings),
                rows: List<DataRow>.generate(
                  activeOrder!.items.length,
                  (index) => _buildRow(
                    context,
                    orderService,
                    activeOrder!.items[index],
                    index,
                    settings,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<DataColumn> _buildColumns(BuildContext context, PosSettings settings) {
    final List<DataColumn> columns = [];

    if (settings.showLineNumber) {
      columns.add(const DataColumn(label: Text('#')));
    }
    columns.add(const DataColumn(label: Text('Tên sản phẩm')));
    if (settings.showProductCode) {
      columns.add(const DataColumn(label: Text('Mã hàng')));
    }
    columns.add(const DataColumn(label: Text('SL'), numeric: true));
    if (settings.showSellingPrice) {
      columns.add(const DataColumn(label: Text('Giá bán'), numeric: true));
    }
    if (settings.showDiscount) {
      columns.add(const DataColumn(label: Text('Giảm giá'), numeric: true));
    }
    if (settings.showLineTotal) {
      columns.add(const DataColumn(label: Text('Thành tiền'), numeric: true));
    }
    columns.add(const DataColumn(label: Text(''))); // For actions

    return columns;
  }

  DataRow _buildRow(
    BuildContext context,
    TemporaryOrderService orderService,
    CartItem item,
    int index,
    PosSettings settings,
  ) {
    final List<DataCell> cells = [];

    if (settings.showLineNumber) {
      cells.add(DataCell(Text((index + 1).toString())));
    }
    cells.add(
      DataCell(
        Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
    if (settings.showProductCode) {
      cells.add(DataCell(Text(item.productCode)));
    }
    // Quantity Cell
    cells.add(
      DataCell(
        Text(item.quantity.toString()),
        showEditIcon: true,
        onTap: () {
          _showEditDialog(
            context,
            title: 'Cập nhật số lượng',
            initialValue: item.quantity.toString(),
            onSave: (newValue) {
              final newQuantity = double.tryParse(newValue);
              if (newQuantity != null) {
                orderService.updateItemQuantity(item.productId, newQuantity);
              }
            },
          );
        },
      ),
    );
    // Unit Price (Selling Price) Cell
    if (settings.showSellingPrice) {
      cells.add(
        DataCell(
          Text(item.unitPrice.toStringAsFixed(0)),
          showEditIcon: true,
          onTap: () {
            _showEditDialog(
              context,
              title: 'Cập nhật giá bán',
              initialValue: item.unitPrice.toStringAsFixed(0),
              onSave: (newValue) {
                final newPrice = double.tryParse(newValue);
                if (newPrice != null) {
                  orderService.updateItemUnitPrice(item.productId, newPrice);
                }
              },
            );
          },
        ),
      );
    }
    // Discount Cell
    if (settings.showDiscount) {
      final discountText = item.isDiscountPercentage
          ? '${item.discount}%'
          : item.discount.toStringAsFixed(0);
      cells.add(
        DataCell(
          Text(discountText),
          showEditIcon: true,
          onTap: () {
            _showDiscountEditDialog(
              context,
              item: item,
              onSave: (newValue, isPercentage) {
                orderService.applyItemDiscount(
                  item.productId,
                  newValue,
                  isPercentage: isPercentage,
                );
              },
            );
          },
        ),
      );
    }
    // Line Total Cell
    if (settings.showLineTotal) {
      cells.add(
        DataCell(
          Text(
            item.lineTotal.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          showEditIcon: settings.allowEditLineTotal,
          onTap: settings.allowEditLineTotal
              ? () {
                  _showEditDialog(
                    context,
                    title: 'Cập nhật thành tiền',
                    initialValue: item.lineTotal.toStringAsFixed(0),
                    onSave: (newValue) {
                      final newTotal = double.tryParse(newValue);
                      orderService.overrideItemLineTotal(
                        item.productId,
                        newTotal,
                      );
                    },
                  );
                }
              : null,
        ),
      );
    }
    // Actions Cell
    cells.add(
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (settings.showLastPrice)
              IconButton(
                icon: const Icon(Icons.history_outlined),
                tooltip: 'Xem giá gần nhất',
                onPressed: () {
                  // TODO: Implement show last price logic
                },
              ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Giảm số lượng',
              onPressed: () {
                orderService.updateItemQuantity(
                  item.productId,
                  item.quantity - 1,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Tăng số lượng',
              onPressed: () {
                orderService.updateItemQuantity(
                  item.productId,
                  item.quantity + 1,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Xóa sản phẩm',
              onPressed: () {
                orderService.removeItem(item.productId);
              },
            ),
          ],
        ),
      ),
    );

    return DataRow(cells: cells);
  }

  /// Shows a generic dialog for editing a numeric value.
  Future<void> _showEditDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required void Function(String) onSave,
    TextInputType keyboardType = const TextInputType.numberWithOptions(
      decimal: true,
    ),
  }) async {
    final controller = TextEditingController(text: initialValue);
    // Select all text for easy replacement
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: keyboardType,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) {
              onSave(value);
              Navigator.of(dialogContext).pop();
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: const Text('Lưu'),
              onPressed: () {
                onSave(controller.text);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Shows a specific dialog for editing the discount value and type (VND/%).
  Future<void> _showDiscountEditDialog(
    BuildContext context, {
    required CartItem item,
    required void Function(double, bool) onSave,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _DiscountEditDialog(
          initialValue: item.discount,
          initialIsPercentage: item.isDiscountPercentage,
          onSave: (newValue, isPercentage) {
            onSave(newValue, isPercentage);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }
}

/// A stateful dialog widget to edit discount value and type.
class _DiscountEditDialog extends StatefulWidget {
  final double initialValue;
  final bool initialIsPercentage;
  final Function(double, bool) onSave;

  const _DiscountEditDialog({
    required this.initialValue,
    required this.initialIsPercentage,
    required this.onSave,
  });

  @override
  State<_DiscountEditDialog> createState() => _DiscountEditDialogState();
}

class _DiscountEditDialogState extends State<_DiscountEditDialog> {
  late TextEditingController _controller;
  late List<bool> _selections;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(0),
    );
    _selections = [!widget.initialIsPercentage, widget.initialIsPercentage];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cập nhật giảm giá'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Giá trị giảm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ToggleButtons(
            isSelected: _selections,
            onPressed: (int index) {
              setState(() {
                for (int i = 0; i < _selections.length; i++) {
                  _selections[i] = i == index;
                }
              });
            },
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            children: const <Widget>[Text('VND'), Text('%')],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Hủy'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: const Text('Lưu'),
          onPressed: () {
            final double? value = double.tryParse(_controller.text);
            final bool isPercentage = _selections[1];
            if (value != null) {
              widget.onSave(value, isPercentage);
            }
          },
        ),
      ],
    );
  }
}
