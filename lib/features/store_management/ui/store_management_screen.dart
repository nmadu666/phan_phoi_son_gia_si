import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/store_info.dart';
import 'package:phan_phoi_son_gia_si/core/services/store_info_service.dart';
import 'package:phan_phoi_son_gia_si/features/store_management/ui/dialogs/edit_store_dialog.dart';
import 'package:provider/provider.dart';

class StoreManagementScreen extends StatelessWidget {
  const StoreManagementScreen({super.key});

  // Chuyển thành async để có thể chờ dialog đóng lại
  Future<void> _showEditDialog(BuildContext context, {StoreInfo? store}) async {
    // Chờ dialog trả về kết quả. Nếu là `true`, nghĩa là đã lưu thành công.
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EditStoreDialog(store: store),
    );
    // Nếu lưu thành công, thông báo cho các listener để cập nhật lại UI.
    if (result == true && context.mounted) {
      context.read<StoreInfoService>().forceReload();
    }
  }

  Future<void> _deleteStore(BuildContext context, StoreInfo store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa cửa hàng "${store.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<StoreInfoService>().deleteStore(store.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa cửa hàng thành công.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa cửa hàng: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeService = context.watch<StoreInfoService>();
    final stores = storeService.stores;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Cửa hàng')),
      body: ListView.builder(
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          ImageProvider? backgroundImage;
          if (store.logoUrl != null && store.logoUrl!.isNotEmpty) {
            if (store.logoUrl!.startsWith('http')) {
              backgroundImage = NetworkImage(store.logoUrl!);
            } else {
              backgroundImage = AssetImage(store.logoUrl!);
            }
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: backgroundImage,
                child: backgroundImage == null ? const Icon(Icons.store) : null,
              ),
              title: Text(
                store.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(store.address),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Chỉnh sửa',
                    onPressed: () => _showEditDialog(context, store: store),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Xóa',
                    onPressed: () => _deleteStore(context, store),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context),
        tooltip: 'Thêm cửa hàng mới',
        child: const Icon(Icons.add),
      ),
    );
  }
}
