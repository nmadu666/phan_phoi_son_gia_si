import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleApiService {
  // TODO: Thay thế bằng Client ID của bạn từ Google Cloud Console
  static const _clientIdValue = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
  final _clientId = ClientId(_clientIdValue);
  final _scopes = [drive.DriveApi.driveFileScope];

  http.Client? _client;

  /// Bắt đầu luồng xác thực OAuth 2.0 và lấy http.Client đã được xác thực.
  Future<bool> authenticate() async {
    try {
      _client = await clientViaUserConsent(_clientId, _scopes, _prompt);
      return true;
    } catch (e) {
      debugPrint('Lỗi xác thực Google API: $e');
      return false;
    }
  }

  bool get isAuthenticated => _client != null;

  /// Hàm callback để mở URL xác thực trên trình duyệt.
  void _prompt(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  /// Tạo một file Google Docs từ nội dung HTML.
  /// Trả về ID của file đã tạo.
  Future<String?> createDocumentFromHtml(
    String htmlContent,
    String title,
  ) async {
    if (!isAuthenticated) {
      throw Exception('Chưa xác thực với Google API.');
    }

    final driveApi = drive.DriveApi(_client!);

    // 1. Chuẩn bị metadata cho file
    final gFile = drive.File()
      ..name = title
      ..mimeType = 'application/vnd.google-apps.document';

    // 2. Chuẩn bị nội dung HTML để tải lên
    final media = drive.Media(
      Stream.value(htmlContent.codeUnits),
      htmlContent.codeUnits.length,
      contentType: 'text/html',
    );

    // 3. Gửi yêu cầu tạo file
    try {
      final createdFile = await driveApi.files.create(
        gFile,
        uploadMedia: media,
      );
      debugPrint('Đã tạo Google Doc với ID: ${createdFile.id}');
      return createdFile.id;
    } catch (e) {
      debugPrint('Lỗi khi tạo Google Doc: $e');
      return null;
    }
  }

  /// Mở một file Google Docs trong trình duyệt để chỉnh sửa.
  Future<void> openDocumentForEditing(String docId) async {
    final url = 'https://docs.google.com/document/d/$docId/edit';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } else {
      throw 'Could not launch $url';
    }
  }

  /// Xuất file Google Docs ra định dạng PDF và trả về dưới dạng [Uint8List].
  Future<Uint8List?> exportDocumentAsPdf(String docId) async {
    if (!isAuthenticated) {
      throw Exception('Chưa xác thực với Google API.');
    }

    final driveApi = drive.DriveApi(_client!);

    try {
      final media =
          await driveApi.files.export(
                docId,
                'application/pdf',
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = await media.stream.expand((chunk) => chunk).toList();
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Lỗi khi xuất PDF từ Google Doc: $e');
      return null;
    }
  }
}
