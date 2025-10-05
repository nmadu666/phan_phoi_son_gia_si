import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/pos_settings_service.dart';
import 'package:phan_phoi_son_gia_si/features/auth/ui/auth_gate.dart';
import 'package:provider/provider.dart';
import 'package:phan_phoi_son_gia_si/firebase_options.dart';

void main() async {
  // Đảm bảo Flutter binding đã được khởi tạo.
  // Đây là bước bắt buộc khi hàm main là một async function.
  WidgetsFlutterBinding.ensureInitialized();

  // Chờ cho Firebase khởi tạo xong trước khi chạy ứng dụng.
  // Điều này đảm bảo mọi lệnh gọi đến Firebase sau đó đều hợp lệ.
  // `DefaultFirebaseOptions.currentPlatform` sẽ tự động chọn cấu hình
  // phù hợp cho web, android, ios, v.v.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        Provider<AppUserService>(create: (_) => AppUserService()),
        ChangeNotifierProvider(create: (_) => AppStateService()),
        ChangeNotifierProvider(create: (context) => AuthService()),
        // TemporaryOrderService depends on Auth and AppUser services to set the default seller.
        ChangeNotifierProxyProvider<AuthService, TemporaryOrderService>(
          create: (context) => TemporaryOrderService(
            appUserService: context.read<AppUserService>(),
            authService: context.read<AuthService>(),
          ),
          update: (context, auth, previous) {
            // When auth state changes, update the dependencies in TemporaryOrderService.
            // This is useful if a new user logs in.
            previous?.updateDependencies(
              appUserService: context.read<AppUserService>(),
              authService: auth,
            );
            return previous!;
          },
        ),
        ChangeNotifierProvider(create: (context) => PosSettingsService()),
        // Thêm các provider khác ở đây nếu cần
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
      title: 'POS Ngành Sơn',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home:
          const AuthGate(), // Sử dụng AuthGate để kiểm tra trạng thái đăng nhập
    );
  }
}
