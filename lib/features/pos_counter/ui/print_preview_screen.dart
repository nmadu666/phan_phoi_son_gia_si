import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:phan_phoi_son_gia_si/core/services/google_api_service.dart';
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

/// Enum cho các tùy chọn canh lề đặt trước
enum MarginPreset {
  normal('Mặc định', 15.0),
  minimal('Tối thiểu', 5.0),
  none('Không lề', 0.0),
  custom('Tùy chỉnh', -1);

  const MarginPreset(this.label, this.value);
  final String label;
  final double value; // in mm
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  late StoreInfo _selectedStore;
  late TextEditingController _titleController;
  // TÍNH NĂNG MỚI: State để quản lý khổ giấy được chọn
  late PdfPageFormat _selectedPageFormat;
  // TÍNH NĂNG MỚI: Controllers cho việc canh lề
  late TextEditingController _marginTopController;
  late TextEditingController _marginBottomController;
  late TextEditingController _marginLeftController;
  late TextEditingController _marginRightController;
  // TÍNH NĂNG MỚI: State cho tùy chọn lề và tỷ lệ
  MarginPreset _selectedMarginPreset =
      MarginPreset.minimal; // Đổi mặc định sang Tối thiểu
  double _scaleFactor = 0.8; // Đổi mặc định sang 80%

  // TÍNH NĂNG MỚI: State cho Google Docs
  bool _isProcessingGoogleDocs = false;
  String? _googleDocId;
  String? _processingError;

  late final GoogleApiService _googleApiService;

  // Định nghĩa các khổ giấy có sẵn
  final Map<String, PdfPageFormat> _pageFormats = {
    'A4': PdfPageFormat.a4,
    'A5': PdfPageFormat.a5,
    'Hóa đơn 80mm': PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
  };

  // TÍNH NĂNG MỚI: Danh sách các mẫu tiêu đề hóa đơn
  final List<String> _invoiceTitles = [
    'HÓA ĐƠN BÁN HÀNG',
    'BÁO GIÁ KHÁCH HÀNG',
  ];

