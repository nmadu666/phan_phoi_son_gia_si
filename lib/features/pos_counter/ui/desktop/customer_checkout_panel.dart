import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_sale_channel.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_price_book.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_price_book_service.dart';
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
  final KiotVietUserService _userService = KiotVietUserService();
  final KiotVietCustomerService _customerService = KiotVietCustomerService();
  final KiotVietSaleChannelService _saleChannelService =
      KiotVietSaleChannelService();
  final KiotVietPriceBookService _priceBookService = KiotVietPriceBookService();

  late Future<List<KiotVietUser>> _usersFuture;
  late Future<List<KiotVietSaleChannel>> _saleChannelsFuture;
  late Future<List<KiotVietPriceBook>> _priceBooksFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _usersFuture = _userService.getUsers();
    _saleChannelsFuture = _saleChannelService.getSaleChannels();
    _priceBooksFuture = _priceBookService.getPriceBooks();
    _setDefaultSeller();
  }

  /// Sets the default seller for the active order based on the logged-in user.
  /// This function is optimized to use async/await for better readability and error handling.
  Future<void> _setDefaultSeller() async {
    // It's a good practice to check if the widget is still mounted before proceeding,
    // especially at the beginning of an async method called from initState.
    if (!mounted) return;

    // Read all necessary services from the context before any async operations.
    // This avoids using the context after an `await` gap.
    final authService = context.read<AuthService>();
    final orderService = context.read<TemporaryOrderService>();
    final appUserService = context.read<AppUserService>();

    final currentUser = authService.currentUser;
    final activeOrder = orderService.activeOrder;

    // Proceed only if there's a logged-in user, an active order, and no seller is set yet.
    if (currentUser == null ||
        activeOrder == null ||
        activeOrder.seller != null) {
      return;
    }

    try {
      final appUser = await appUserService.getUser(currentUser.uid);
      if (appUser?.kiotvietUserRef == null) return;

      final defaultSeller = await appUserService.getUserFromRef(
        appUser!.kiotvietUserRef!,
      );

      // Final check for `mounted` before updating the state.
      if (mounted) {
        orderService.setSellerForActiveOrder(defaultSeller);
      }
    } catch (e) {
      // Log the error for debugging purposes.
      debugPrint('Failed to set default seller: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<TemporaryOrderService>();
    final activeOrder =
        orderService.activeOrder ?? TemporaryOrder(id: '', name: '');

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
            Expanded(
              flex: 4,
              child: _buildPriceListDropdown(activeOrder.priceBookId),
            ),
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
    // Always use the Autocomplete widget, but pass the initial customer value.
    // The Autocomplete widget will handle its own display logic.
    return Row(
      children: [
        Expanded(
          child: _CustomerAutocomplete(
            initialValue: customer,
            customerService: _customerService,
            onCustomerSelected: (selectedCustomer) {
              context.read<TemporaryOrderService>().setCustomerForActiveOrder(
                selectedCustomer,
              );
            },
            onCustomerRemoved: () {
              // The text field is cleared, which triggers the parent to rebuild
              // with a null customer, effectively removing them.
              context
                  .read<TemporaryOrderService>()
                  .removeCustomerFromActiveOrder();
            },
            onCreateNewCustomer: (name) {
              _showCreateCustomerDialog(name);
            },
          ),
        ),
      ],
    );
  }

  /// Hiển thị dialog để tạo khách hàng mới.
  void _showCreateCustomerDialog(
    String initialName, // Nhận service như một tham số
  ) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    // Sử dụng ValueNotifier để quản lý trạng thái loading của nút Lưu
    final isLoading = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tạo khách hàng mới'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên khách hàng *',
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Vui lòng nhập tên'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Địa chỉ'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            // Sử dụng ValueListenableBuilder để rebuild nút khi trạng thái loading thay đổi
            ValueListenableBuilder<bool>(
              valueListenable: isLoading,
              builder: (context, loading, child) {
                return FilledButton(
                  onPressed: loading
                      ? null // Vô hiệu hóa nút khi đang tải
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          isLoading.value = true;

                          // Lấy các service cần thiết một cách an toàn
                          final customerService = dialogContext
                              .read<KiotVietCustomerService>();
                          final orderService = dialogContext
                              .read<TemporaryOrderService>();
                          final appState = dialogContext
                              .read<AppStateService>();
                          final branchId = appState.get<int>(
                            AppStateService.selectedBranchIdKey,
                          );

                          if (branchId == null) {
                            // Xử lý lỗi nếu không có chi nhánh nào được chọn
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lỗi: Chưa chọn chi nhánh.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            isLoading.value = false;
                            return;
                          }

                          try {
                            // Gọi service để tạo khách hàng trên Firestore
                            final newCustomer = await customerService
                                .createCustomer(
                                  name: nameController.text,
                                  contactNumber: phoneController.text,
                                  address: addressController.text,
                                  branchId: branchId,
                                );

                            // Đóng dialog sau khi hoàn tất
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            // CRITICAL: Update the order state AFTER the dialog has been popped
                            // to prevent the disposed EngineFlutterView error.
                            // Using a post-frame callback is the safest way.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              orderService.setCustomerForActiveOrder(
                                newCustomer,
                              );
                            });
                          } catch (e) {
                            // Xử lý lỗi nếu có
                            // Check if the original context for the panel is still mounted
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tạo khách hàng thất bại: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            // Luôn đảm bảo tắt trạng thái loading
                            // Check if the dialog's context is still mounted
                            if (dialogContext.mounted) {
                              isLoading.value = false;
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lưu'),
                );
              },
            ),
          ],
        );
      },
    );
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
        final defaultChannel =
            selectedChannel ??
            channels.firstWhere(
              (c) => c.name.contains('Tại cửa hàng'),
              orElse: () => channels.first,
            );
        return DropdownButtonFormField<int>(
          initialValue: defaultChannel.id,
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

  Widget _buildPriceListDropdown(int? selectedPriceBookId) {
    return FutureBuilder<List<KiotVietPriceBook>>(
      future: _priceBooksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Bảng giá',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Lỗi tải bảng giá');
        }

        final priceBooks = List<KiotVietPriceBook>.from(snapshot.data ?? []);

        // Ensure "Bảng giá chung" (id: 0) always exists in the list.
        if (!priceBooks.any((pb) => pb.id == 0)) {
          priceBooks.insert(
            0,
            const KiotVietPriceBook(
              id: 0,
              name: 'Bảng giá chung',
              isActive: true, // Assume it's always usable
              isGlobal: true,
            ),
          );
        }

        if (priceBooks.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Bảng giá',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('Không có bảng giá'),
          );
        }

        // Determine the initial value, ensuring it exists in the list.
        int? initialValue = selectedPriceBookId;
        final bool valueExists = priceBooks.any((pb) => pb.id == initialValue);

        if (initialValue == null || !valueExists) {
          // Default to general price book (id: 0) if available, otherwise the first item.
          initialValue = priceBooks.any((pb) => pb.id == 0)
              ? 0
              : priceBooks.first.id;
        }

        return DropdownButtonFormField<int>(
          isExpanded: true, // Tránh lỗi overflow khi tên bảng giá quá dài
          initialValue: initialValue,
          decoration: const InputDecoration(
            labelText: 'Bảng giá',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          items: priceBooks.map((pb) {
            return DropdownMenuItem(
              value: pb.id,
              child: Text(pb.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            context.read<TemporaryOrderService>().setPriceBookForActiveOrder(
              value,
            );
          },
        );
      },
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

/// A dedicated, stateful widget to handle the customer search autocomplete logic.
/// This encapsulates debouncing and state management for search results,
/// optimizing performance by reducing Firestore reads.
/// It now also handles its own display state (showing selected customer vs. search).
class _CustomerAutocomplete extends StatefulWidget {
  final KiotVietCustomer? initialValue;
  final KiotVietCustomerService customerService;
  final ValueChanged<KiotVietCustomer> onCustomerSelected;
  final VoidCallback onCustomerRemoved;
  final ValueChanged<String> onCreateNewCustomer;

  const _CustomerAutocomplete({
    this.initialValue,
    required this.customerService,
    required this.onCustomerSelected,
    required this.onCreateNewCustomer,
    required this.onCustomerRemoved,
  });

  @override
  State<_CustomerAutocomplete> createState() => __CustomerAutocompleteState();
}

class __CustomerAutocompleteState extends State<_CustomerAutocomplete> {
  Timer? _debounce;
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _suggestionsScrollController = ScrollController();

  // State for pagination and loading
  List<KiotVietCustomer> _searchResults = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _isLazyLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Add a listener to rebuild the options view when text changes,
    // which is necessary to show/hide the "Create New" button.
    _textEditingController.addListener(() => setState(() {}));
    _updateControllerWithInitialValue();
    _suggestionsScrollController.addListener(_onSuggestionsScroll);
  }

  @override
  void didUpdateWidget(covariant _CustomerAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent widget passes a different customer (or null),
    // update the text field to reflect the change.
    if (widget.initialValue != oldWidget.initialValue) {
      _updateControllerWithInitialValue();
    }
  }

  void _updateControllerWithInitialValue() {
    _textEditingController.text = widget.initialValue?.name ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textEditingController.dispose();
    _focusNode.dispose();
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  void _onSuggestionsScroll() {
    if (_suggestionsScrollController.position.pixels ==
            _suggestionsScrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLazyLoading) {
      _fetchMoreData(_textEditingController.text);
    }
  }

  Future<void> _fetchInitialData(String query) async {
    if (_isLoading) return;

    // Get services and state from context BEFORE the async gap.
    final appState = context.read<AppStateService>();
    final authService = context.read<AuthService>();
    final appUserService = context.read<AppUserService>();

    final branchId = appState.get<int>(AppStateService.selectedBranchIdKey);

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _lastDocument = null;
      _hasMore = true;
      _error = null;
    });

    try {
      final appUser = authService.currentUser != null
          ? await appUserService.getUser(authService.currentUser!.uid)
          : null;

      final result = await widget.customerService.searchCustomers(
        query,
        currentUser: appUser,
        branchId: branchId,
      );

      if (!mounted) return;

      final newCustomers = result['customers'] as List<KiotVietCustomer>;
      final lastDoc = result['lastDoc'] as DocumentSnapshot?;

      setState(() {
        _searchResults = newCustomers;
        _lastDocument = lastDoc;
        _hasMore = newCustomers.length == 15; // Assuming limit is 15
      });
    } catch (e) {
      debugPrint('Failed to search customers: $e');
      if (mounted) {
        setState(() => _error = 'Lỗi tải dữ liệu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreData(String query) async {
    if (_isLazyLoading || !_hasMore || _lastDocument == null) return;

    setState(() => _isLazyLoading = true);

    try {
      final appState = context.read<AppStateService>();
      final authService = context.read<AuthService>();
      final appUserService = context.read<AppUserService>();
      final branchId = appState.get<int>(AppStateService.selectedBranchIdKey);
      final appUser = authService.currentUser != null
          ? await appUserService.getUser(authService.currentUser!.uid)
          : null;

      final result = await widget.customerService.searchCustomers(
        query,
        currentUser: appUser,
        branchId: branchId,
        lastDoc: _lastDocument,
      );

      if (!mounted) return;

      final moreCustomers = result['customers'] as List<KiotVietCustomer>;
      final lastDoc = result['lastDoc'] as DocumentSnapshot?;

      setState(() {
        _searchResults.addAll(moreCustomers);
        _lastDocument = lastDoc;
        _hasMore = moreCustomers.length == 15;
      });
    } catch (e) {
      debugPrint('Error fetching more customers: $e');
      if (mounted) {
        setState(() => _error = 'Lỗi tải thêm dữ liệu.');
      }
    } finally {
      if (mounted) setState(() => _isLazyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<KiotVietCustomer>(
      textEditingController: _textEditingController,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        // When the text field is cleared, schedule a state update for after the build.
        if (textEditingValue.text.isEmpty) {
          if (_isLoading || _error != null || _searchResults.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _searchResults.clear();
                _isLoading = false;
                _error = null;
              });
            });
          }
          return const Iterable<KiotVietCustomer>.empty();
        }

        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          _fetchInitialData(textEditingValue.text);
        });

        return _searchResults;
      },
      onSelected: (selection) {
        // Use a post-frame callback for maximum safety when updating state
        // after an overlay (from Autocomplete) has been dismissed.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onCustomerSelected(selection);
          // After selection, unfocus to hide the keyboard and options view.
          // The text field will be updated by didUpdateWidget.
          _focusNode.unfocus();
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        final RenderBox? fieldBox = context.findRenderObject() as RenderBox?;
        final double fieldWidth = fieldBox?.size.width ?? 300;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: SizedBox(
              width: fieldWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              // Manually trigger a search retry
                              final currentText = _textEditingController.text;
                              _textEditingController.clear();
                              // Use a post-frame callback to safely update the controller
                              // and trigger a new search.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _textEditingController.text = currentText;
                              });
                            },
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  else if (options.isEmpty &&
                      _textEditingController.text.isNotEmpty &&
                      !_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Không tìm thấy khách hàng nào.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        controller: _suggestionsScrollController,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
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
                          return _buildCustomerOptionTile(
                            _searchResults[index],
                            onSelected,
                          );
                        },
                      ),
                    ),
                  // Always show "Create new" button if there's text, regardless of loading state.
                  if (_textEditingController.text.isNotEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.green,
                      ),
                      title: Text(
                        'Tạo mới khách hàng "${_textEditingController.text}"',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.green,
                        ),
                      ),
                      onTap: () {
                        final newName = _textEditingController.text;
                        // Unfocus and clear to reset the UI state, then
                        // call the callback to create the new customer.
                        _focusNode.unfocus();
                        _textEditingController.clear();
                        widget.onCreateNewCustomer(newName);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            final bool hasCustomer = widget.initialValue != null;

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              readOnly: hasCustomer,
              decoration: InputDecoration(
                labelText: 'Tìm khách hàng (Tên, SĐT, Mã)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(hasCustomer ? Icons.person : Icons.search),
                suffixIcon: hasCustomer
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // Clear the text field and notify the parent to remove the customer.
                          textEditingController.clear();
                          widget.onCustomerRemoved();
                        },
                      )
                    : null,
              ),
              onTap: () {
                if (hasCustomer) {
                  // If a customer is already selected, tapping the field should
                  // clear it and prepare for a new search.
                  textEditingController.clear();
                  focusNode.requestFocus();
                }
              },
            );
          },
    );
  }

  /// Widget để hiển thị một khách hàng trong danh sách gợi ý.
  Widget _buildCustomerOptionTile(
    KiotVietCustomer option,
    AutocompleteOnSelected<KiotVietCustomer> onSelected,
  ) {
    return InkWell(
      onTap: () => onSelected(option),
      child: ListTile(
        title: Text(option.name),
        subtitle: Text(
          'Mã: ${option.code} - SĐT: ${option.contactNumber ?? 'N/A'}',
        ),
      ),
    );
  }
}
