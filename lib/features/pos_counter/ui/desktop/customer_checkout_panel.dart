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
            // Guard against calling on a disposed widget.
            if (mounted) {
              orderService.setSellerForActiveOrder(defaultSeller);
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
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
      return Autocomplete<KiotVietCustomer>(
        // Hàm này trả về chuỗi để hiển thị trong TextField sau khi chọn.
        displayStringForOption: (KiotVietCustomer option) => option.name,
        optionsBuilder: (TextEditingValue textEditingValue) async {
          if (textEditingValue.text.isEmpty) {
            // Trả về một Future hoàn thành ở frame tiếp theo.
            // Điều này ngăn Autocomplete đóng overlay ngay lập tức,
            // cho phép onSelected có thời gian rebuild widget trước.
            return Future.value(const Iterable<KiotVietCustomer>.empty());
          }
          // Lấy các service và giá trị cần thiết từ context TRƯỚC async gap.
          final appState = context.read<AppStateService>();
          final authService = context.read<AuthService>();
          final appUserService = context.read<AppUserService>();

          // Sử dụng các biến đã lấy, không dùng context sau await.
          final branchId = appState.get<int>(
            AppStateService.selectedBranchIdKey,
          );
          final appUser = authService.currentUser != null
              ? await appUserService.getUser(authService.currentUser!.uid)
              : null;

          final Map<String, dynamic> result = await _customerService
              .searchCustomers(
                textEditingValue.text,
                currentUser: appUser,
                branchId: branchId,
              );
          final customers = result['customers'] as List<KiotVietCustomer>;

          // Nếu không tìm thấy khách hàng, thêm tùy chọn "Tạo mới"
          if (textEditingValue.text.isNotEmpty && customers.isEmpty) {
            return [
              KiotVietCustomer(
                id: -1, // ID đặc biệt để nhận biết hành động tạo mới
                code: 'CREATE_NEW',
                name: 'Tạo mới khách hàng "${textEditingValue.text}"',
              ),
            ];
          }

          return customers;
        },
        // Hàm này được gọi khi người dùng chọn một khách hàng từ danh sách.
        onSelected: (KiotVietCustomer selection) {
          // Lấy service ra trước để tránh sử dụng context sau async gap.
          final orderService = context.read<TemporaryOrderService>();

          if (selection.id == -1) {
            // Xử lý tạo khách hàng mới
            _showCreateCustomerDialog(
              selection.name
                  .replaceAll('Tạo mới khách hàng "', '')
                  .replaceAll('"', ''),
              orderService, // Truyền service vào hàm
            );
          } else {
            // Xử lý chọn khách hàng bình thường
            Future.delayed(Duration.zero, () {
              orderService.setCustomerForActiveOrder(selection);
            });
          }
        },
        // Tùy chỉnh giao diện cho danh sách gợi ý
        optionsViewBuilder: (context, onSelected, options) {
          // Lấy RenderBox của TextField để xác định chiều rộng cho danh sách gợi ý
          final RenderBox? fieldBox = context.findRenderObject() as RenderBox?;
          final double fieldWidth =
              fieldBox?.size.width ?? 300; // Giá trị mặc định

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              child: SizedBox(
                width:
                    fieldWidth, // Đặt chiều rộng bằng với chiều rộng của TextField
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final KiotVietCustomer option = options.elementAt(index);
                    return _buildCustomerOptionTile(option, onSelected);
                  },
                ),
              ),
            ),
          );
        },
        // Tùy chỉnh giao diện cho TextField
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Tìm khách hàng (Tên, SĐT, Mã)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
      );
    }
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

  /// Hiển thị dialog để tạo khách hàng mới.
  void _showCreateCustomerDialog(
    String initialName,
    TemporaryOrderService orderService, // Nhận service như một tham số
  ) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

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
            FilledButton(
              onPressed: () async {
                // Chỉ thực hiện nếu form hợp lệ
                if (!formKey.currentState!.validate()) {
                  return;
                }

                // 1. Đóng dialog ngay lập tức để giao diện người dùng phản hồi.
                Navigator.of(dialogContext).pop();

                // 2. Trì hoãn việc tạo và gán khách hàng để Autocomplete có thời gian đóng overlay.
                Future.delayed(Duration.zero, () {
                  // Linter không cảnh báo vì orderService đã được truyền vào
                  // Tạo một khách hàng tạm thời với ID duy nhất (sử dụng uuid)
                  // và các thông tin người dùng đã nhập.
                  final newCustomer = KiotVietCustomer(
                    id: -2, // ID đặc biệt cho khách hàng tạm, chưa có trên KiotViet
                    code: const Uuid().v4(), // Dùng UUID làm mã tạm thời
                    name: nameController.text,
                    contactNumber: phoneController.text,
                    address: addressController.text,
                  );

                  // Gán khách hàng tạm này vào đơn hàng hiện tại
                  orderService.setCustomerForActiveOrder(newCustomer);
                });
              },
              child: const Text('Lưu'),
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
