import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_branch_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_user_service.dart';
import 'package:provider/provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final User user;
  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final AppUserService _appUserService = AppUserService();
  final KiotVietBranchService _branchService = KiotVietBranchService();
  final KiotVietUserService _kiotVietUserService = KiotVietUserService();

  late Future<List<KiotVietBranch>> _branchesFuture;
  late Future<List<KiotVietUser>> _kiotVietUsersFuture;

  int? _selectedBranchId;
  int? _selectedKiotVietUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _branchesFuture = _branchService.getBranches();
    _kiotVietUsersFuture = _kiotVietUserService.getUsers();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get branch reference
        final branchDoc = await FirebaseFirestore.instance
            .collection('kiotviet_branches')
            .where('id', isEqualTo: _selectedBranchId)
            .limit(1)
            .get();
        if (branchDoc.docs.isEmpty) {
          throw Exception('Không tìm thấy chi nhánh đã chọn.');
        }
        final branchRef = branchDoc.docs.first.reference;

        // Get KiotViet user reference
        final userDoc = await FirebaseFirestore.instance
            .collection('kiotviet_users')
            .where('id', isEqualTo: _selectedKiotVietUserId)
            .limit(1)
            .get();
        if (userDoc.docs.isEmpty) {
          throw Exception('Không tìm thấy người dùng KiotViet đã chọn.');
        }
        final userRef = userDoc.docs.first.reference;

        // Update the AppUser document
        await _appUserService.updateUserBranch(widget.user.uid, branchRef);
        await _appUserService.updateUserKiotVietUser(widget.user.uid, userRef);

        // No need to call setState for navigation as AuthGate will handle it.
        // Just show a success message.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hồ sơ đã được cập nhật!')),
          );
        }
        // The AuthGate will automatically navigate to the main screen
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lưu hồ sơ: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoàn tất hồ sơ'),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthService>().signOut(),
            child: const Text('Đăng xuất'),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Vui lòng chọn thông tin liên kết cho tài khoản:',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                FutureBuilder<List<KiotVietBranch>>(
                  future: _branchesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Chi nhánh', border: OutlineInputBorder()),
                      items: snapshot.data!.map((branch) => DropdownMenuItem(value: branch.id, child: Text(branch.branchName))).toList(),
                      onChanged: (value) => _selectedBranchId = value,
                      validator: (value) => value == null ? 'Vui lòng chọn chi nhánh' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<KiotVietUser>>(
                  future: _kiotVietUsersFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Người dùng KiotViet', border: OutlineInputBorder()),
                      items: snapshot.data!.map((user) => DropdownMenuItem(value: user.id, child: Text(user.givenName))).toList(),
                      onChanged: (value) => _selectedKiotVietUserId = value,
                      validator: (value) => value == null ? 'Vui lòng chọn người dùng' : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu và tiếp tục'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
