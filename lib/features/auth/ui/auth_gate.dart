import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/features/auth/ui/login_screen.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/desktop/desktop_layout.dart';
import 'package:provider/provider.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Nếu người dùng đã đăng nhập, hiển thị màn hình chính
        return snapshot.hasData ? const DesktopLayout() : const LoginScreen();
      },
    );
  }
}

