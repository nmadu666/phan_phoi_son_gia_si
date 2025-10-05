import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_sale_channel.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_sale_channel_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_user_service.dart';
import 'package:provider/provider.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_customer_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/temporary_order.dart';
import '../../../../core/services/app_state_service.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../core/services/auth_service.dart';

class CustomerCheckoutPanel extends StatefulWidget {
  const CustomerCheckoutPanel({super.key});

  @override
  State<CustomerCheckoutPanel> createState() => _CustomerCheckoutPanelState();
}

class _CustomerCheckoutPanelState extends State<CustomerCheckoutPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final KiotVietUserService _userService = KiotVietUserService();
  final KiotVietCustomerService _customerService = KiotVietCustomerService();
  final KiotVietSaleChannelService _saleChannelService =
      KiotVietSaleChannelService();

  List<KiotVietCustomer> _searchResults = [];
  late Future<List<KiotVietUser>> _usersFuture;
  late Future<List<KiotVietSaleChannel>> _saleChannelsFuture;
  bool _isLoading = false;
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
    _usersFuture = _userService.getUsers();
    _saleChannelsFuture = _saleChannelService.getSaleChannels();
    _setDefaultSeller();
  }

  void _setDefaultSeller() {
    // Lấy các service cần thiết từ context
    final authService = context.read<AuthService>();
    final orderService = context.read<TemporaryOrderService>();
    final appUserService = context.read<AppUserService>();
    final currentUser = authService.currentUser;

    if (currentUser != null && orderService.activeOrderId != null) {
      final activeOrder = orderService.orders.firstWhere(
        (o) => o.id == orderService.activeOrderId,
      );
      // Chỉ đặt nhân viên mặc định nếu chưa có ai được chọn
      if (activeOrder.seller == null) {
        // Lấy thông tin AppUser và sau đó lấy KiotVietUser từ reference
        appUserService.getUser(currentUser.uid).then((appUser) async {
          if (appUser?.kiotvietUserRef != null) {
            final defaultSeller = await appUserService.getUserFromRef(
              appUser!.kiotvietUserRef,
            );
            orderService.setSellerForActiveOrder(defaultSeller);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _hideOverlay();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final appState = context.read<AppStateService>();
    final authService = context.read<AuthService>();
    final appUserService = context.read<AppUserService>();

    final branchId = appState.get<int>(AppStateService.selectedBranchIdKey);
    final appUser = authService.currentUser != null
        ? await appUserService.getUser(authService.currentUser!.uid)
        : null;

    final result = await _customerService.searchCustomers(
      query,
      currentUser: appUser,
      branchId: branchId,
    );
    if (mounted) {
      setState(() {
        _searchResults = result['customers'];
        _isLoading = false;
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 8.0),
          child: Material(elevation: 4.0, child: _buildSuggestionsList()),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const ListTile(title: Text('Không tìm thấy khách hàng'));
    }
    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final customer = _searchResults[index];
          return ListTile(
            title: Text(customer.name),
            subtitle: Text(
              '${customer.code} - ${customer.contactNumber ?? ''}',
            ),
            onTap: () {
              context.read<TemporaryOrderService>().setCustomerForActiveOrder(
                customer,
              );
              _searchController.clear();
              _searchFocusNode.unfocus();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<TemporaryOrderService>();
    final activeOrder = orderService.orders.firstWhere(
      (o) => o.id == orderService.activeOrderId,
      orElse: () => TemporaryOrder(id: '', name: ''),
    );

    final customer = activeOrder.customer;
    final totalAmount = activeOrder.total;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Column(
      children: [
        // Row 1: Seller, Channel, Date - Improved layout to prevent overflow
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _buildSellerDropdown(activeOrder.seller)),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildSaleChannelDropdown(activeOrder.saleChannel),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _selectDate,
              padding: const EdgeInsets.all(12.0), // Ensure consistent tap area
              tooltip: 'Chọn ngày',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Customer, Price List
        Row(
          children: [
            Expanded(flex: 5, child: _buildCustomerSearch(customer)),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: _buildPriceListDropdown()),
          ],
        ),

        const Divider(height: 32),

        // Checkout Summary
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSummaryRow(
                'Tổng tiền hàng',
                currencyFormat.format(totalAmount),
              ),
              _buildSummaryRow('Giảm giá', currencyFormat.format(0)),
              const Divider(),
              _buildSummaryRow(
                'Khách cần trả',
                currencyFormat.format(totalAmount),
                isBold: true,
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Khách thanh toán',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow('Tiền thừa trả khách', currencyFormat.format(0)),
            ],
          ),
        ),

        // Action Buttons
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              // TODO: Implement checkout logic
            },
            icon: const Icon(Icons.payment),
            label: const Text('Thanh toán'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSearch(KiotVietCustomer? customer) {
    if (customer != null) {
      return InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.fromLTRB(12, 4, 0, 4),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(customer.name, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                context
                    .read<TemporaryOrderService>()
                    .removeCustomerFromActiveOrder();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    } else {
      return CompositedTransformTarget(
        link: _layerLink,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: const InputDecoration(
            labelText: 'Tìm khách hàng (Tên, SĐT, Mã)',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      );
    }
  }

  Widget _buildSellerDropdown(KiotVietUser? selectedSeller) {
    return FutureBuilder<List<KiotVietUser>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Nhân viên',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Nhân viên bán hàng',
              border: OutlineInputBorder(),
            ),
            child: Text('Lỗi tải nhân viên'),
          );
        }

        final users = snapshot.data!;
        return DropdownButtonFormField<int>(
          initialValue: selectedSeller?.id,
          decoration: const InputDecoration(
            labelText: 'Nhân viên',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          items: users.map((user) {
            return DropdownMenuItem<int>(
              value: user.id,
              child: Text(user.givenName),
            );
          }).toList(),
          onChanged: (userId) {
            final KiotVietUser? seller = (userId == null)
                ? null
                : users.firstWhere((u) => u.id == userId);

            context.read<TemporaryOrderService>().setSellerForActiveOrder(
              seller,
            );
          },
        );
      },
    );
  }

  Widget _buildSaleChannelDropdown(KiotVietSaleChannel? selectedChannel) {
    return FutureBuilder<List<KiotVietSaleChannel>>(
      future: _saleChannelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(border: OutlineInputBorder()),
            child: Icon(Icons.storefront, color: Colors.grey),
          );
        }

        final channels = snapshot.data!;
        return DropdownButtonFormField<int>(
          initialValue: selectedChannel?.id ?? channels.first.id,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          // Hide the label text when an item is selected
          selectedItemBuilder: (context) {
            return channels.map<Widget>((channel) {
              return Center(
                child: FaIcon(getIconFromKiotVietString(channel.img), size: 20),
              );
            }).toList();
          },
          items: channels.map((channel) {
            return DropdownMenuItem<int>(
              value: channel.id,
              child: Row(
                children: [
                  FaIcon(
                    getIconFromKiotVietString(channel.img),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  // Use Expanded to allow the text to wrap or show an ellipsis
                  // if the channel name is too long for the dropdown item.
                  Expanded(
                    child: Text(channel.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (channelId) {
            if (channelId != null) {
              final channel = channels.firstWhere((c) => c.id == channelId);
              context
                  .read<TemporaryOrderService>()
                  .setSaleChannelForActiveOrder(channel);
            }
          },
        );
      },
    );
  }

  Widget _buildPriceListDropdown() {
    // Placeholder data
    return DropdownButtonFormField<int>(
      initialValue: 1,
      decoration: const InputDecoration(
        labelText: 'Bảng giá',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Bảng giá chung')),
        DropdownMenuItem(value: 2, child: Text('Giá bán sỉ')),
      ],
      onChanged: (value) {},
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // TODO: Update date in TemporaryOrder model and service
      });
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    final style = isBold
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
