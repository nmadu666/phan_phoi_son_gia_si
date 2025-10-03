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
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _suggestionsScrollController = ScrollController();
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Khởi tạo service một lần.
    _kiotVietProductService = KiotVietProductService();
    _suggestionsScrollController.addListener(_onSuggestionsScroll);
    // Lắng nghe sự thay đổi của text trong TextEditingController
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _suggestionsScrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    // _portalController is disposed by the OverlayPortal widget
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchInitialData(query);
    });
  }

  void _onSuggestionsScroll() {
    if (_suggestionsScrollController.position.pixels ==
            _suggestionsScrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLazyLoading) {
      // Thêm kiểm tra _isLazyLoading
      _fetchMoreData(_searchController.text);
    }
  }

  Future<void> _fetchInitialData([String query = '']) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      print('--- DEBUG (UI): Calling service with query: "$query" ---');

      final result = query.isEmpty
          ? await _kiotVietProductService.getRecentProducts()
          : await _kiotVietProductService.searchProducts(query);

      if (!mounted) return;

      final newProducts = result['products'] as List<KiotVietProduct>;
      final lastDoc = result['lastDoc'];

      setState(() {
        _searchResults = newProducts;
        _lastDocument = lastDoc;
        _hasMore = newProducts.length == 15;
      });
    } catch (e, s) {
      debugPrint('Error fetching initial data: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xảy ra lỗi khi tải dữ liệu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMoreData(String query) async {
    if (_isLazyLoading || !_hasMore || _lastDocument == null) return;

    setState(() {
      _isLazyLoading = true;
    });

    try {
      final result = query.isEmpty
          ? await _kiotVietProductService.getRecentProducts(
              lastDoc: _lastDocument,
            )
          : await _kiotVietProductService.searchProducts(
              query,
              lastDoc: _lastDocument,
            );

      if (!mounted) return;

      final moreProducts = result['products'] as List<KiotVietProduct>;
      final lastDoc = result['lastDoc'];

      setState(() {
        _searchResults.addAll(moreProducts);
        _lastDocument = lastDoc;
        _hasMore = moreProducts.length == 15;
      });
    } catch (e, s) {
      debugPrint('Error fetching more data: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xảy ra lỗi khi tải thêm dữ liệu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLazyLoading = false;
        });
      }
    }
  }

  void _onSearchOpened() {
    if (_searchController.text.isEmpty && _searchResults.isEmpty) {
      _fetchInitialData();
    }
  }

  void _onSearchClosed() {
    _portalController.hide();
    setState(() {
      _searchResults = [];
      _lastDocument = null;
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final temporaryOrderService = context.watch<TemporaryOrderService>();
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
            onInvoke: (intent) {
              _searchFocusNode.requestFocus();
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
            SizedBox(
              width: 400,
              child: OverlayPortal(
                controller: _portalController,
                overlayChildBuilder: (BuildContext context) {
                  return Positioned(
                    top: 80, // Vị trí của AppBar
                    left: 200, // Căn chỉnh vị trí theo SearchBar
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 400,
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: _buildSuggestionsList(),
                      ),
                    ),
                  );
                },
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _searchController,
                  onTap: () {
                    _portalController.show();
                    _onSearchOpened();
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm theo mã, tên sản phẩm (F3)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30.0)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  style: const TextStyle(height: 1.2),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // --- Temporary Order Tabs ---
            Expanded(
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
                        itemCount: temporaryOrderService.orders.length,
                        itemBuilder: (context, index) {
                          final order = temporaryOrderService.orders[index];
                          final bool isActive =
                              order.id == temporaryOrderService.activeOrderId;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: InputChip(
                              avatar: isActive
                                  ? const Icon(Icons.check_circle, size: 18)
                                  : const Icon(Icons.receipt_long, size: 18),
                              label: Text(order.name),
                              onPressed: () {
                                temporaryOrderService.setActiveOrder(order.id);
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
                                            temporaryOrderService.deleteOrder(
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
                      temporaryOrderService.createNewOrder();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
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

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(18.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18.0),
        child: Center(
          child: Text(
            _searchController.text.isEmpty
                ? 'Gợi ý sản phẩm gần đây'
                : 'Không tìm thấy sản phẩm nào.',
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      controller: _suggestionsScrollController,
      itemCount: _searchResults.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final product = _searchResults[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text(
            'Mã: ${product.code} - ĐVT: ${product.unit} - Giá: ${product.basePrice}',
          ),
          onTap: () {
            context
                .read<TemporaryOrderService>()
                .addKiotVietProductToActiveOrder(product);
            _onSearchClosed();
          },
        );
      },
    );
  }
}
