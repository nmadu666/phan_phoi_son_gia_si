import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
  final KiotVietUserService _userService = KiotVietUserService();
  final KiotVietCustomerService _customerService = KiotVietCustomerService();
  final KiotVietSaleChannelService _saleChannelService =
      KiotVietSaleChannelService();

  late Future<List<KiotVietUser>> _usersFuture;
  late Future<List<KiotVietSaleChannel>> _saleChannelsFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _usersFuture = _userService.getUsers();
    _saleChannelsFuture = _saleChannelService.getSaleChannels();
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
      return _CustomerAutocomplete(
        customerService: _customerService,
        onCustomerSelected: (customer) {
          // Use a post-frame callback for maximum safety when updating state
          // after an overlay (from Autocomplete) has been dismissed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<TemporaryOrderService>().setCustomerForActiveOrder(customer);
          });
        },
        onCreateNewCustomer: (name) {
          // The dialog is also an overlay, so a delay is safest.
          Future.delayed(Duration.zero, () {
            _showCreateCustomerDialog(name);
          });
        },
      );
    }
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
                              orderService.setCustomerForActiveOrder(newCustomer);
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

/// A dedicated, stateful widget to handle the customer search autocomplete logic.
/// This encapsulates debouncing and state management for search results,
/// optimizing performance by reducing Firestore reads.
class _CustomerAutocomplete extends StatefulWidget {
  final KiotVietCustomerService customerService;
  final ValueChanged<KiotVietCustomer> onCustomerSelected;
  final ValueChanged<String> onCreateNewCustomer;

  const _CustomerAutocomplete({
    required this.customerService,
    required this.onCustomerSelected,
    required this.onCreateNewCustomer,
  });

  @override
  State<_CustomerAutocomplete> createState() => __CustomerAutocompleteState();
}

class __CustomerAutocompleteState extends State<_CustomerAutocomplete> {
  Timer? _debounce;
  // We manage the search results in the state of this widget.
  Iterable<KiotVietCustomer> _lastOptions = const Iterable.empty();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<Iterable<KiotVietCustomer>> _search(String query) async {
    if (!mounted) return const Iterable.empty();

    // Get services and state from context BEFORE the async gap.
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
    );

    final customers = result['customers'] as List<KiotVietCustomer>;

    // If no customers are found, add the "Create New" option.
    if (query.isNotEmpty && customers.isEmpty) {
      return [
        KiotVietCustomer(
          id: -1,
          code: 'CREATE_NEW',
          name: 'Tạo mới khách hàng "$query"',
        ),
      ];
    }

    return customers;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<KiotVietCustomer>(
      displayStringForOption: (option) => option.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<KiotVietCustomer>.empty();
        }

        // Debounce logic
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        final completer = Completer<Iterable<KiotVietCustomer>>();
        _debounce = Timer(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          final options = await _search(textEditingValue.text);
          _lastOptions = options; // Cache the results
          if (!completer.isCompleted) {
            completer.complete(options);
          }
        });

        // While waiting for the debounce timer, return the last known results
        // to prevent the options view from flickering or disappearing.
        return _lastOptions;
      },
      onSelected: (selection) {
        if (selection.id == -1) {
          widget.onCreateNewCustomer(
            selection.name
                .replaceAll('Tạo mới khách hàng "', '')
                .replaceAll('"', ''),
          );
        } else {
          widget.onCustomerSelected(selection);
        }
      },
      optionsViewBuilder: (context, onSelected, options) {
        final RenderBox? fieldBox = context.findRenderObject() as RenderBox?;
        final double fieldWidth = fieldBox?.size.width ?? 300;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              width: fieldWidth,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return _buildCustomerOptionTile(option, onSelected);
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Tìm khách hàng (Tên, SĐT, Mã)',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSubmitted(),
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
        // Nếu là tùy chọn "Tạo mới", hiển thị icon và style khác
        leading: option.id == -1
            ? const Icon(Icons.add_circle_outline, color: Colors.green)
            : null,
        title: Text(
          option.name,
          style: option.id == -1
              ? const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.green,
                )
              : null,
        ),
        subtitle: Text(
          // Không hiển thị subtitle cho tùy chọn "Tạo mới"
          option.id == -1
              ? 'Nhấn để thêm khách hàng mới vào hệ thống'
              : 'Mã: ${option.code} - SĐT: ${option.contactNumber ?? 'N/A'}',
        ),
      ),
    );
  }
}
