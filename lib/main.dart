import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/pos_settings_service.dart';
import 'package:phan_phoi_son_gia_si/features/auth/ui/auth_gate.dart';
import 'package:provider/provider.dart';
import 'package:phan_phoi_son_gia_si/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi tạo các service có trạng thái và cần tải dữ liệu bất đồng bộ
  final appStateService = AppStateService();
  await appStateService.init();

  final posSettingsService = PosSettingsService();
  await posSettingsService.init();

  final authService = AuthService();
  final appUserService = AppUserService();

  final temporaryOrderService = TemporaryOrderService(
    authService: authService,
    appUserService: appUserService,
  );
  await temporaryOrderService.init();

  runApp(
    MultiProvider(
      providers: [
        // Các service không có trạng thái hoặc không cần khởi tạo async
        Provider<KiotVietOrderService>(create: (_) => KiotVietOrderService()),
        Provider.value(value: appUserService),

        // Các service đã được khởi tạo, cung cấp instance bằng .value
        ChangeNotifierProvider.value(value: appStateService),
        ChangeNotifierProvider.value(value: posSettingsService),
        ChangeNotifierProvider.value(value: authService),

        // Sử dụng ProxyProvider để cập nhật dependency khi authService thay đổi
        ChangeNotifierProxyProvider<AuthService, TemporaryOrderService>(
          // Cung cấp instance đã được khởi tạo ban đầu
          create: (_) => temporaryOrderService,
          // Khi authService thay đổi (ví dụ: đăng nhập/đăng xuất),
          // cập nhật lại dependency cho temporaryOrderService.
          update: (_, auth, previous) =>
 previous!..updateDependencies(authService: auth, appUserService: appUserService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phân Phối Sơn Giá Sỉ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home:
          const AuthGate(), // Sử dụng AuthGate để kiểm tra trạng thái đăng nhập
    );
  }
}
