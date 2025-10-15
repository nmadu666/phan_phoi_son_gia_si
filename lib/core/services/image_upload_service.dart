import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery and uploads it to Firebase Storage.
  ///
  /// Returns the download URL of the uploaded image, or null if the process is cancelled or fails.
  Future<String?> pickAndUploadImage() async {
    try {
      // 1. Pick image
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return null; // User cancelled the picker
      }

      // 2. Prepare for upload
      final String fileName =
          'store_logos/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final Reference storageRef = _storage.ref().child(fileName);

      // 3. Upload file
      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(await image.readAsBytes());
      } else {
        uploadTask = storageRef.putFile(File(image.path));
      }

      // 4. Lấy URL gs:// ổn định
      final TaskSnapshot snapshot = await uploadTask;
      // TỐI ƯU: Trả về URL gs:// thay vì URL tải xuống có token hết hạn.
      // URL này sẽ được hàm `firebaseImage` sử dụng để lấy URL tải xuống mới mỗi lần.
      return 'gs://${snapshot.ref.bucket}/${snapshot.ref.fullPath}';
    } catch (e) {
      debugPrint('Error picking and uploading image: $e');
      return null;
    }
  }
}
