import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
  late final KiotVietProductService _kiotVietProductService;
  // Thay đổi để lưu trữ danh sách kết quả, không phải Future
  List<KiotVietProduct> _searchResults = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String _currentQuery = '';
  Timer? _debounce;
  final SearchController _searchController = SearchController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _suggestionsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Khởi tạo service một lần.
    _kiotVietProductService = KiotVietProductService();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _suggestionsScrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final trimmedQuery = query.trim();
      if (_currentQuery == trimmedQuery) return;

      _currentQuery = trimmedQuery;

      if (_currentQuery.isEmpty) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        return;
      }
      _fetchProducts(isNewSearch: true);
    });
  }

  Future<void> _fetchProducts({bool isNewSearch = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (isNewSearch) {
        _searchResults = [];
        _hasMore = true;
      }
    });

    // `lastDoc` không thể được truyền trực tiếp, đây là một giới hạn.
    // Để lazy loading thực sự hiệu quả với 2 query song song,
    // cần một logic phức tạp hơn để quản lý `lastDoc` cho từng query.
    // Tạm thời, chúng ta sẽ tải lại toàn bộ kết quả mở rộng.
    // Hoặc đơn giản hơn là chỉ tìm kiếm trên một trường (ví dụ: name).
    final newProducts =
        await _kiotVietProductService.searchProducts(_currentQuery);

    if (!mounted) return;

    setState(() {
      _searchResults = newProducts; // Thay thế kết quả cũ
      _isLoading = false;
      // Giả định không có "tải thêm" trong logic hiện tại,
      // vì việc kết hợp 2 query làm phức tạp việc phân trang.
      _hasMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final temporaryOrderService = Provider.of<TemporaryOrderService>(
      context,
      listen: false,
    );

    // Sử dụng Shortcuts và Actions để xử lý phím tắt F3.
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f3): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _searchFocusNode.requestFocus();
              _searchController.openView();
              return null;
            },
          ),
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Search Bar ---
            SearchAnchor(
              searchController: _searchController,
              builder: (BuildContext context, SearchController controller) {
                return SearchBar(
                  focusNode: _searchFocusNode,
                  controller: controller,
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  onTap: () => controller.openView(),
                  onChanged: (query) {
                    _onSearchChanged(query);
                    if (!controller.isOpen) {
                      controller.openView();
                    }
                  },
                  leading: const Icon(Icons.search),
                  hintText: 'Tìm theo mã, tên sản phẩm (F3)',
                  constraints:
                      const BoxConstraints(minWidth: 360.0, maxWidth: 400),
                );
              },
              suggestionsBuilder:
                  (BuildContext context, SearchController controller) {
                if (_currentQuery.isEmpty) {
                  return [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18.0),
                        child: Text('Nhập để tìm kiếm sản phẩm...'),
                      ),
                    ),
                  ];
                }

                if (_isLoading && _searchResults.isEmpty) {
                  return [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ];
                }

                if (_searchResults.isEmpty) {
                  return [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18.0),
                        child: Text('Không tìm thấy sản phẩm nào.'),
                      ),
                    ),
                  ];
                }

                return _searchResults.map((product) {
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                        'Mã: ${product.code} - ĐVT: ${product.unit} - Giá: ${product.basePrice}'),
                    onTap: () {
                      temporaryOrderService
                          .addKiotVietProductToActiveOrder(product);
                      controller.closeView(null);
                      setState(() {
                        _searchResults = [];
                        _currentQuery = '';
                      });
                    },
                  );
                }).toList();
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
        ),
      ),
    );
  }
}