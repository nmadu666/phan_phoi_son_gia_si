import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:printing/printing.dart';

class ReceiptPrinterService {
  // --- Tối ưu hóa: Cache font và logo ---
  pw.ThemeData? _theme;
  final Map<String, pw.ImageProvider> _logoCache = {};

  /// Initializes the service by pre-loading fonts.
  /// This should be called once when the app starts.
  Future<void> init() async {
    if (_theme != null) return; // Already initialized

    // Tải tất cả các font song song
    final fontData = await Future.wait([
      rootBundle.load("assets/fonts/NotoSans-Regular.ttf"),
      rootBundle.load("assets/fonts/NotoSans-Bold.ttf"),
      rootBundle.load("assets/fonts/NotoSans-Italic.ttf"),
      rootBundle.load("assets/fonts/NotoSans-BoldItalic.ttf"),
    ]);

    _theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(fontData[0]),
      bold: pw.Font.ttf(fontData[1]),
      italic: pw.Font.ttf(fontData[2]),
      boldItalic: pw.Font.ttf(fontData[3]),
    );
  }

  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  /// Hàm này giờ chỉ là một lối tắt để in nhanh với các giá trị mặc định
  Future<void> printReceipt(
    TemporaryOrder order,
    StoreInfo storeInfo, {
    String title = 'HÓA ĐƠN BÁN HÀNG',
  }) async {
    final doc = await generatePdfDocument(order, storeInfo, title: title);
    // Hiển thị màn hình xem trước và in
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  /// Tạo đối tượng Document PDF dựa trên các tham số.
  Future<pw.Document> generatePdfDocument(
    TemporaryOrder order,
    StoreInfo storeInfo, {
    String title = 'HÓA ĐƠN BÁN HÀNG',
    PdfPageFormat? pageFormat,
  }) async {
    // Đảm bảo font đã được tải
    if (_theme == null) {
      await init();
    }
    final doc = pw.Document();

    // Tải logo trước khi xây dựng trang
    final logoImage = await _loadLogo(storeInfo.logoUrl);

    doc.addPage(
      pw.MultiPage(
        // Cho phép chọn khổ giấy khi in, mặc định là A4
        pageFormat:
            pageFormat ??
            PdfPageFormat.a4.copyWith(
              marginBottom: 1.5 * PdfPageFormat.cm,
              marginTop: 1.5 * PdfPageFormat.cm,
              marginLeft: 1.5 * PdfPageFormat.cm,
              marginRight: 1.5 * PdfPageFormat.cm,
            ),
        theme: _theme,
        header: (context) => _buildHeader(logoImage, storeInfo, context),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildTitle(order, title),
          pw.SizedBox(height: 0.8 * PdfPageFormat.cm),
          _buildCustomerInfo(order),
          pw.SizedBox(height: 1 * PdfPageFormat.cm),
          _buildItemsTable(order),
          pw.Divider(),
          _buildSummary(order),
          pw.SizedBox(height: 2 * PdfPageFormat.cm),
          _buildSignature(),
        ],
      ),
    );

    return doc;
  }

  Future<pw.ImageProvider?> _loadLogo(String? logoUrl) async {
    final String cacheKey = logoUrl ?? 'default_logo';

    // 1. Kiểm tra cache trước
    if (_logoCache.containsKey(cacheKey)) {
      return _logoCache[cacheKey];
    }

    // 2. Nếu không có trong cache, tải và lưu vào cache
    try {
      pw.ImageProvider? imageProvider;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        imageProvider = await networkImage(logoUrl);
      } else {
        final byteData = await rootBundle.load('assets/images/logo.png');
        imageProvider = pw.MemoryImage(byteData.buffer.asUint8List());
      }
      _logoCache[cacheKey] = imageProvider;
      return imageProvider;
    } catch (e) {
      print('Could not load logo: $e');
      return null;
    }
  }

  pw.Widget _buildHeader(
    pw.ImageProvider? logoImage,
    StoreInfo storeInfo,
    pw.Context context,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Flexible(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    storeInfo.name,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Địa chỉ: ${storeInfo.address}'),
                  pw.Text('Hotline: ${storeInfo.hotline}'),
                  pw.Text('Email: ${storeInfo.email}'),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            if (logoImage != null)
              pw.SizedBox(
                height: 60,
                width: 60,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
          ],
        ),
        pw.SizedBox(height: 1 * PdfPageFormat.cm),
      ],
    );
  }

  pw.Widget _buildTitle(TemporaryOrder order, String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
        ),
        pw.SizedBox(height: 0.2 * PdfPageFormat.cm),
        pw.Text(
          'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}',
        ),
        pw.Text('Số: ${order.kiotvietOrderCode ?? order.name}'),
      ],
    );
  }

  pw.Widget _buildCustomerInfo(TemporaryOrder order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Khách hàng: ${order.customer?.name ?? 'Khách lẻ'}'),
              if (order.customer != null)
                pw.Text('SĐT: ${order.customer!.contactNumber ?? 'N/A'}'),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Nhân viên: ${order.seller?.givenName ?? 'N/A'}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(TemporaryOrder order) {
    final headers = [
      'STT',
      'Tên hàng hóa',
      'ĐVT',
      'SL',
      'Đơn giá',
      'Thành tiền',
    ];

    final data = order.items.map((item) {
      final index = order.items.indexOf(item) + 1;
      return [
        index.toString(),
        item.productFullName,
        item.unit,
        item.quantity.toStringAsFixed(0),
        currencyFormat.format(item.unitPrice),
        currencyFormat.format(item.totalAfterDiscount),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      columnWidths: {
        0: const pw.IntrinsicColumnWidth(flex: 0.5), // STT
        1: const pw.FlexColumnWidth(4), // Tên hàng
        2: const pw.IntrinsicColumnWidth(flex: 0.8), // ĐVT
        3: const pw.IntrinsicColumnWidth(flex: 0.8), // SL
        4: const pw.FlexColumnWidth(1.5), // Đơn giá
        5: const pw.FlexColumnWidth(1.5), // Thành tiền
      },
    );
  }

  pw.Widget _buildSummary(TemporaryOrder order) {
    return pw.Container(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Ghi chú:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(order.description ?? ''),
              ],
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(
                  'Tổng tiền hàng:',
                  currencyFormat.format(order.totalBeforeDiscount),
                ),
                _buildSummaryRow(
                  'Tổng chiết khấu:',
                  currencyFormat.format(order.totalDiscount),
                ),
                pw.Divider(),
                _buildSummaryRow(
                  'Khách cần trả:',
                  currencyFormat.format(order.total),
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    final style = isBold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)
        : const pw.TextStyle(fontSize: 11);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Cảm ơn quý khách và hẹn gặp lại!',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.Text(
              'Trang ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        pw.SizedBox(height: 1 * PdfPageFormat.mm),
        pw.Text(
          'Powered by Gemini Code Assist',
          style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8),
        ),
      ],
    );
  }

  pw.Widget _buildSignature() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Text('Khách hàng'),
            pw.SizedBox(height: 0.5 * PdfPageFormat.cm),
            pw.Text(
              '(Ký, ghi rõ họ tên)',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Text('Người bán hàng'),
            pw.SizedBox(height: 0.5 * PdfPageFormat.cm),
            pw.Text(
              '(Ký, ghi rõ họ tên)',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      ],
    );
  }
}
