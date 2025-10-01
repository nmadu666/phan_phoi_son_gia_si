import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_product_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_product.dart';
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
  final KiotVietProductService _kiotVietProductService =
      KiotVietProductService();
  Future<List<KiotVietProduct>>? _searchResults;
  Timer? _debounce;
  final SearchController _searchController = SearchController();

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = null;
          });
        }
        return;
      }
      // We are not calling setState here because the FutureBuilder will rebuild
      // when the future changes.
      _searchResults = _kiotVietProductService.searchProducts(query);
      if (mounted) {
        setState(() {});
      }
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
        SearchAnchor(
          searchController: _searchController,
          builder: (BuildContext context, SearchController controller) {
            return SearchBar(
              controller: controller,
              padding: const WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onTap: () {
                controller.openView();
              },
              onChanged: (query) {
                _onSearchChanged(query);
                if (!controller.isOpen) {
                  controller.openView();
                }
              },
              leading: const Icon(Icons.search),
              hintText: 'Tìm theo mã, tên sản phẩm (F3)',
              constraints: const BoxConstraints(minWidth: 360.0, maxWidth: 400),
            );
          },
          suggestionsBuilder:
              (BuildContext context, SearchController controller) {
            if (_searchResults == null) {
              return [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(18.0),
                    child: Text('Nhập để tìm kiếm sản phẩm...'),
                  ),
                )
              ];
            }

            return [
              FutureBuilder<List<KiotVietProduct>>(
                future: _searchResults,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

                  if (snapshot.hasError) {
                    print('FutureBuilder Error: ${snapshot.error}');
                    print('Stack Trace: ${snapshot.stackTrace}');
                    return Center(
                        child: Padding(
                      padding: EdgeInsets.all(18.0),
                      // Display the error message to the user
                      child: Text('Lỗi tìm kiếm: ${snapshot.error}'),
                    ));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18.0),
                        child: Text('Không tìm thấy sản phẩm nào.'),
                      ),
                    );
                  }

                  final results = snapshot.data!;
                  return Column(
                    children: results.map((product) {
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                            'Mã: ${product.code} - ĐVT: ${product.unit} - Giá: ${product.basePrice}'),
                        onTap: () {
                          temporaryOrderService
                              .addKiotVietProductToActiveOrder(product);
                          controller.closeView(null);
                          setState(() {
                            _searchResults = null;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              )
            ];
          },
        ),
        const SizedBox(width: 16),

        // --- Temporary Order Tabs ---
        Consumer<TemporaryOrderService>(
          builder: (context, orderService, child) {
            final tabKeys = List.generate(
              orderService.orders.length,
              (index) => GlobalKey(),
            );
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          final offset = _scrollController.offset +
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