  @override
  void initState() {
    super.initState();
    final storeService = context.read<StoreInfoService>();
    _selectedStore = storeService.defaultStore;
    _titleController = TextEditingController(text: 'HÓA ĐƠN BÁN HÀNG');
    _googleApiService = context.read<GoogleApiService>();
    _selectedPageFormat = _pageFormats['A4']!; // Mặc định là A4

    // Khởi tạo giá trị mặc định cho lề theo preset đã chọn (Tối thiểu - 5mm)
    _marginTopController = TextEditingController(
      text: _selectedMarginPreset.value.toStringAsFixed(0),
    );
    _marginBottomController = TextEditingController(
      text: _selectedMarginPreset.value.toStringAsFixed(0),
    );
    _marginLeftController = TextEditingController(
      text: _selectedMarginPreset.value.toStringAsFixed(0),
    );
    _marginRightController = TextEditingController(
      text: _selectedMarginPreset.value.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _marginTopController.dispose();
    _marginBottomController.dispose();
    _marginLeftController.dispose();
    _marginRightController.dispose();
    super.dispose();
  }

  void _updateMarginControllers(MarginPreset preset) {
    if (preset == MarginPreset.custom) {
      // Không làm gì khi người dùng chọn Tùy chỉnh, giữ nguyên giá trị họ đã nhập
      return;
    }
    final value = preset.value.toStringAsFixed(0);
    setState(() {
      _selectedMarginPreset = preset;
      _marginTopController.text = value;
      _marginBottomController.text = value;
      _marginLeftController.text = value;
      _marginRightController.text = value;
    });
  }

  /// TÍNH NĂNG MỚI: Xử lý luồng tạo và mở Google Docs
  Future<void> _handleEditWithGoogleDocs() async {
    setState(() {
      _isProcessingGoogleDocs = true;
      _processingError = null;
      _googleDocId = null;
    });

    try {
      // 1. Xác thực nếu cần
      if (!_googleApiService.isAuthenticated) {
        final authenticated = await _googleApiService.authenticate();
        if (!authenticated) {
          throw Exception('Xác thực Google thất bại.');
        }
      }

      // 2. Tạo nội dung HTML
      final htmlContent = context.read<ReceiptPrinterService>().generateHtml(
            widget.order,
            _selectedStore,
            _titleController.text,
          );

      // 3. Tạo Google Doc từ HTML
      final docId = await _googleApiService.createDocumentFromHtml(
          htmlContent, _titleController.text);

      if (docId == null) {
        throw Exception('Không thể tạo file Google Docs.');
      }

      setState(() {
        _googleDocId = docId;
      });

      // 4. Mở file để chỉnh sửa
      await _googleApiService.openDocumentForEditing(docId);
    } catch (e) {
      setState(() => _processingError = e.toString());
    } finally {
      setState(() => _isProcessingGoogleDocs = false);
    }
  }

  /// TÍNH NĂNG MỚI: Xử lý luồng xuất PDF và in
  Future<void> _handlePrintFromGoogleDocs() async {
    if (_googleDocId == null) return;
    setState(() => _isProcessingGoogleDocs = true);
    try {
      final pdfBytes = await _googleApiService.exportDocumentAsPdf(_googleDocId!);
      if (pdfBytes != null) {
        await Printing.layoutPdf(onLayout: (_) => pdfBytes);
      }
    } finally {
      setState(() => _isProcessingGoogleDocs = false);
    }
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
                // TÍNH NĂNG MỚI: Autocomplete cho phép chọn hoặc nhập tiêu đề
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _titleController.text),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _invoiceTitles;
                    }
                    return _invoiceTitles.where((String option) {
                      return option.contains(
                        textEditingValue.text.toUpperCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _titleController.text = selection;
                    });
                  },
                  fieldViewBuilder:
                      (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Đồng bộ controller của Autocomplete với _titleController
                        _titleController.value = textEditingController.value;
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Tiêu đề hóa đơn',
                            border: OutlineInputBorder(),
                          ),
                          inputFormatters: [UpperCaseTextFormatter()],
                          onChanged: (value) => setState(() {}),
                        );
                      },
                ),
                const SizedBox(height: 24),
                // TÍNH NĂNG MỚI: Dropdown chọn canh lề
                DropdownButtonFormField<MarginPreset>(
                  initialValue: _selectedMarginPreset,
                  decoration: const InputDecoration(
                    labelText: 'Canh lề',
                    border: OutlineInputBorder(),
                  ),
                  items: MarginPreset.values.map((preset) {
                    return DropdownMenuItem<MarginPreset>(
                      value: preset,
                      child: Text(preset.label),
                    );
                  }).toList(),
                  onChanged: (MarginPreset? newValue) {
                    if (newValue != null) {
                      _updateMarginControllers(newValue);
                    }
                  },
                ),
                // TÍNH NĂNG MỚI: Hiển thị các ô nhập liệu khi chọn "Tùy chỉnh"
                if (_selectedMarginPreset == MarginPreset.custom) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMarginTextField(
                          _marginTopController,
                          'Trên',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMarginTextField(
                          _marginBottomController,
                          'Dưới',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMarginTextField(
                          _marginLeftController,
                          'Trái',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMarginTextField(
                          _marginRightController,
                          'Phải',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // TÍNH NĂNG MỚI: Slider điều chỉnh tỷ lệ
                Text(
                  'Tỷ lệ: ${(_scaleFactor * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _scaleFactor,
                  min: 0.5, // 50%
                  max: 1.5, // 150%
                  divisions: 20, // 20 steps for 100% range (5% per step)
                  label: '${(_scaleFactor * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() {
                      _scaleFactor = value;
                    });
                  },
                ),
                const Spacer(), // Đẩy các nút Google Docs xuống dưới
                if (_processingError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Lỗi: $_processingError',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (_isProcessingGoogleDocs)
                  const Center(child: CircularProgressIndicator()),
                if (!_isProcessingGoogleDocs) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_document),
                      label: const Text('Chỉnh sửa bằng Google Docs'),
                      onPressed: _handleEditWithGoogleDocs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('In từ Google Docs'),
                      onPressed: _googleDocId == null ? null : _handlePrintFromGoogleDocs,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Phần xem trước PDF
          Expanded(
            child: PdfPreview(
              // Sử dụng key để buộc PdfPreview build lại khi state thay đổi
              key: ValueKey(
                '${_selectedStore.id}_${_titleController.text}_${_selectedPageFormat.width}_${_marginTopController.text}_${_marginBottomController.text}_${_marginLeftController.text}_${_marginRightController.text}_$_scaleFactor',
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
    // Lấy giá trị lề từ controllers, chuyển đổi sang double
    final defaultMarginValue = MarginPreset.normal.value;
    final marginTop =
        (double.tryParse(_marginTopController.text) ?? defaultMarginValue) *
        PdfPageFormat.mm;
    final marginBottom =
        (double.tryParse(_marginBottomController.text) ?? defaultMarginValue) *
        PdfPageFormat.mm;
    final marginLeft =
        (double.tryParse(_marginLeftController.text) ?? defaultMarginValue) *
        PdfPageFormat.mm;
    final marginRight =
        (double.tryParse(_marginRightController.text) ?? defaultMarginValue) *
        PdfPageFormat.mm;

    // Tạo khổ giấy mới với lề đã tùy chỉnh
    final customFormat = format.copyWith(
      marginTop: marginTop,
      marginBottom: marginBottom,
      marginLeft: marginLeft,
      marginRight: marginRight,
    );

    final printerService = context.read<ReceiptPrinterService>();
    final doc = await printerService.generatePdfDocument(
      widget.order,
      _selectedStore,
      title: _titleController.text,
      scaleFactor: _scaleFactor,
      pageFormat: customFormat, // Truyền khổ giấy đã tùy chỉnh
    );
    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }

  Widget _buildMarginTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => setState(() {}), // Rebuild on change
    );
  }
}

/// Một formatter để tự động chuyển đổi văn bản nhập vào thành chữ in hoa.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
