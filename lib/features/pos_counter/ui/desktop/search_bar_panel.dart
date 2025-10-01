import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
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
  List<KiotVietProduct> _searchResults = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _isLazyLoading = false;
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
    _suggestionsScrollController.addListener(_onSuggestionsScroll);
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmedQuery = query.trim();
      if (_currentQuery == trimmedQuery) return;

      _currentQuery = trimmedQuery;
      _fetchInitialData();
    });
  }

  void _onSuggestionsScroll() {
    if (_suggestionsScrollController.position.pixels ==
        _suggestionsScrollController.position.maxScrollExtent) {
      _fetchMoreData();
    }
  }

  Future<void> _fetchInitialData() async {
    if (_isLoading || _isLazyLoading) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _lastDocument = null;
      _hasMore = true;
    });

    final newProducts = _currentQuery.isEmpty
        ? await _kiotVietProductService.getRecentProducts()
        : await _kiotVietProductService.searchProducts(_currentQuery);

    if (!mounted) return;

    setState(() {
      _searchResults = newProducts;
      if (newProducts.isNotEmpty) {
        _lastDocument = newProducts.last as DocumentSnapshot<Object?>?;
      }
      _hasMore = newProducts.length == 15;
      _isLoading = false;
    });
  }

  Future<void> _fetchMoreData() async {
    if (_isLoading || _isLazyLoading || !_hasMore) return;

    setState(() {
      _isLazyLoading = true;
    });

    final moreProducts = _currentQuery.isEmpty
        ? await _kiotVietProductService.getRecentProducts(
            lastDoc: _lastDocument,
          )
        : await _kiotVietProductService.searchProducts(
            _currentQuery,
            lastDoc: _lastDocument,
          );

    if (!mounted) return;

    setState(() {
      _searchResults.addAll(moreProducts);
      if (moreProducts.isNotEmpty) {
        _lastDocument = moreProducts.last as DocumentSnapshot<Object?>?;
      }
      _hasMore = moreProducts.length == 15;
      _isLazyLoading = false;
    });
  }

  void _onSearchOpened() {
    if (_currentQuery.isEmpty && _searchResults.isEmpty) {
      _fetchInitialData();
    }
  }

  void _onSearchClosed() {
    setState(() {
      _searchResults = [];
      _currentQuery = '';
      _lastDocument = null;
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final temporaryOrderService = Provider.of<TemporaryOrderService>(
      context,
      listen: false,
    );
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final userDisplayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName
        : user?.email;

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
            // --- Logo ---
            Padding(
              padding: const EdgeInsets.only(right: 24.0),
              child: Image.asset(
                'assets/images/logo.png',
                height: 36, // Điều chỉnh chiều cao cho phù hợp với AppBar
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.business); // Placeholder
                },
              ),
            ),
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
                  onTap: () {
                    controller.openView();
                    _onSearchOpened();
                  },
                  onChanged: (query) {
                    _onSearchChanged(query);
                    if (!controller.isOpen) {
                      controller.openView();
                    }
                  },
                  leading: const Icon(Icons.search),
                  hintText: 'Tìm theo mã, tên sản phẩm (F3)',
                  constraints: const BoxConstraints(
                    minWidth: 360.0,
                    maxWidth: 400,
                  ),
                );
              },
              suggestionsBuilder:
                  (BuildContext context, SearchController controller) {
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

                    if (_isLoading && _searchResults.isEmpty && _currentQuery.isNotEmpty) {
                      return [
                      ];
                    }

                    if (_searchResults.isEmpty) {
                      return [
                        Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Center(
                            child: Text(_currentQuery.isEmpty
                                ? 'Không có sản phẩm nào.'
                                : 'Không tìm thấy sản phẩm nào.'),
                          ),
                        ),
                      ];
                    }

                    return _searchResults.map(
                      (product) => ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          'Mã: ${product.code} - ĐVT: ${product.unit} - Giá: ${product.basePrice}',
                        ),
                        onTap: () {
                          temporaryOrderService
                              .addKiotVietProductToActiveOrder(
                            product,
                          );
                          controller.closeView(null);
                          _onSearchClosed();
                        },
                      ),
                    ).followedBy(
                      [
                        if (_hasMore)
                          const ListTile(
                            title: Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            ), // Wrap CircularProgressIndicator in ListTile
                          ),
                      ],
                    );
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
                                      : const Icon(
                                          Icons.receipt_long,
                                          size: 18,
                                        ),
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
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();
                                              },
                                            ),
                                            TextButton(
                                              child: const Text('Có, Xóa'),
                                              onPressed: () {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();
                                                orderService.deleteOrder(
                                                  order.id,
                                                );
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
            if (userDisplayName != null) ...[
              const SizedBox(width: 16),
              Text(
                userDisplayName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            PopupMenuButton<String>(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onSelected: (value) {
                if (value == 'logout') {
                  // Gọi hàm signOut từ AuthService
                  context.read<AuthService>().signOut();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Đăng xuất'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
