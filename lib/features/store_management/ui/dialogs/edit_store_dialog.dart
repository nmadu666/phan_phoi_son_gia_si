import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';
import 'package:phan_phoi_son_gia_si/core/services/store_info_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/image_upload_service.dart';
import 'package:provider/provider.dart';

class EditStoreDialog extends StatefulWidget {
  final StoreInfo? store;

  const EditStoreDialog({super.key, this.store});

  @override
  State<EditStoreDialog> createState() => _EditStoreDialogState();
}

class _EditStoreDialogState extends State<EditStoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _hotlineController;
  late TextEditingController _emailController;
  late TextEditingController _logoUrlController;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store?.name ?? '');
    _addressController = TextEditingController(
      text: widget.store?.address ?? '',
    );
    _hotlineController = TextEditingController(
      text: widget.store?.hotline ?? '',
    );
    _emailController = TextEditingController(text: widget.store?.email ?? '');
    _logoUrlController = TextEditingController(
      text: widget.store?.logoUrl ?? '',
    );
    // Thêm listener để cập nhật UI khi URL thay đổi
    _logoUrlController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _hotlineController.dispose();
    _emailController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveStore() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final data = {
        'name': _nameController.text,
        'address': _addressController.text,
        'hotline': _hotlineController.text,
        'email': _emailController.text,
        'logoUrl': _logoUrlController.text,
      };

      try {
        final service = context.read<StoreInfoService>();
        if (widget.store == null) {
          await service.addStore(data);
        } else {
          await service.updateStore(widget.store!.id, data);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUploadLogo() async {
    setState(() => _isUploading = true);
    final uploadService = ImageUploadService();
    try {
      final newUrl = await uploadService.pickAndUploadImage();
      if (newUrl != null && mounted) {
        setState(() {
          _logoUrlController.text = newUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải ảnh lên: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.store == null ? 'Thêm Cửa hàng' : 'Sửa Cửa hàng'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                _nameController,
                'Tên cửa hàng',
                isRequired: true,
              ),
              _buildTextField(_addressController, 'Địa chỉ', isRequired: true),
              _buildTextField(_hotlineController, 'Hotline'),
              _buildTextField(_emailController, 'Email'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildTextField(_logoUrlController, 'URL Logo'),
                  ),
                  const SizedBox(width: 8),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: _handleUploadLogo,
                      tooltip: 'Tải ảnh lên',
                    ),
                ],
              ),
              if (_logoUrlController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.network(
                    _logoUrlController.text,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.error),
                  ),
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
          onPressed: _isLoading ? null : _saveStore,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: isRequired
            ? (value) => (value == null || value.isEmpty)
                  ? 'Vui lòng nhập $label'
                  : null
            : null,
      ),
    );
  }
}
