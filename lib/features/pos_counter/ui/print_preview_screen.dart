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
  // TÍNH NĂNG MỚI: State để quản lý khổ giấy được chọn
  late PdfPageFormat _selectedPageFormat;

  // Định nghĩa các khổ giấy có sẵn
  final Map<String, PdfPageFormat> _pageFormats = {
    'A4': PdfPageFormat.a4,
    'A5': PdfPageFormat.a5,
    'Hóa đơn 80mm': PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
  };

  @override
  void initState() {
    super.initState();
    final storeService = context.read<StoreInfoService>();
    _selectedStore = storeService.defaultStore;
    _titleController = TextEditingController(text: 'HÓA ĐƠN BÁN HÀNG');
    _selectedPageFormat = _pageFormats['A4']!; // Mặc định là A4
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
                  initialValue:
                      storeService.stores.any((s) => s.id == _selectedStore.id)
                      ? _selectedStore
                      : null,
                  isExpanded: true, // Cho phép item trong dropdown mở rộng
                  decoration: const InputDecoration(
                    labelText: 'Chọn cửa hàng/công ty',
                    border: OutlineInputBorder(),
                  ),
                  items: storeService.stores.map((store) {
                    return DropdownMenuItem<StoreInfo>(
                      value: store,
                      // TỐI ƯU: Xử lý tên cửa hàng dài để tránh lỗi overflow
                      child: Text(store.name, overflow: TextOverflow.ellipsis),
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
                // TÍNH NĂNG MỚI: Dropdown chọn khổ giấy
                DropdownButtonFormField<PdfPageFormat>(
                  initialValue: _selectedPageFormat,
                  decoration: const InputDecoration(
                    labelText: 'Chọn khổ giấy',
                    border: OutlineInputBorder(),
                  ),
                  items: _pageFormats.entries.map((entry) {
                    return DropdownMenuItem<PdfPageFormat>(
                      value: entry.value,
                      child: Text(entry.key),
                    );
                  }).toList(),
                  onChanged: (PdfPageFormat? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPageFormat = newValue;
                        // Việc thay đổi key của PdfPreview sẽ buộc nó build lại
                        // với khổ giấy mới.
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
              key: ValueKey(
                '${_selectedStore.id}_${_titleController.text}_${_selectedPageFormat.width}',
              ),
              build: (format) => _generatePdf(_selectedPageFormat),
              canChangePageFormat:
                  false, // Tắt tùy chọn của thư viện, dùng của mình
              canChangeOrientation: false, // Tắt tùy chọn của thư viện
              canDebug: false,
            ),
          ),
        ],
      ),
    );
  }

  /// Tạo file PDF dựa trên các tùy chọn hiện tại
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final printerService = context.read<ReceiptPrinterService>();
    final doc = await printerService.generatePdfDocument(
      widget.order,
      _selectedStore,
      title: _titleController.text,
      pageFormat: format, // Truyền khổ giấy từ PdfPreview
    );
    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }
}
