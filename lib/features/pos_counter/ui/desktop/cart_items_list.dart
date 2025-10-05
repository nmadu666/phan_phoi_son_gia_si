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

            // Using ReorderableListView to allow drag-and-drop functionality.
            // We manually build a header row and then the list of items
            // to maintain a table-like appearance.
            return Column(
              children: [
                _buildHeaderRow(settings),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: activeOrder!.items.length,
                    itemBuilder: (context, index) {
                      final item = activeOrder!.items[index];
                      return _ReorderableRow(
                        context,
                        orderService,
                        item,
                        index,
                        settings,
                        // Use a unique key for each item to help the reorderable list
                        key: ValueKey(item.id),
                      );
                    },
                    onReorder: orderService.reorderItem,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the header row for the cart items table.
  Widget _buildHeaderRow(PosSettings settings) {
    return Table(
      columnWidths: _getColumnWidths(settings),
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1.5,
              ),
            ),
          ),
          children: _buildHeaderCells(settings: settings),
        ),
      ],
    );
  }

  /// Defines the widths for each column in the table.
  Map<int, TableColumnWidth> _getColumnWidths(PosSettings settings) {
    final Map<int, TableColumnWidth> widths = {};
    int i = 0;

    if (settings.showLineNumber) {
      widths[i++] = const FixedColumnWidth(40);
    }
    widths[i++] = const FlexColumnWidth(3); // Hàng hóa
    widths[i++] = const FlexColumnWidth(1.8); // SL
    if (settings.showSellingPrice) {
      widths[i++] = const FlexColumnWidth(1.2);
    }
    if (settings.showDiscount) {
      widths[i++] = const FlexColumnWidth(1.2);
    }
    if (settings.showLineTotal) {
      widths[i++] = const FlexColumnWidth(1.5);
    }
    widths[i++] = const FlexColumnWidth(2); // Actions

    return widths;
  }

  /// Builds the list of cells for the header row only.
  List<Widget> _buildHeaderCells({required PosSettings settings}) {
    final List<Widget> cells = [];

    // Helper to add a cell with consistent padding.
    void addCell(Widget child, {TextAlign align = TextAlign.start}) {
      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Align(
            alignment: align == TextAlign.end
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: child,
          ),
        ),
      );
    }

    if (settings.showLineNumber) {
      addCell(const Text('#'));
    }
    addCell(const Text('Hàng hóa'));
    addCell(const Text('SL'), align: TextAlign.end);
    if (settings.showSellingPrice) {
      addCell(const Text('Giá bán'), align: TextAlign.end);
    }
    if (settings.showDiscount) {
      addCell(const Text('Giảm giá'), align: TextAlign.end);
    }
    if (settings.showLineTotal) {
      addCell(const Text('Thành tiền'), align: TextAlign.end);
    }
    addCell(const SizedBox()); // For actions
    return cells;
  }
}

class _ReorderableRow extends StatefulWidget {
  final BuildContext context;
  final TemporaryOrderService orderService;
  final CartItem item;
  final int index;
  final PosSettings settings;

  const _ReorderableRow(
    this.context,
    this.orderService,
    this.item,
    this.index,
    this.settings, {
    required super.key,
  });

  @override
  State<_ReorderableRow> createState() => _ReorderableRowState();
}

