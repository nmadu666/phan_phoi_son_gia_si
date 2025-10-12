import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/print_template.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/print_preview_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart' as htw;

/// Hàm top-level để chuyển đổi HTML sang PDF, được thiết kế để chạy trong một Isolate riêng biệt.
/// Điều này ngăn chặn việc block luồng UI chính khi thực hiện các tác vụ nặng.
Future<Uint8List> _generatePdfFromHtml(String htmlContent) async {
  final pdf = pw.Document();
  final List<pw.Widget> widgets = await htw.HTMLToPdf().convert(htmlContent);

  pdf.addPage(pw.MultiPage(build: (context) => widgets));

  return pdf.save();
}

/// Một dialog để xem trước và chọn mẫu in cho một đơn hàng.
class PrintPreviewDialog extends StatelessWidget {
  final TemporaryOrder order;
  final PrintTemplateType templateType;

  const PrintPreviewDialog({
    super.key,
    required this.order,
    this.templateType = PrintTemplateType.invoice,
  });

  @override
  Widget build(BuildContext context) {
    // Cung cấp PrintPreviewService cho dialog này và các widget con của nó.
    return ChangeNotifierProvider(
      create: (_) =>
          PrintPreviewService()..initialize(order: order, type: templateType),
      child: AlertDialog(
        title: const Text('Xem trước bản in'),
        // Đặt kích thước cho dialog
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6, // 60% chiều rộng
          height: MediaQuery.of(context).size.height * 0.7, // 70% chiều cao
          child: Consumer<PrintPreviewService>(
            builder: (context, service, child) {
              if (service.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (service.availableTemplates.isEmpty) {
                return const Center(
                  child: Text(
                    'Không tìm thấy mẫu in nào cho loại tài liệu này.',
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cột trái: Tùy chọn
                  Expanded(
                    flex: 2,
                    child: _buildOptionsPanel(context, service),
                  ),
                  const VerticalDivider(width: 24),
                  // Cột phải: Nội dung xem trước
                  Expanded(flex: 3, child: _buildPreviewPanel(service)),
                ],
              );
            },
          ),
        ),
        // Sử dụng Consumer để có được context nằm dưới Provider
        actions: <Widget>[
          Consumer<PrintPreviewService>(
            builder: (context, service, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final content = service.previewContent;
                      if (content == null) return;

                      // Chuyển tác vụ tạo PDF nặng sang một Isolate khác bằng `compute`.
                      // Điều này giúp UI không bị "đơ" trong quá trình xử lý.
                      await Printing.layoutPdf(
                        onLayout: (format) =>
                            compute(_generatePdfFromHtml, content),
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('In'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Panel chứa các tùy chọn như chọn mẫu in.
  Widget _buildOptionsPanel(BuildContext context, PrintPreviewService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tùy chọn', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: service.selectedTemplate?.id,
          decoration: const InputDecoration(
            labelText: 'Chọn mẫu in',
            border: OutlineInputBorder(),
          ),
          items: service.availableTemplates.map((template) {
            return DropdownMenuItem<String>(
              value: template.id,
              child: Text(template.name),
            );
          }).toList(),
          onChanged: (templateId) {
            if (templateId != null) {
              final selected = service.availableTemplates.firstWhere(
                (t) => t.id == templateId,
              );
              service.selectTemplate(selected);
            }
          },
        ),
      ],
    );
  }

  /// Panel hiển thị nội dung xem trước.
  Widget _buildPreviewPanel(PrintPreviewService service) {
    // Định nghĩa các style cho các thẻ HTML khác nhau.
    // Đây là nơi bạn có thể tùy chỉnh giao diện giống như CSS.
    final Map<String, Style> htmlStyles = {
      // Style cho toàn bộ body, loại bỏ margin mặc định và đặt font chữ.
      'body': Style(
        margin: Margins.zero,
        fontFamily: 'sans-serif',
        fontSize: FontSize.medium,
      ),
      'h1': Style(
        textAlign: TextAlign.center,
        fontSize: FontSize.xLarge,
        fontWeight: FontWeight.bold,
      ),
      'p': Style(lineHeight: LineHeight.number(1.5)),
      'table': Style(
        width: Width.auto(),
        border: Border.all(color: Colors.grey.shade400),
      ),
      'thead': Style(
        backgroundColor: Colors.grey.shade200,
        fontWeight: FontWeight.bold,
      ),
      'th, td': Style(
        padding: HtmlPaddings.all(8),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Html(
          data: service.previewContent ?? '<h3>Không có nội dung.</h3>',
          style: htmlStyles,
        ),
      ),
    );
  }
}
