import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/print_template.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/print_template_service.dart';
import 'package:intl/intl.dart';
import 'package:mustache_template/mustache.dart';

/// Quản lý trạng thái và logic cho việc xem trước bản in.
///
/// Service này xử lý:
/// - Tải các mẫu in có sẵn cho một loại tài liệu.
/// - Cho phép chọn một mẫu in.
/// - Lưu trữ dữ liệu (ví dụ: đơn hàng) cần in.
/// - Tạo ra nội dung xem trước (hiện tại là dạng chuỗi, có thể mở rộng ra Widget).
class PrintPreviewService with ChangeNotifier {
  final PrintTemplateService _templateService;

  PrintPreviewService({PrintTemplateService? templateService})
    : _templateService = templateService ?? PrintTemplateService();

  // Trạng thái
  bool _isLoading = false;
  List<PrintTemplate> _availableTemplates = [];
  PrintTemplate? _selectedTemplate;
  TemporaryOrder? _orderData;
  String? _previewContent;

  // Getters
  bool get isLoading => _isLoading;
  List<PrintTemplate> get availableTemplates => _availableTemplates;
  PrintTemplate? get selectedTemplate => _selectedTemplate;
  TemporaryOrder? get orderData => _orderData;
  String? get previewContent => _previewContent;

  /// Tải dữ liệu ban đầu cho việc xem trước.
  ///
  /// [order]: Dữ liệu đơn hàng cần in.
  /// [type]: Loại tài liệu cần in (ví dụ: hóa đơn).
  Future<void> initialize({
    required TemporaryOrder order,
    required PrintTemplateType type,
  }) async {
    _isLoading = true;
    _orderData = order;
    notifyListeners();

    _availableTemplates = await _templateService.getTemplates(type: type);

    // Tự động chọn mẫu in mặc định nếu có, nếu không thì chọn mẫu đầu tiên.
    if (_availableTemplates.isNotEmpty) {
      _selectedTemplate = _availableTemplates.firstWhere(
        (t) => t.isDefault,
        orElse: () => _availableTemplates.first,
      );
    }

    _generatePreview();

    _isLoading = false;
    notifyListeners();
  }

  /// Chọn một mẫu in khác và tạo lại bản xem trước.
  void selectTemplate(PrintTemplate template) {
    if (_selectedTemplate?.id == template.id) return;

    _selectedTemplate = template;
    _generatePreview();
    notifyListeners();
  }

  /// Tạo nội dung xem trước từ dữ liệu và mẫu in đã chọn.
  void _generatePreview() {
    if (_selectedTemplate == null || _orderData == null) {
      _previewContent = 'Lỗi: Không có mẫu in hoặc dữ liệu đơn hàng.';
      return;
    }

    // Chuẩn hóa cú pháp lặp để tương thích với Mustache.
    // Thay thế `{{#each items}}` và `{{/each}}` thành cú pháp chuẩn.
    final sanitizedContent = _selectedTemplate!.content
        .replaceAll('{{#each items}}', '{{#items}}')
        .replaceAll('{{/each}}', '{{/items}}');

    // Sử dụng Mustache template engine để render nội dung.
    final template = Template(
      sanitizedContent,
      htmlEscapeValues: false,
      lenient: true, // Bật chế độ linh hoạt để bỏ qua các lỗi cú pháp nhỏ
    );
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '');

    // 1. Chuẩn bị dữ liệu để điền vào template
    final data = {
      // Thông tin chung của đơn hàng
      'order_code': _orderData!.name,
      'customer_name': _orderData!.customer?.name ?? 'Khách lẻ',
      'customer_address': _orderData!.customer?.address ?? '',
      'order_date': DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(_orderData!.createdAt),
      'total_amount': currencyFormat.format(_orderData!.total),
      'total_before_discount': currencyFormat.format(
        _orderData!.totalBeforeDiscount,
      ),

      // Danh sách sản phẩm (dạng List<Map> cho vòng lặp {{#each}})
      'items': _orderData!.items.map((item) {
        return {
          'name': item.productFullName,
          'code': item.productCode,
          'quantity': item.quantity,
          'price': currencyFormat.format(item.unitPrice),
          'line_total': currencyFormat.format(item.totalAfterDiscount),
        };
      }).toList(),

      // Chuỗi danh sách sản phẩm (dạng text cho các mẫu in đơn giản như K80)
      'item_list': _orderData!.items
          .map((item) {
            final name = item.productName;
            final quantity = item.quantity.toString().padLeft(3);
            final price = currencyFormat.format(item.unitPrice).padLeft(8);
            final total = currencyFormat
                .format(item.totalAfterDiscount)
                .padLeft(9);
            return '$name | $quantity | $price | $total';
          })
          .join('\n'),
    };

    // 2. Render template với dữ liệu
    _previewContent = template.renderString(data);
  }
}
