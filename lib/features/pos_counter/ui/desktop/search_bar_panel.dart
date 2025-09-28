import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/product_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/product.dart';
import 'package:provider/provider.dart';
import 'dart:async';

/// A widget that contains the main search bar and temporary order tabs,
/// designed to be placed in the AppBar of the POS screen.
class SearchBarPanel extends StatefulWidget {
  const SearchBarPanel({super.key});

  @override
  State<SearchBarPanel> createState() => _SearchBarPanelState();
}

class _SearchBarPanelState extends State<SearchBarPanel> {
  final ScrollController _scrollController = ScrollController();
  final ProductService _productService = ProductService();
  List<Product> _allProducts = [];
  List<Product> _searchResults = [];
  Timer? _debounce;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    _allProducts = await _productService.getProducts();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
        });
        return;
      }
      setState(() {
        _searchResults = _allProducts
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final temporaryOrderService = Provider.of<TemporaryOrderService>(
      context,
      listen: false,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // --- Search Bar ---
        // Use Material 3 SearchAnchor for search functionality
        SearchAnchor(
          builder: (BuildContext context, SearchController controller) {
            return SearchBar(
              controller: controller,
              padding: const MaterialStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onTap: () => controller.openView(),
              onChanged: (_) => controller.openView(),
              leading: const Icon(Icons.search),
              hintText: 'Tìm sản phẩm theo mã hoặc tên (F3)',
              constraints: const BoxConstraints(minWidth: 360.0, maxWidth: 400),
            );
          },
          suggestionsBuilder:
              (BuildContext context, SearchController controller) {
                _onSearchChanged(controller.text);
                return _searchResults.map((product) {
                  return ListTile(
                    title: Text(product.name),
                    onTap: () {
                      setState(() {
                        temporaryOrderService.addItemToActiveOrder(product);
                        controller.closeView(null);
                      });
                    },
                  );
                });
              },
        ),
        const SizedBox(width: 16),

        // --- Temporary Order Tabs ---
        // This part will take the remaining available space.
        // Use a Consumer to listen to changes in TemporaryOrderService
        Consumer<TemporaryOrderService>(
          builder: (context, orderService, child) {
            // Create a list of keys that matches the current list of orders.
            // This avoids side-effects inside the build method.
            final tabKeys = List.generate(
              orderService.orders.length,
              (index) => GlobalKey(),
            );
            // The Expanded widget must be a direct child of the Row.
            // The Listener then wraps the scrollable content inside.
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          final offset =
                              _scrollController.offset +
                              pointerSignal.scrollDelta.dy * 2;
                          _scrollController.animateTo(
                            offset,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.ease,
                          );
                        }
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: orderService.orders.length,
                        itemBuilder: (context, index) {
                          final order = orderService.orders[index];
                          final bool isActive =
                              order.id == orderService.activeOrderId;
                          final key = tabKeys[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: InputChip(
                              key: key,
                              avatar: isActive
                                  ? const Icon(Icons.check_circle, size: 18)
                                  : const Icon(Icons.receipt_long, size: 18),
                              label: Text(order.name),
                              onPressed: () {
                                orderService.setActiveOrder(order.id);
                                // Ensure the just-selected tab is visible.
                                // A short delay allows the UI to rebuild before scrolling.
                                Future.delayed(
                                  const Duration(milliseconds: 50),
                                  () {
                                    if (key.currentContext != null) {
                                      Scrollable.ensureVisible(
                                        key.currentContext!,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  },
                                );
                              },
                              selected: isActive,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              onDeleted: () {
                                // Show a confirmation dialog before deleting
                                showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Xác nhận xóa'),
                                      content: Text(
                                        'Bạn có chắc chắn muốn xóa "${order.name}" không?',
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Không'),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Có, Xóa'),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                            orderService.deleteOrder(order.id);
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // The "Add" button is now outside the ListView, so it's always visible.
                  IconButton(
                    tooltip: 'Thêm đơn tạm mới',
                    onPressed: () {
                      orderService.createNewOrder();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            );
          },
        ),
        // --- Menu Icon ---
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Bảng màu',
          onPressed: () {},
          icon: const Icon(Icons.palette_outlined),
        ),
        IconButton(
          tooltip: 'Xử lý đặt hàng',
          onPressed: () {},
          icon: const Icon(Icons.inventory_2_outlined),
        ),
        IconButton(
          tooltip: 'Menu',
          onPressed: () {
            // TODO: Implement menu action
          },
          icon: const Icon(Icons.menu),
        ),
      ],
    );
  }
}
