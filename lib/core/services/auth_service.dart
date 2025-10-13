import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _firebaseAuth;
  final AppUserService _appUserService;

  // Constructor để có thể inject dependency, hữu ích cho việc test
  AuthService({
    FirebaseAuth? firebaseAuth,
    required AppUserService appUserService,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _appUserService = appUserService {
    // Sử dụng Future.microtask để đảm bảo việc đăng nhập tự động được thực thi
    // một cách an toàn ngay sau khi service được khởi tạo, thay vì gọi
    // trực tiếp một hàm async trong constructor.
    if (kDebugMode) {
      Future.microtask(() {
        signIn(email: 'admin@ppsgs.com', password: '12345678');
      });
    }
  }

  // Stream để lắng nghe sự thay đổi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Lấy thông tin người dùng hiện tại
  User? get currentUser => _firebaseAuth.currentUser;

  // Đăng nhập bằng email và mật khẩu
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _appUserService.createOrUpdateUserDocument(userCredential.user!);
      }
      return null; // Thành công
    } on FirebaseAuthException catch (e) {
      // Trả về thông báo lỗi thân thiện với người dùng
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          return 'Không tìm thấy người dùng với email này.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Mật khẩu không đúng.';
        default:
          return 'Đã xảy ra lỗi. Vui lòng thử lại.';
      }
    } catch (e) {
      return 'Đã xảy ra lỗi không mong muốn.';
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Gửi email reset mật khẩu
  Future<String?> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null; // Thành công
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return 'Không tìm thấy người dùng với email này.';
      }
      return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    } catch (e) {
      return 'Đã xảy ra lỗi không mong muốn.';
    }
  }
}