class _ReorderableRowState extends State<_ReorderableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final rowContent = Container(
      decoration: BoxDecoration(
        color: _isHovered ? Colors.grey.withOpacity(0.1) : null,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Table(
        columnWidths: _getColumnWidths(widget.settings),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: _buildCells(
              settings: widget.settings,
              item: widget.item,
              index: widget.index,
              orderService: widget.orderService,
              isHovered: _isHovered,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onDoubleTap: () {
        _showNoteEditDialog(
          context,
          initialValue: widget.item.note ?? '',
          onSave: (newNote) {
            widget.orderService.updateItemNote(widget.item.id, newNote);
          },
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Tooltip(
          message: widget.item.note ?? 'Nhấp đúp để thêm ghi chú',
          child: rowContent,
        ),
      ),
    );
  }

  /// Defines the widths for each column in the table.
  /// This is a copy from the parent state to make this widget self-contained.
  Map<int, TableColumnWidth> _getColumnWidths(PosSettings settings) {
    final Map<int, TableColumnWidth> widths = {};
    int i = 0;

    if (settings.showLineNumber) {
      widths[i++] = const FixedColumnWidth(40);
    }
    widths[i++] = const FlexColumnWidth(3); // Hàng hóa
    widths[i++] = const FlexColumnWidth(1.8); // SL
    if (settings.showSellingPrice) {
      widths[i++] = const FlexColumnWidth(1.2);
    }
    if (settings.showDiscount) {
      widths[i++] = const FlexColumnWidth(1.2);
    }
    if (settings.showLineTotal) {
      widths[i++] = const FlexColumnWidth(1.5);
    }
    widths[i++] = const FlexColumnWidth(2); // Actions

    return widths;
  }

  /// Builds the list of cells for a data row.
  /// This is a modified copy from the parent state.
  List<Widget> _buildCells({
    required PosSettings settings,
    required CartItem item,
    required int index,
    required TemporaryOrderService orderService,
    bool isHovered = false,
  }) {
    final List<Widget> cells = [];

    void addCell(Widget child, {TextAlign align = TextAlign.start}) {
      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Align(
            alignment: align == TextAlign.end
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: child,
          ),
        ),
      );
    }

    if (settings.showLineNumber) {
      addCell(Text((index + 1).toString()));
    }

    addCell(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productFullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (settings.showProductCode)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      'Mã: ${item.productCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (item.note != null && item.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Ghi chú: ${item.note}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isHovered)
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: 'Xem tồn kho',
              onPressed: () {},
            ),
        ],
      ),
    );

    addCell(
      _QuantityCounter(
        quantity: item.quantity,
        onIncrement: () =>
            orderService.updateItemQuantity(item.id, item.quantity + 1),
        onDecrement: () =>
            orderService.updateItemQuantity(item.id, item.quantity - 1),
        onTap: () => _showEditDialog(
          context,
          title: 'Cập nhật số lượng',
          initialValue: item.quantity.toString(),
          onSave: (newValue) {
            final newQuantity = double.tryParse(newValue);
            if (newQuantity != null) {
              orderService.updateItemQuantity(item.id, newQuantity);
            }
          },
        ),
      ),
      align: TextAlign.end,
    );

    if (settings.showSellingPrice) {
      addCell(
        InkWell(
          onTap: () {
            _showEditDialog(
              context,
              title: 'Cập nhật giá bán',
              initialValue: item.unitPrice.toStringAsFixed(0),
              onSave: (newValue) {
                final newPrice = double.tryParse(newValue);
                if (newPrice != null) {
                  orderService.updateItemUnitPrice(item.id, newPrice);
                }
              },
            );
          },
          child: Text(
            item.unitPrice.toStringAsFixed(0),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: isHovered
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
        align: TextAlign.end,
      );
    }

    if (settings.showDiscount) {
      final discountText = item.isDiscountPercentage
          ? '${item.discount}%'
          : item.discount.toStringAsFixed(0);
      addCell(
        InkWell(
          onTap: () {
            _showDiscountEditDialog(
              context,
              item: item,
              onSave: (newValue, isPercentage) {
                orderService.applyItemDiscount(
                  item.id,
                  newValue,
                  isPercentage: isPercentage,
                );
              },
            );
          },
          child: Text(
            discountText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: isHovered
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
        align: TextAlign.end,
      );
    }

    if (settings.showLineTotal) {
      addCell(
        InkWell(
          onTap: settings.allowEditLineTotal
              ? () {
                  _showEditDialog(
                    context,
                    title: 'Cập nhật thành tiền',
                    initialValue: item.lineTotal.toStringAsFixed(0),
                    onSave: (newValue) {
                      final newTotal = double.tryParse(newValue);
                      orderService.overrideItemLineTotal(item.id, newTotal);
                    },
                  );
                }
              : null,
          child: Text(
            item.lineTotal.toStringAsFixed(0),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: settings.allowEditLineTotal
                  ? Theme.of(context).colorScheme.primary
                  : null,
              decoration: settings.allowEditLineTotal && isHovered
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
        align: TextAlign.end,
      );
    }

    addCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
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
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Sao chép dòng',
            onPressed: () {
              orderService.duplicateItem(item);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Xóa sản phẩm',
            onPressed: () {
              orderService.removeItem(item.id);
            },
          ),
        ],
      ),
    );

    return cells;
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

  /// Shows a dialog for editing the item note.
  Future<void> _showNoteEditDialog(
    BuildContext context, {
    required String initialValue,
    required void Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Ghi chú hàng hóa'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.text,
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

/// A compact widget for incrementing/decrementing quantity.
class _QuantityCounter extends StatelessWidget {
  final double quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onTap;

  const _QuantityCounter({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverableQuantityCounter(
      quantity: quantity,
      onIncrement: onIncrement,
      onDecrement: onDecrement,
      onTap: onTap,
    );
  }
}

class _HoverableQuantityCounter extends StatefulWidget {
  final double quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onTap;

  const _HoverableQuantityCounter({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.onTap,
  });

  @override
  State<_HoverableQuantityCounter> createState() =>
      _HoverableQuantityCounterState();
}

class _HoverableQuantityCounterState extends State<_HoverableQuantityCounter> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isHovered)
            _buildIconButton(Icons.remove_circle_outline, widget.onDecrement),
          if (_isHovered) const SizedBox(width: 8),
          _buildQuantityText(),
          if (_isHovered) const SizedBox(width: 8),
          if (_isHovered)
            _buildIconButton(Icons.add_circle_outline, widget.onIncrement),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: onPressed,
    );
  }

  Widget _buildQuantityText() {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Text(
          widget.quantity.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
