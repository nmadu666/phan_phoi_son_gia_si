import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/store_info_service.dart';
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

  final storeInfoService = StoreInfoService();
  await storeInfoService.init();

  final temporaryOrderService = TemporaryOrderService(
    authService: authService,
    appUserService: appUserService,
  );
  await temporaryOrderService.init();

  runApp(
    MultiProvider(
      providers: [
        // Các service không có trạng thái hoặc không cần khởi tạo async
        Provider(create: (_) => KiotVietOrderService()),
        Provider.value(
          value: appUserService,
        ), // Hoặc Provider(create: (_) => appUserService)
        ChangeNotifierProvider.value(value: appStateService),
        ChangeNotifierProvider.value(value: posSettingsService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: storeInfoService),
        ChangeNotifierProvider.value(value: temporaryOrderService),
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
