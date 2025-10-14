import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:phan_phoi_son_gia_si/features/auth/ui/auth_gate.dart';
import 'package:phan_phoi_son_gia_si/firebase_options.dart';

import 'app_services_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Bọc MaterialApp bằng AppServicesProvider để các service có thể được truy cập
    // từ bất kỳ đâu trong ứng dụng, bao gồm cả các dialog và route mới.
    return AppServicesProvider(
      child: MaterialApp(
        title: 'Phân Phối Sơn Giá Sỉ',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        // AuthGate giờ là home của MaterialApp
        home: const AuthGate(),
      ),
    );
  }
}
