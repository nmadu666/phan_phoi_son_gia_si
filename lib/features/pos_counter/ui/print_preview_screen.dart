import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdfx/pdfx.dart';
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/store_info_service.dart';
import 'package:phan_phoi_son_gia_si/core/utils/receipt_printer_service.dart';
import 'package:pdfx/pdfx.dart'
    as pdfx; // THAY ĐỔI: Sử dụng pdfx thay vì printing
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
  // State để quản lý khổ giấy được chọn
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

  // TỐI ƯU: State để quản lý dữ liệu PDF và debounce
  Uint8List? _pdfBytes;
  Timer? _debounce;
  bool _isGeneratingPdf = true; // Hiển thị loading indicator ban đầu
  int _pdfGenerationCount = 0; // Dùng cho ValueKey để force rebuild
  // THAY ĐỔI: Controller để quản lý việc hiển thị PDF
  pdfx.PdfController? _pdfController;

  // Định nghĩa các khổ giấy có sẵn
  final Map<String, PdfPageFormat> _pageFormats = {
    'A4': PdfPageFormat.a4,
    'A5': PdfPageFormat.a5,
    'Hóa đơn 80mm': PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
  };

  // Danh sách các mẫu tiêu đề hóa đơn
  final List<String> _invoiceTitles = [
    'HÓA ĐƠN BÁN HÀNG',
    'BÁO GIÁ KHÁCH HÀNG',
  ];

  @override
  void initState() {
    super.initState();
    final storeService = context.read<StoreInfoService>();
    _selectedStore = storeService.defaultStore; // Initialize _selectedStore
    _titleController = TextEditingController(
      text: _invoiceTitles.first,
    ); // Initialize with default title
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

    // TỐI ƯU: Thêm listeners để kích hoạt debounce
    _titleController.addListener(_onSettingsChanged);
    _marginTopController.addListener(_onSettingsChanged);
    _marginBottomController.addListener(_onSettingsChanged);
    _marginLeftController.addListener(_onSettingsgChanged);
    _marginRightController.addListener(_onSettingsChanged);

    // TỐI ƯU: Tạo PDF lần đầu tiên
    _triggerPdfRegeneration(immediate: true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _marginTopController.dispose();
    _marginBottomController.dispose();
    _marginLeftController.dispose();
    _marginRightController.dispose();
    // TỐI ƯU: Hủy debounce timer và xóa listeners
    _debounce?.cancel();
    _titleController.removeListener(_onSettingsChanged);
    _marginTopController.removeListener(_onSettingsChanged);
    _marginBottomController.removeListener(_onSettingsChanged);
    _marginLeftController.removeListener(_onSettingsgChanged);
    _marginRightController.removeListener(_onSettingsChanged);
    // THAY ĐỔI: Hủy pdfController khi widget bị dispose
    _pdfController?.dispose();
    super.dispose();
  }

  // TỐI ƯU: Dummy listener để tránh lỗi typo trong removeListener
  void _onSettingsgChanged() {
    _onSettingsChanged();
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
      _triggerPdfRegeneration(); // Tái tạo PDF khi preset thay đổi
    });
  }

  /// TỐI ƯU: Kích hoạt việc tái tạo PDF với cơ chế debounce.
  void _onSettingsChanged() {
    _triggerPdfRegeneration();
  }

  /// TỐI ƯU: Hàm quản lý debounce và tái tạo PDF.
  void _triggerPdfRegeneration({bool immediate = false}) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Nếu `immediate` là true, chạy ngay lập tức.
    // Ngược lại, đợi 500ms.
    if (immediate) {
      _regeneratePdf();
    } else {
      setState(() {
        _isGeneratingPdf = true; // Hiển thị loading ngay khi bắt đầu gõ
      });
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _regeneratePdf();
      });
    }
  }

  /// TỐI ƯU: Hàm thực hiện việc tạo PDF và cập nhật state.
  Future<void> _regeneratePdf() async {
    // Đảm bảo widget vẫn còn tồn tại
    if (!mounted) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    final bytes = await _generatePdfBytes(_selectedPageFormat);

    if (mounted) {
      // THAY ĐỔI: Cập nhật PdfController thay vì chỉ cập nhật _pdfBytes
      // Hủy controller cũ trước khi tạo cái mới
      _pdfController?.dispose();
      setState(() {
        _pdfBytes = bytes;
        _pdfController = pdfx.PdfController(
          document: pdfx.PdfDocument.openData(bytes),
        );
        _isGeneratingPdf = false;
        _pdfGenerationCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeService = context.watch<StoreInfoService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem trước và Tùy chỉnh In'),
        // THAY ĐỔI: Thêm nút để thực hiện hành động in
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: _printPdf),
          const SizedBox(width: 8),
        ],
      ),
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
                        _triggerPdfRegeneration();
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
                          // Listener đã được thêm trong initState, không cần onChanged ở đây
                          // onChanged: (value) => _onSettingsChanged(),
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
                      _triggerPdfRegeneration();
                    });
                  },
                ),
                const Spacer(), // Đẩy các nút Google Docs xuống dưới
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Phần xem trước PDF
          Expanded(
            child: _isGeneratingPdf && _pdfBytes == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // THAY ĐỔI: Sử dụng PdfView từ gói pdfx
                      if (_pdfController != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: PdfView(
                            key: ValueKey(_pdfGenerationCount),
                            controller: _pdfController!,
                          ),
                        ),
                      if (_isGeneratingPdf)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Tạo file PDF dựa trên các tùy chọn hiện tại
  Future<Uint8List> _generatePdfBytes(PdfPageFormat format) async {
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

  /// THAY ĐỔI: Hàm để thực hiện hành động in
  Future<void> _printPdf() async {
    if (_pdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dữ liệu PDF để in.')),
      );
      return;
    }
    // Sử dụng lại thư viện printing cho chức năng in cuối cùng
    await Printing.layoutPdf(onLayout: (format) async => _pdfBytes!);
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
      // Listener đã được thêm trong initState, không cần onChanged ở đây
      // onChanged: (value) {
      //   _onSettingsChanged();
      // },
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
