import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Tải một hình ảnh từ Firebase Storage sử dụng URL `gs://` và chuyển đổi nó
/// thành một [pw.ImageProvider] để sử dụng trong tài liệu PDF.
///
/// Hàm này giải quyết vấn đề URL của Firebase Storage có token hết hạn bằng cách
/// lấy URL tải xuống công khai, ổn định trước khi tải dữ liệu hình ảnh.
///
/// [url]: Đường dẫn đến file trên Firebase Storage, phải có định dạng `gs://<bucket>/<path_to_image>`.
///
/// Trả về một [pw.ImageProvider] có thể được sử dụng trực tiếp trong widget `pw.Image`.
/// Ném ra một [Exception] nếu URL không hợp lệ hoặc không thể tải hình ảnh.
Future<pw.ImageProvider> firebaseImage(String originalUrl) async {
  String gsUrl = originalUrl;

  // TỐI ƯU: Tự động chuyển đổi URL https:// của Firebase Storage sang định dạng gs://
  // Điều này giúp xử lý cả URL cũ và mới một cách đồng nhất.
  if (originalUrl.startsWith('https://firebasestorage.googleapis.com')) {
    try {
      final uri = Uri.parse(originalUrl);
      final bucket = uri.pathSegments[2];
      // Ghép các phần còn lại của path và decode
      final path = Uri.decodeComponent(uri.pathSegments.sublist(4).join('/'));
      gsUrl = 'gs://$bucket/$path';
      debugPrint('firebaseImage: Đã chuyển đổi URL http sang gs: $gsUrl');
    } catch (e) {
      debugPrint(
        'firebaseImage: Không thể chuyển đổi URL http. Sử dụng URL gốc. Lỗi: $e',
      );
      // Nếu không chuyển đổi được, vẫn thử dùng URL gốc với networkImage
      return networkImage(originalUrl);
    }
  }

  try {
    // 1. Lấy tham chiếu đến file từ URL gs://
    final ref = FirebaseStorage.instance.refFromURL(gsUrl);
    // 2. Lấy URL tải xuống công khai (không có token)
    String downloadUrl = await ref.getDownloadURL();

    // TỐI ƯU: Thêm một tham số truy vấn ngẫu nhiên để "phá" cache của `networkImage`.
    // Điều này đảm bảo rằng ảnh sẽ luôn được tải lại với token mới,
    // thay vì sử dụng lại kết quả lỗi đã được cache từ token cũ.
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final separator = downloadUrl.contains('?') ? '&' : '?';
    downloadUrl = '$downloadUrl${separator}cacheBuster=$cacheBuster';

    // 3. Sử dụng networkImage của thư viện printing để tải hình ảnh từ URL công khai
    return await networkImage(downloadUrl);
  } catch (e) {
    debugPrint('Lỗi khi tải hình ảnh từ Firebase Storage ($gsUrl): $e');
    rethrow; // Ném lại lỗi để nơi gọi có thể xử lý
  }
}
