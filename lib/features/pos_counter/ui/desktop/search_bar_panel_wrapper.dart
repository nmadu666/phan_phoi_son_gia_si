import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/logic/product_search_provider.dart';
import 'package:phan_phoi_son_gia_si/features/store_management/ui/store_management_screen.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/desktop/pos_settings_dialog.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/dialogs/kiotviet_orders_dialog.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/logic/kiotviet_orders_provider.dart';
import 'package:phan_phoi_son_gia_si/features/user_management/ui/user_management_screen.dart';
import 'package:provider/provider.dart';

/// A widget that contains the main search bar and temporary order tabs,
/// designed to be placed in the AppBar of the POS screen.
/// This widget is now wrapped with a ChangeNotifierProvider for ProductSearchProvider.
class SearchBarPanelWrapper extends StatelessWidget {
  const SearchBarPanelWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductSearchProvider(),
      child: const SearchBarPanel(),
    );
  }
}

class SearchBarPanel extends StatefulWidget {
  const SearchBarPanel({super.key});

  @override
  State<SearchBarPanel> createState() => _SearchBarPanelState();
}

class _SearchBarPanelState extends State<SearchBarPanel> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu người dùng khi widget được khởi tạo
    context.read<AppUserService>().initForCurrentUser(context.read<AuthService>().currentUser);
  }

  @override
  Widget build(BuildContext context) {
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
            _Logo(),
            // --- Search Bar ---
            _SearchBar(focusNode: _searchFocusNode),
            const SizedBox(width: 16),
            // --- Temporary Order Tabs ---
            const Expanded(child: _TemporaryOrderTabs()),
            // --- Menu Icon ---
            _ActionMenu(),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24.0),
      child: Image.asset(
        'assets/images/logo.png',
        height: 36,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.business);
        },
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final FocusNode focusNode;
  const _SearchBar({required this.focusNode});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final OverlayPortalController _portalController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<ProductSearchProvider>().onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _portalController,
          overlayChildBuilder: (BuildContext context) {
            return CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0.0, 56.0),
              child: const _SuggestionsList(),
            );
          },
          child: TextField(
            focusNode: widget.focusNode,
            controller: _searchController,
            style: const TextStyle(height: 1.2),
            onTap: () {
              if (!_portalController.isShowing) {
                _portalController.show();
                // Initial fetch when tapping
                context.read<ProductSearchProvider>().onSearchChanged('');
              }
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm theo mã, tên sản phẩm (F3)',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(30.0)),
                borderSide: BorderSide.none,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  widget.focusNode.unfocus();
                  context.read<ProductSearchProvider>().clearSearch();
                  if (_portalController.isShowing) {
                    _portalController.hide();
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatefulWidget {
  const _SuggestionsList();

  @override
  State<_SuggestionsList> createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<_SuggestionsList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<ProductSearchProvider>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      provider.fetchMoreData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Consumer<ProductSearchProvider>(
          builder: (context, provider, child) {
            switch (provider.state) {
              case SearchState.loading:
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(18.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              case SearchState.error:
                return const Center(child: Text('Lỗi tải dữ liệu.'));
              case SearchState.idle:
              case SearchState.success:
                if (provider.searchResults.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Center(
                      child: Text(
                        provider.currentQuery.isEmpty
                            ? 'Gợi ý sản phẩm gần đây'
                            : 'Không tìm thấy sản phẩm nào.',
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: provider.searchResults.length +
                      (provider.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.searchResults.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final product = provider.searchResults[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'Mã: ${product.code} - ĐVT: ${product.unit} - Giá: ${product.basePrice}',
                      ),
                      onTap: () {
                        context
                            .read<TemporaryOrderService>()
                            .addKiotVietProductToActiveOrder(product);
                        // Logic để đóng suggestions sẽ được xử lý trong _SearchBar
                      },
                    );
                  },
                );
            }
          },
        ),
      ),
    );
  }
}

class _TemporaryOrderTabs extends StatelessWidget {
  const _TemporaryOrderTabs();

  @override
  Widget build(BuildContext context) {
    final temporaryOrderService = context.watch<TemporaryOrderService>();
    final scrollController = ScrollController();

    return Row(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final offset =
                    scrollController.offset + pointerSignal.scrollDelta.dy * 2;
                scrollController.animateTo(
                  offset,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.ease,
                );
              }
            },
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: temporaryOrderService.orders.length,
              itemBuilder: (context, index) {
                final order = temporaryOrderService.orders[index];
                final bool isActive =
                    order.id == temporaryOrderService.activeOrderId;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InputChip(
                    avatar: isActive
                        ? const Icon(Icons.check_circle, size: 18)
                        : const Icon(Icons.receipt_long, size: 18),
                    label: Text(order.name),
                    onPressed: () =>
                        temporaryOrderService.setActiveOrder(order.id),
                    selected: isActive,
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    onDeleted: () => _showDeleteConfirmation(context, order.id, order.name),
                  ),
                );
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'Thêm đơn tạm mới',
          onPressed: () => temporaryOrderService.createNewOrder(),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, String orderId, String orderName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa "$orderName" không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Không'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Có, Xóa'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<TemporaryOrderService>().deleteOrder(orderId);
              },
            ),
          ],
        );
      },
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final userDisplayName =
        user?.displayName?.isNotEmpty == true ? user!.displayName : user?.email;

    // Lắng nghe AppUserService để lấy thông tin vai trò người dùng
    final appUser = context.watch<AppUserService>().appUser;
    final bool isAdmin = appUser?.role == 'admin';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Bảng màu',
          onPressed: () {},
          icon: const Icon(Icons.palette_outlined),
        ),
        IconButton(
          tooltip: 'Xử lý đặt hàng',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => ChangeNotifierProvider(
                create: (_) => KiotVietOrdersProvider(),
                child: const KiotVietOrdersDialog(),
              ),
            );
          },
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
          onSelected: (value) => _onMenuSelected(context, value),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Tùy chỉnh hiển thị'),
              ),
            ),
            if (isAdmin)
              const PopupMenuItem<String>(
                value: 'user_management',
                child: ListTile(
                  leading: Icon(Icons.manage_accounts_outlined),
                  title: Text('Quản lý người dùng'),
                ),
              ),
            if (isAdmin)
              const PopupMenuItem<String>(
                value: 'store_management',
                child: ListTile(
                  leading: Icon(Icons.store_mall_directory_outlined),
                  title: Text('Quản lý cửa hàng'),
                ),
              ),
            const PopupMenuDivider(),
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
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'settings':
        showDialog(
          context: context,
          builder: (context) => const PosSettingsDialog(),
        );
        break;
      case 'user_management':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const UserManagementScreen()),
        );
        break;
      case 'store_management':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const StoreManagementScreen()),
        );
        break;
      case 'logout':
        context.read<AuthService>().signOut();
        break;
    }
  }
}
