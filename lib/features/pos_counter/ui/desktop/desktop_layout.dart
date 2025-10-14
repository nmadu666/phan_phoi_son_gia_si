import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/desktop/search_bar_panel_wrapper.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/desktop/cart_items_list.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/desktop/branch_selector.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/temporary_order_service.dart';
import 'customer_checkout_panel.dart';

/// Defines the types of sales modes available in the bottom navigation bar.
enum SaleType {
  quick('Bán nhanh'),
  normal('Bán thường'),
  delivery('Bán giao hàng');

  const SaleType(this.label);
  final String label;
}

/// The main layout for the desktop POS interface, following the 2-column "Quick Sale"
/// design inspired by KiotViet's new web retail interface.
///
/// This layout is composed of:
/// 1. Main Column (Left, ~70%): Contains the search bar and the order items list (cart).
/// 2. Side Column (Right, ~30%): Contains customer information and checkout/payment details.
class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  SaleType _selectedSaleType = SaleType.quick;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        toolbarHeight: 80.0, // Set the desired height for the entire AppBar
        // Use flexibleSpace to have full control over the AppBar's content.
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 64),
                // Placeholder for Search Bar, temporary order tabs, and menu
                child: const SearchBarPanel(),
              ),
            ),
          ),
        ),
      ),
      body: _buildCurrentView(),
      bottomNavigationBar: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Sale type tabs
            Row(
              children: [
                _buildSaleTypeTab(context, SaleType.quick),
                _buildSaleTypeTab(context, SaleType.normal),
                _buildSaleTypeTab(context, SaleType.delivery),
              ],
            ),
            // Right side: Branch selector
            const BranchSelector(),
          ],
        ),
      ),
    );
  }

  /// Builds the main content view based on the currently selected sale type.
  Widget _buildCurrentView() {
    switch (_selectedSaleType) {
      case SaleType.quick:
        return const _QuickSaleView();
      case SaleType.normal:
        return const _NormalSaleView();
      case SaleType.delivery:
        return const _DeliverySaleView();
    }
  }

  /// Helper widget to build a single sale type tab.
  Widget _buildSaleTypeTab(BuildContext context, SaleType saleType) {
    final bool isActive = _selectedSaleType == saleType;
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: () {
        setState(() {
          _selectedSaleType = saleType;
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: isActive
            ? colorScheme.primaryContainer
            : Colors.transparent,
        foregroundColor: isActive
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        saleType.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The view for the "Delivery Sale" mode.
///
/// This layout is a 3-column design:
/// - Left Column (~45%): The current order/cart, description, and checkout.
/// - Middle Column (~27.5%): Customer and Delivery information.
/// - Right Column (~27.5%): Delivery partner information.
class _DeliverySaleView extends StatelessWidget {
  const _DeliverySaleView();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // --- Left Column: Order Panel ---
        Expanded(
          flex: 5, // Represents ~45% of the width
          child: Padding(
            padding: const EdgeInsets.all(
              8.0,
            ), // Sử dụng OrderPanel đã được tái cấu trúc
            child: const _OrderPanel(),
          ),
        ),
        const VerticalDivider(width: 1),
        // --- Middle Column: Customer & Delivery ---
        Expanded(
          flex: 3, // Represents ~27.5% of the width
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: const [
                Expanded(
                  child: Placeholder(
                    child: Center(child: Text('Customer Info')),
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: Placeholder(
                    child: Center(child: Text('Delivery Details')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // --- Right Column: Delivery Partner ---
        Expanded(
          flex: 3, // Represents ~27.5% of the width
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Placeholder(child: Center(child: Text('Đối tác giao hàng'))),
          ),
        ),
      ],
    );
  }
}

/// The view for the "Normal Sale" mode.
///
/// This layout is different from Quick Sale. It features:
/// - Left Column (60%): The current order/cart.
/// - Right Column (40%): A composite panel for selecting a customer and browsing products.
class _NormalSaleView extends StatelessWidget {
  const _NormalSaleView();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // --- Left Column: Order Panel ---
        Expanded(
          flex: 6, // Represents ~60% of the width
          child: Padding(
            padding: const EdgeInsets.all(
              8.0,
            ), // Sử dụng OrderPanel đã được tái cấu trúc
            child: const _OrderPanel(),
          ),
        ),
        const VerticalDivider(width: 1),
        // --- Right Column: Customer & Product List ---
        Expanded(
          flex: 4, // Represents ~40% of the width
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: const [
                // Placeholder for Customer Search/Info
                SizedBox(
                  height: 150,
                  child: Placeholder(
                    child: Center(child: Text('Customer Info Panel')),
                  ),
                ),
                SizedBox(height: 8),
                // Placeholder for Product List/Grid
                Expanded(
                  child: Placeholder(
                    child: Center(child: Text('Product List')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The view for the "Quick Sale" mode, containing the main 2-column layout.
class _QuickSaleView extends StatelessWidget {
  const _QuickSaleView();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // --- Main Column (Left) ---
        Expanded(
          flex: 7, // Represents ~70% of the width
          child: Padding(
            padding: const EdgeInsets.all(
              8.0,
            ), // Sử dụng OrderPanel đã được tái cấu trúc
            child: const _OrderPanel(),
          ),
        ),
        const VerticalDivider(width: 1),
        // --- Side Column (Right) ---
        Expanded(
          flex: 3, // Represents ~30% of the width
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            // Placeholder for Customer Info and Checkout/Payment Panel
            child: const CustomerCheckoutPanel(),
          ),
        ),
      ],
    );
  }
}

/// A reusable widget that encapsulates the cart items list and the order description field.
/// This helps to avoid code duplication across different sale views.
class _OrderPanel extends StatelessWidget {
  const _OrderPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        // 1. The list of items in the cart.
        Expanded(child: CartItemsList()),
        SizedBox(height: 8),
        // 2. The description field for the order.
        _OrderDescriptionField(maxLines: 3),
      ],
    );
  }
}

/// A stateful widget that handles the display and editing of the active order's description.
/// It debounces user input to avoid excessive updates to the order service.
class _OrderDescriptionField extends StatefulWidget {
  final int maxLines;

  const _OrderDescriptionField({required this.maxLines});

  @override
  State<_OrderDescriptionField> createState() => _OrderDescriptionFieldState();
}

class _OrderDescriptionFieldState extends State<_OrderDescriptionField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Listen for text changes to trigger the debounced save.
    _controller.addListener(_onTextChanged);
  }

  @override
  void _onTextChanged() {
    // Cancel any existing timer.
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer. After 500ms, update the order description.
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Check if the widget is still in the tree before calling the service.
      if (mounted) {
        context.read<TemporaryOrderService>().updateOrderDescription(
          _controller.text,
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TỐI ƯU: Sử dụng `context.select` thay vì `context.watch`.
    // Widget này sẽ chỉ rebuild khi giá trị của `description` thay đổi,
    // tránh việc rebuild không cần thiết khi các phần khác của order thay đổi
    // (ví dụ: thêm/xóa sản phẩm).
    final description = context.select<TemporaryOrderService, String>(
      (service) => service.activeOrder?.description ?? '',
    );

    // Cập nhật controller nếu description từ service thay đổi (ví dụ: đổi tab đơn hàng).
    if (_controller.text != description) {
      _controller.text = description;
    }

    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Mô tả đơn hàng',
      ),
      maxLines: widget.maxLines,
    );
  }
}
