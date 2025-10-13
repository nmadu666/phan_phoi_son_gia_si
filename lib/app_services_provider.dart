import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_data_cache_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/pos_settings_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/store_info_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:phan_phoi_son_gia_si/core/utils/receipt_printer_service.dart';
import 'package:provider/provider.dart';

/// A widget responsible for initializing and providing all core application services.
/// It shows a loading indicator while services are initializing.
class AppServicesProvider extends StatelessWidget {
  final Widget child;

  const AppServicesProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Sử dụng FutureBuilder để xử lý việc khởi tạo bất đồng bộ các service.
    // Nó sẽ hiển thị màn hình tải trong khi chờ, và sau đó cung cấp các service cho ứng dụng.
    return FutureBuilder<List<Object>>(
      future: _initializeServices(),
      builder: (context, snapshot) {
        // While services are initializing, show a loading screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // If initialization fails, show an error screen.
        if (snapshot.hasError) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Text('Lỗi khởi tạo ứng dụng: ${snapshot.error}'),
            ),
          );
        }

        // Once services are initialized, provide them to the app.
        final services = snapshot.data!;
        return MultiProvider(
          providers: [
            // --- Independent Services ---
            Provider.value(value: services[0] as KiotVietOrderService),
            Provider.value(value: services[1] as ReceiptPrinterService),
            ChangeNotifierProvider.value(value: services[2] as AppStateService),
            ChangeNotifierProvider.value(
              value: services[3] as PosSettingsService,
            ),
            ChangeNotifierProvider.value(
              value: services[4] as StoreInfoService,
            ),
            ChangeNotifierProvider.value(
              value: services[5] as KiotVietDataCacheService,
            ),
            ChangeNotifierProvider.value(value: services[6] as AppUserService),

            // --- Dependent Services (using ProxyProvider) ---

            // AuthService depends on AppUserService
            ChangeNotifierProxyProvider<AppUserService, AuthService>(
              create: (context) =>
                  AuthService(appUserService: context.read<AppUserService>()),
              update: (context, appUserService, authService) {
                // This is where you would update AuthService if it depended on a changing value from AppUserService.
                // For this setup, we can return the existing instance.
                return authService ??
                    AuthService(appUserService: appUserService);
              },
            ),

            // TemporaryOrderService depends on AuthService and AppUserService
            ChangeNotifierProxyProvider2<
              AuthService,
              AppUserService,
              TemporaryOrderService
            >(
              create: (context) => TemporaryOrderService(
                authService: context.read<AuthService>(),
                appUserService: context.read<AppUserService>(),
              )..init(), // Call init here for dependent services
              update:
                  (
                    context,
                    authService,
                    appUserService,
                    temporaryOrderService,
                  ) {
                    return temporaryOrderService ??
                        TemporaryOrderService(
                          authService: authService,
                          appUserService: appUserService,
                        );
                  },
            ),
          ],
          child: child,
        );
      },
    );
  }

  /// Initializes all independent services in parallel.
  Future<List<Object>> _initializeServices() async {
    // Create instances
    final kiotVietOrderService = KiotVietOrderService(); // No init
    final receiptPrinterService = ReceiptPrinterService();
    final appStateService = AppStateService();
    final posSettingsService = PosSettingsService();
    final storeInfoService = StoreInfoService();
    final kiotVietDataCacheService = KiotVietDataCacheService();
    final appUserService = AppUserService(); // No async init needed

    // Initialize all services with an `init` method in parallel
    await Future.wait([
      receiptPrinterService.init(),
      appStateService.init(),
      posSettingsService.init(),
      storeInfoService.init(),
      kiotVietDataCacheService.init(),
    ]);

    // Return all created instances in a specific order
    return [
      kiotVietOrderService,
      receiptPrinterService,
      appStateService,
      posSettingsService,
      storeInfoService,
      kiotVietDataCacheService,
      appUserService,
    ];
  }
}
