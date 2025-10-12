import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_customer_service.dart';
import 'package:provider/provider.dart';

/// Một dialog độc lập để tạo khách hàng mới.
///
/// Widget này tự quản lý trạng thái form và logic gọi API.
/// Khi tạo thành công, nó sẽ gọi callback `onCustomerCreated`.
class CreateCustomerDialog extends StatefulWidget {
  final String initialName;
  final ValueChanged<KiotVietCustomer> onCustomerCreated;

  const CreateCustomerDialog({
    super.key,
    required this.initialName,
    required this.onCustomerCreated,
  });

  @override
  State<CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    // 1. Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // 2. Lấy các service cần thiết từ context
    final customerService = context.read<KiotVietCustomerService>();
    final appState = context.read<AppStateService>();
    final branchId = appState.get<int>(AppStateService.selectedBranchIdKey);

    if (branchId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Chưa chọn chi nhánh.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 3. Gọi service để tạo khách hàng
      final newCustomer = await customerService.createCustomer(
        name: _nameController.text,
        contactNumber: _phoneController.text,
        address: _addressController.text,
        branchId: branchId,
      );

      // 4. Gọi callback để thông báo cho widget cha và đóng dialog
      if (mounted) {
        widget.onCustomerCreated(newCustomer);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tạo khách hàng thất bại: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo khách hàng mới'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên khách hàng *',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Vui lòng nhập tên'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveCustomer,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
