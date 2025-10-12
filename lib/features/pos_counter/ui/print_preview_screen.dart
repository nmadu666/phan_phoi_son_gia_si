import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/store_info_service.dart';
import 'package:phan_phoi_son_gia_si/core/utils/receipt_printer_service.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class PrintPreviewScreen extends StatefulWidget {
  final TemporaryOrder order;

  const PrintPreviewScreen({super.key, required this.order});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  late StoreInfo _selectedStore;
  late TextEditingController _titleController;
  final ReceiptPrinterService _printerService = ReceiptPrinterService();

  @override
  void initState() {
    super.initState();
    final storeService = context.read<StoreInfoService>();
    _selectedStore = storeService.defaultStore;
    _titleController = TextEditingController(text: 'HÓA ĐƠN BÁN HÀNG');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeService = context.watch<StoreInfoService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Xem trước và Tùy chỉnh In')),
      body: Row(
        children: [
          // Cột tùy chỉnh
          Container(
            width: 300,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tùy chọn in',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                // Dropdown chọn cửa hàng
                DropdownButtonFormField<StoreInfo>(
                  // Đảm bảo giá trị value luôn tồn tại trong danh sách items
                  initialValue:
                      storeService.stores.any((s) => s.id == _selectedStore.id)
                      ? _selectedStore
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Chọn cửa hàng/công ty',
                    border: OutlineInputBorder(),
                  ),
                  items: storeService.stores.map((store) {
                    return DropdownMenuItem<StoreInfo>(
                      value: store,
                      child: Text(store.name),
                    );
                  }).toList(),
                  onChanged: (StoreInfo? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStore = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // TextField chỉnh sửa tiêu đề
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề hóa đơn',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // Trigger rebuild của PdfPreview khi người dùng gõ
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          // Phần xem trước PDF
          Expanded(
            child: PdfPreview(
              // Sử dụng key để buộc PdfPreview build lại khi state thay đổi
              key: ValueKey('${_selectedStore.name}_${_titleController.text}'),
              build: (format) => _generatePdf(format),
              canChangePageFormat: true,
              canChangeOrientation: true,
              canDebug: false,
            ),
          ),
        ],
      ),
    );
  }

  /// Tạo file PDF dựa trên các tùy chọn hiện tại
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = await _printerService.generatePdfDocument(
      widget.order,
      _selectedStore,
      title: _titleController.text,
      pageFormat: format, // Truyền khổ giấy từ PdfPreview
    );
    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }
}
