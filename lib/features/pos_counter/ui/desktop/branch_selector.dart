import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
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
  late Future<List<KiotVietBranch>> _branchesFuture;

  @override
  void initState() {
    super.initState();
    _branchesFuture = _branchService.getBranches();
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
      future: _branchesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final allBranches = snapshot.data!;
        _initializeSelectedBranch(context, allBranches);

        final selectedBranchId =
            appState.get<int>(AppStateService.selectedBranchIdKey);

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
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
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

  /// Khởi tạo chi nhánh được chọn.
  /// Ưu tiên lấy từ AppState, nếu không có thì lấy từ AppUser và lưu vào AppState.
  void _initializeSelectedBranch(
      BuildContext context, List<KiotVietBranch> allBranches) async {
    final appState = context.read<AppStateService>();
    final appUserService = context.read<AppUserService>();
    final authService = context.read<AuthService>();

    // Chỉ thực hiện khi chưa có chi nhánh nào được chọn trong AppState
    if (appState.get(AppStateService.selectedBranchIdKey) == null &&
        authService.currentUser != null) {
      final appUser = await appUserService.getUser(authService.currentUser!.uid);
      final defaultBranch = await appUserService.getBranchFromRef(appUser?.kiotvietBranchRef);
      if (defaultBranch != null) {
        // Dùng `persisted: true` để lưu lại cho lần mở app sau
        appState.set(AppStateService.selectedBranchIdKey, defaultBranch.id, persisted: true);
      }
    }
  }

  void _showBranchMenu(BuildContext context, List<KiotVietBranch> allBranches) async {
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
      final currentBranchId =
          appState.get<int>(AppStateService.selectedBranchIdKey);

      // Chỉ xử lý nếu người dùng chọn một chi nhánh khác với chi nhánh hiện tại
      if (selectedBranchId == currentBranchId) {
        return;
      }

      final orderService = context.read<TemporaryOrderService>();
      final activeOrder = orderService.orders.firstWhere(
        (o) => o.id == orderService.activeOrderId,
        orElse: () => TemporaryOrder(id: '', name: ''),
      );

      bool canSwitch = true;
      // Nếu giỏ hàng có sản phẩm, hiển thị cảnh báo
      if (activeOrder.items.isNotEmpty) {
        canSwitch = await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Cảnh báo'),
                  content: const Text(
                      'Đơn hàng tạm hiện tại đang có sản phẩm. Bạn có chắc chắn muốn chuyển chi nhánh không?'),
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
        appState.set(
          AppStateService.selectedBranchIdKey,
          selectedBranchId,
          persisted: true, // Lưu lựa chọn này vào local storage
        );
      }
    }
  }
}
