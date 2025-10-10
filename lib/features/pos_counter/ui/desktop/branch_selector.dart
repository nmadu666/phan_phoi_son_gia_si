import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_branch_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_state_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/temporary_order_service.dart';
import 'package:provider/provider.dart';

class BranchSelector extends StatefulWidget {
  const BranchSelector({super.key});

  @override
  State<BranchSelector> createState() => _BranchSelectorState();
}

class _BranchSelectorState extends State<BranchSelector> {
  final KiotVietBranchService _branchService = KiotVietBranchService();
  late Future<List<KiotVietBranch>> _initializationFuture;

  @override
  void initState() {
    super.initState();
    // Combine all initialization logic into a single future.
    _initializationFuture = _initializeAndGetBranches();
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe thay đổi từ AppStateService để cập nhật UI
    final appState = context.watch<AppStateService>();
    final authService = context.watch<AuthService>();

    if (authService.currentUser == null) {
      return const SizedBox.shrink();
    }

    // Hiển thị loading cho đến khi AppStateService được khởi tạo xong
    if (!appState.isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return FutureBuilder<List<KiotVietBranch>>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final allBranches = snapshot.data!;

        final selectedBranchId = appState.get<int>(
          AppStateService.selectedBranchIdKey,
        );

        final currentBranchName = allBranches
            .firstWhere(
              (b) => b.id == selectedBranchId,
              orElse: () => KiotVietBranch(id: 0, branchName: 'Chọn chi nhánh'),
            )
            .branchName;

        return InkWell(
          onTap: () => _showBranchMenu(context, allBranches),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 20),
                const SizedBox(width: 8),
                Text(currentBranchName),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Initializes the component by fetching all branches and setting the default
  /// selected branch if one isn't already set in the app state.
  /// This ensures all async initialization happens in one place, not in `build`.
  Future<List<KiotVietBranch>> _initializeAndGetBranches() async {
    // Use `WidgetsBinding.instance.addPostFrameCallback` to safely interact
    // with providers after the first frame has been built.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return [];

    try {
      // Fetch all available branches first.
      final allBranches = await _branchService.getBranches();

      if (!mounted) return allBranches;

      final appState = context.read<AppStateService>();
      final appUserService = context.read<AppUserService>();
      final authService = context.read<AuthService>();

      // If no branch is selected in the global state, determine the default one.
      if (appState.get(AppStateService.selectedBranchIdKey) == null &&
          authService.currentUser != null) {
        final appUser = await appUserService.getUser(
          authService.currentUser!.uid,
        );
        final defaultBranch = await appUserService.getBranchFromRef(
          appUser?.kiotvietBranchRef,
        );

        if (mounted && defaultBranch != null) {
          // Set the default branch in the app state.
          // No need to await this, as the FutureBuilder will handle the rebuild.
          appState.set(
            AppStateService.selectedBranchIdKey,
            defaultBranch.id,
            persisted: true,
          );
        }
      }
      return allBranches;
    } catch (e) {
      debugPrint('Error initializing branches: $e');
      // Return an empty list or rethrow to show an error in the UI.
      return [];
    }
  }

  void _showBranchMenu(
    BuildContext context,
    List<KiotVietBranch> allBranches,
  ) async {
    if (!mounted) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    // Hiển thị menu để người dùng chọn
    final selectedBranchId = await showMenu<int>(
      context: context,
      position: position,
      items: allBranches.map((branch) {
        return PopupMenuItem<int>(
          value: branch.id,
          child: Text(branch.branchName),
        );
      }).toList(),
    );

    // Nếu người dùng chọn một chi nhánh mới, kiểm tra giỏ hàng trước khi cập nhật
    if (selectedBranchId != null) {
      final appState = context.read<AppStateService>();
      final currentBranchId = appState.get<int>(
        AppStateService.selectedBranchIdKey,
      );

      // Chỉ xử lý nếu người dùng chọn một chi nhánh khác với chi nhánh hiện tại
      if (selectedBranchId == currentBranchId) {
        return;
      }

      final orderService = context.read<TemporaryOrderService>();
      final activeOrder = orderService.activeOrder;

      bool canSwitch = true;
      // Nếu giỏ hàng có sản phẩm, hiển thị cảnh báo
      if (activeOrder != null && activeOrder.items.isNotEmpty) {
        canSwitch =
            await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Cảnh báo'),
                  content: const Text(
                    'Đơn hàng tạm hiện tại đang có sản phẩm. Bạn có chắc chắn muốn chuyển chi nhánh không?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Hủy'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    FilledButton(
                      child: const Text('Vẫn chuyển'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                );
              },
            ) ??
            false; // Mặc định là không chuyển nếu dialog bị đóng
      }

      if (canSwitch) {
        // Delay the state update to the next frame to avoid conflict with
        // the closing dialog/menu overlays. Using a post-frame callback is safer
        // than Future.delayed(Duration.zero) as it ensures the current frame's
        // build and layout phases are complete.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appState.set(
            AppStateService.selectedBranchIdKey,
            selectedBranchId,
            persisted: true, // Lưu lựa chọn này vào local storage
          );
        });
      }
    }
  }
}
