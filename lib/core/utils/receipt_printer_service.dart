import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:printing/printing.dart';
import 'package:phan_phoi_son_gia_si/core/utils/firebase_image.dart';

class ReceiptPrinterService {
  // --- Tối ưu hóa: Cache font và logo ---
  pw.ThemeData? _theme;
  pw.Font? _fallbackFont;
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
      // TỐI ƯU: Tải font fallback để hiển thị các ký tự đặc biệt
      rootBundle.load("assets/fonts/NotoSansSymbols2-Regular.ttf"),
    ]);

    _fallbackFont = pw.Font.ttf(fontData[4]);
    _theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(fontData[0]),
      bold: pw.Font.ttf(fontData[1]),
      italic: pw.Font.ttf(fontData[2]),
      boldItalic: pw.Font.ttf(fontData[3]),
      fontFallback: [_fallbackFont!],
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
    double scaleFactor = 1.0,
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
        // footer: (context) => _buildFooter(context), // TỐI ƯU: Loại bỏ footer theo yêu cầu
        build: (pw.Context context) {
          final content = pw.Column(
            // TỐI ƯU: Giãn cột để chiếm toàn bộ chiều rộng, đồng nhất với header
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
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
          );
          // Áp dụng tỷ lệ nếu nó khác 1.0
          return [
            scaleFactor == 1.0
                ? content
                : pw.Transform.scale(scale: scaleFactor, child: content),
          ];
        },
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
        // TỐI ƯU: Sử dụng firebaseImage thay vì networkImage để xử lý các URL của Firebase Storage
        // một cách ổn định, tránh lỗi do token hết hạn.
        // URL cần có dạng gs://<bucket>/<path_to_image>
        imageProvider = await firebaseImage(logoUrl);
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
    // TỐI ƯU: Đặt trong Center để căn giữa toàn bộ khối tiêu đề
    return pw.Center(
      child: pw.Column(
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
      ),
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
      'Mã hàng',
      'Tên hàng hóa',
      'ĐVT',
      'SL',
      'Đơn giá',
      'Thành tiền',
    ];

    // TỐI ƯU: Sử dụng asMap().entries.map để tránh dùng indexOf() trong vòng lặp (O(n^2) -> O(n))
    final data = order.items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      return [
        index.toString(),
        item.productCode,
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
        0: const pw.IntrinsicColumnWidth(flex: 0.4), // STT
        1: const pw.FlexColumnWidth(1.2), // Mã hàng
        2: const pw.FlexColumnWidth(2.5), // Tên hàng
        3: const pw.IntrinsicColumnWidth(flex: 0.5), // ĐVT
        4: const pw.IntrinsicColumnWidth(flex: 0.5), // SL
        5: const pw.FlexColumnWidth(1), // Đơn giá
        6: const pw.FlexColumnWidth(1.2), // Thành tiền
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

  /* pw.Widget _buildFooter(pw.Context context) {
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
 */
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

  /// TÍNH NĂNG MỚI: Tạo nội dung HTML cho hóa đơn để import vào Google Docs.
  String generateHtml(TemporaryOrder order, StoreInfo storeInfo, String title) {
    final buffer = StringBuffer();

    // Sử dụng inline style để đảm bảo định dạng khi import vào Google Docs
    buffer.writeln('<html><head><style>');
    buffer.writeln(
      'body { font-family: "Noto Sans", sans-serif; font-size: 10pt; }',
    );
    buffer.writeln('table { width: 100%; border-collapse: collapse; }');
    buffer.writeln(
      'th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }',
    );
    buffer.writeln('th { background-color: #f2f2f2; }');
    buffer.writeln('.text-right { text-align: right; }');
    buffer.writeln('.bold { font-weight: bold; }');
    buffer.writeln(
      '.header-table { border: none; } .header-table td { border: none; padding: 0; }',
    );
    buffer.writeln(
      '.summary-table { width: 50%; float: right; } .summary-table td { border: none; }',
    );
    buffer.writeln(
      '.signature-table { width: 100%; margin-top: 50px; } .signature-table td { border: none; text-align: center; }',
    );
    buffer.writeln('</style></head><body>');

    // --- Header ---
    buffer.writeln('<table class="header-table"><tr>');
    buffer.writeln('<td>');
    buffer.writeln('<h2>${storeInfo.name}</h2>');
    buffer.writeln('<p>Địa chỉ: ${storeInfo.address}<br>');
    buffer.writeln('Hotline: ${storeInfo.hotline}<br>');
    buffer.writeln('Email: ${storeInfo.email}</p>');
    buffer.writeln('</td>');
    // Logo sẽ được thêm vào Google Docs sau nếu cần, HTML khó căn chỉnh
    buffer.writeln('</tr></table>');

    // --- Title ---
    buffer.writeln('<div style="text-align: center;">');
    buffer.writeln('<h1>$title</h1>');
    buffer.writeln(
      '<p>Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}<br>',
    );
    buffer.writeln('Số: ${order.kiotvietOrderCode ?? order.name}</p>');
    buffer.writeln('</div>');

    // --- Customer Info ---
    buffer.writeln('<table class="header-table"><tr>');
    buffer.writeln('<td>Khách hàng: ${order.customer?.name ?? 'Khách lẻ'}<br>');
    if (order.customer != null) {
      buffer.writeln('SĐT: ${order.customer!.contactNumber ?? 'N/A'}');
    }
    buffer.writeln('</td>');
    buffer.writeln(
      '<td style="text-align: right;">Nhân viên: ${order.seller?.givenName ?? 'N/A'}</td>',
    );
    buffer.writeln('</tr></table>');

    buffer.writeln('<br>');

    // --- Items Table ---
    buffer.writeln('<table>');
    buffer.writeln('<thead><tr>');
    buffer.writeln('<th>STT</th>');
    buffer.writeln('<th>Mã hàng</th>');
    buffer.writeln('<th>Tên hàng hóa</th>');
    buffer.writeln('<th>ĐVT</th>');
    buffer.writeln('<th>SL</th>');
    buffer.writeln('<th>Đơn giá</th>');
    buffer.writeln('<th>Thành tiền</th>');
    buffer.writeln('</tr></thead>');
    buffer.writeln('<tbody>');
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln('<tr>');
      buffer.writeln('<td>${i + 1}</td>');
      buffer.writeln('<td>${item.productCode}</td>');
      buffer.writeln('<td>${item.productFullName}</td>');
      buffer.writeln('<td>${item.unit}</td>');
      buffer.writeln(
        '<td class="text-right">${item.quantity.toStringAsFixed(0)}</td>',
      );
      buffer.writeln(
        '<td class="text-right">${currencyFormat.format(item.unitPrice)}</td>',
      );
      buffer.writeln(
        '<td class="text-right">${currencyFormat.format(item.totalAfterDiscount)}</td>',
      );
      buffer.writeln('</tr>');
    }
    buffer.writeln('</tbody></table>');

    // --- Summary ---
    buffer.writeln('<br>');
    buffer.writeln('<p><b>Ghi chú:</b> ${order.description ?? ''}</p>');
    buffer.writeln('<table class="summary-table">');
    buffer.writeln(
      '<tr><td>Tổng tiền hàng:</td><td class="text-right">${currencyFormat.format(order.totalBeforeDiscount)}</td></tr>',
    );
    buffer.writeln(
      '<tr><td>Tổng chiết khấu:</td><td class="text-right">${currencyFormat.format(order.totalDiscount)}</td></tr>',
    );
    buffer.writeln('<tr><td colspan="2"><hr></td></tr>');
    buffer.writeln(
      '<tr><td class="bold">Khách cần trả:</td><td class="text-right bold">${currencyFormat.format(order.total)}</td></tr>',
    );
    buffer.writeln('</table>');
    buffer.writeln('<div style="clear: both;"></div>');

    // --- Signature ---
    buffer.writeln('<table class="signature-table">');
    buffer.writeln('<tr>');
    buffer.writeln('<td><b>Khách hàng</b><br><i>(Ký, ghi rõ họ tên)</i></td>');
    buffer.writeln(
      '<td><b>Người bán hàng</b><br><i>(Ký, ghi rõ họ tên)</i></td>',
    );
    buffer.writeln('</tr>');
    buffer.writeln('</table>');

    buffer.writeln('</body></html>');
    return buffer.toString();
  }
}
