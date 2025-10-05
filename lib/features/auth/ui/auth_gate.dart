import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/app_user.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/features/auth/ui/login_screen.dart';
import 'package:phan_phoi_son_gia_si/features/auth/ui/profile_setup_screen.dart';
import 'package:phan_phoi_son_gia_si/features/pos_counter/ui/desktop/desktop_layout.dart';
import 'package:provider/provider.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final appUserService = context.read<AppUserService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (authSnapshot.hasData) {
          // User is logged in, now check their Firestore profile.
          return StreamBuilder<AppUser?>(
            stream: appUserService.userStream(authSnapshot.data!.uid),
            builder: (context, appUserSnapshot) {
              if (appUserSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final appUser = appUserSnapshot.data;
              // If profile is complete, show main app. Otherwise, show setup screen.
              return appUserService.isProfileComplete(appUser)
                  ? const DesktopLayout()
                  : ProfileSetupScreen(user: authSnapshot.data!);
            },
          );
        }

        // User is not logged in, show login screen.
        return const LoginScreen();
      },
    );
  }
}
