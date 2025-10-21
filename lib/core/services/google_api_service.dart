import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/docs/v1.dart' as docs;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleApiService {
  static const _clientIdValue =
      '1058439936847-ua2dnsss949i40r8107ispacbp9i8hga.apps.googleusercontent.com';
  final _clientId = ClientId(_clientIdValue);
  // Thêm scope drive để có toàn quyền quản lý file (tạo, xóa, sửa)
  // thay vì chỉ drive.file (chỉ tạo file do ứng dụng tạo ra)
  // Điều này cần thiết để tạo thư mục và dọn dọn. Thêm DocsApi.documentsScope
  final _scopes = [drive.DriveApi.driveFileScope, docs.DocsApi.documentsScope];

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

  /// NÂNG CẤP: Tìm hoặc tạo một thư mục trên Google Drive.
  /// Trả về ID của thư mục.
  Future<String?> _findOrCreateFolder(
    drive.DriveApi driveApi,
    String folderName,
  ) async {
    try {
      // 1. Tìm kiếm thư mục
      final query =
          "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
      final response = await driveApi.files.list(
        q: query,
        $fields: 'files(id)',
      );
      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint(
          'Đã tìm thấy thư mục "$folderName" với ID: ${response.files!.first.id}',
        );
        return response.files!.first.id;
      }

      // 2. Nếu không tìm thấy, tạo thư mục mới
      debugPrint('Không tìm thấy thư mục "$folderName". Đang tạo mới...');
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final createdFolder = await driveApi.files.create(folder);
      debugPrint('Đã tạo thư mục "$folderName" với ID: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      debugPrint('Lỗi khi tìm hoặc tạo thư mục: $e');
      return null;
    }
  }

  /// Tạo một file Google Docs từ nội dung HTML.
  /// Trả về ID của file đã tạo.
  Future<String?> createDocumentFromHtml(
    String htmlContent,
    String title, {
    String? folderName, // NÂNG CẤP: Thêm tùy chọn thư mục
  }) async {
    if (!isAuthenticated) {
      throw Exception('Chưa xác thực với Google API.');
    }

    final driveApi = drive.DriveApi(_client!);
    String? parentFolderId;

    // NÂNG CẤP: Nếu có tên thư mục, tìm hoặc tạo thư mục đó
    if (folderName != null) {
      parentFolderId = await _findOrCreateFolder(driveApi, folderName);
    }

    // 1. Chuẩn bị metadata cho file
    final gFile = drive.File()
      ..name = title
      ..mimeType = 'application/vnd.google-apps.document'
      // NÂNG CẤP: Gán file vào thư mục cha nếu có
      ..parents = parentFolderId != null ? [parentFolderId] : null;

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

  /// Tạo một hóa đơn từ template, điền dữ liệu và trả về ID của file mới.
  ///
  /// [templateId] là ID của file Google Docs mẫu.
  /// [data] là một Map chứa dữ liệu để thay thế, ví dụ: {'ten_khach_hang': 'Anh A'}.
  /// [folderName] là tên thư mục để lưu file mới. Nếu null, file sẽ được lưu ở thư mục gốc.
  Future<String?> createInvoiceFromTemplate(
    String templateId,
    Map<String, String> data, {
    String? folderName, // Thêm tùy chọn thư mục
  }) async {
    if (!isAuthenticated) {
      throw Exception('Chưa xác thực với Google API.');
    }

    final driveApi = drive.DriveApi(_client!);
    final docsApi = docs.DocsApi(_client!);
    String? newFileId;
    String? parentFolderId;

    try {
      // Nếu có tên thư mục, tìm hoặc tạo thư mục đó
      if (folderName != null) {
        parentFolderId = await _findOrCreateFolder(driveApi, folderName);
      }

      // 1. Sao chép tệp mẫu để tạo một tệp mới
      final newFileName =
          'Hóa đơn cho ${data['ten_khach_hang'] ?? 'Khách hàng'}';
      final request = drive.File()
        ..name = newFileName
        // Gán file vào thư mục cha nếu có
        ..parents = parentFolderId != null ? [parentFolderId] : null;
      final copiedFile = await driveApi.files.copy(request, templateId);
      newFileId = copiedFile.id;

      if (newFileId == null) {
        throw Exception('Không thể sao chép tệp mẫu.');
      }
      debugPrint('Đã sao chép tệp mẫu, ID mới: $newFileId');

      // 2. Chuẩn bị các yêu cầu thay thế văn bản
      final List<docs.Request> requests = [];
      data.forEach((key, value) {
        requests.add(
          docs.Request(
            replaceAllText: docs.ReplaceAllTextRequest(
              containsText: docs.SubstringMatchCriteria(
                text: '{{$key}}',
                matchCase: true,
              ),
              replaceText: value,
            ),
          ),
        );
      });

      // 3. Gửi yêu cầu batchUpdate để điền dữ liệu vào tệp mới
      final batchUpdateRequest = docs.BatchUpdateDocumentRequest(requests: requests);
      await docsApi.documents.batchUpdate(batchUpdateRequest, newFileId);

      debugPrint('Đã điền dữ liệu vào hóa đơn.');
      return newFileId;
    } catch (e) {
      debugPrint('Lỗi khi tạo hóa đơn từ mẫu: $e');
      // Nếu có lỗi, cố gắng xóa file đã tạo để tránh rác
      if (newFileId != null) {
        await driveApi.files.delete(newFileId);
      }
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

  /// NÂNG CẤP: Xóa một file trên Google Drive bằng ID.
  Future<bool> deleteDocument(String docId) async {
    if (!isAuthenticated) {
      throw Exception('Chưa xác thực với Google API.');
    }
    final driveApi = drive.DriveApi(_client!);
    try {
      await driveApi.files.delete(docId);
      debugPrint('Đã xóa thành công file với ID: $docId');
      return true;
    } catch (e) {
      debugPrint('Lỗi khi xóa file $docId: $e');
      return false;
    }
  }
}
