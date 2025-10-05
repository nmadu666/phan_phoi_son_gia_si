import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/pos_settings.dart';
import 'package:phan_phoi_son_gia_si/core/services/pos_settings_service.dart';
import 'package:provider/provider.dart';

class PosSettingsDialog extends StatefulWidget {
  const PosSettingsDialog({super.key});

  @override
  State<PosSettingsDialog> createState() => _PosSettingsDialogState();
}

class _PosSettingsDialogState extends State<PosSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PosSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize local state with current settings from the service
    _currentSettings = context.read<PosSettingsService>().settings;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.read<PosSettingsService>();

    return AlertDialog(
      title: const Text('Tùy chỉnh hiển thị'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Hiển thị'),
                Tab(text: 'Khác'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDisplayTab(),
                  _buildOtherTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            settingsService.updateSettings(_currentSettings);
            Navigator.of(context).pop();
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  Widget _buildDisplayTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSwitchTile(
          'Số thứ tự',
          _currentSettings.showLineNumber,
          (val) => _currentSettings = _currentSettings.copyWith(showLineNumber: val),
        ),
        _buildSwitchTile(
          'Mã hàng',
          _currentSettings.showProductCode,
          (val) => _currentSettings = _currentSettings.copyWith(showProductCode: val),
        ),
        _buildSwitchTile(
          'Đơn vị tính',
          _currentSettings.showUnit,
          (val) => _currentSettings = _currentSettings.copyWith(showUnit: val),
        ),
        _buildSwitchTile(
          'Giá bán',
          _currentSettings.showSellingPrice,
          (val) => _currentSettings = _currentSettings.copyWith(showSellingPrice: val),
        ),
        _buildSwitchTile(
          'Giảm giá (VND/%)',
          _currentSettings.showDiscount,
          (val) => _currentSettings = _currentSettings.copyWith(showDiscount: val),
        ),
        _buildSwitchTile(
          'Thành tiền',
          _currentSettings.showLineTotal,
          (val) => _currentSettings = _currentSettings.copyWith(showLineTotal: val),
        ),
        _buildSwitchTile(
          'Chỉnh sửa thành tiền',
          _currentSettings.allowEditLineTotal,
          (val) => _currentSettings = _currentSettings.copyWith(allowEditLineTotal: val),
        ),
        _buildSwitchTile(
          'Xem giá bán gần nhất',
          _currentSettings.showLastPrice,
          (val) => _currentSettings = _currentSettings.copyWith(showLastPrice: val),
        ),
        _buildSwitchTile(
          'Gợi ý thanh toán',
          _currentSettings.showPaymentSuggestion,
          (val) => _currentSettings = _currentSettings.copyWith(showPaymentSuggestion: val),
        ),
      ],
    );
  }

  Widget _buildOtherTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSwitchTile(
          'Hiển thị tồn kho',
          _currentSettings.showInventory,
          (val) => _currentSettings = _currentSettings.copyWith(showInventory: val),
        ),
        _buildSwitchTile(
          'Kéo thả hàng hoá',
          _currentSettings.allowDragAndDrop,
          (val) => _currentSettings = _currentSettings.copyWith(allowDragAndDrop: val),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (newValue) {
        setState(() {
          onChanged(newValue);
        });
      },
    );
  }
}
