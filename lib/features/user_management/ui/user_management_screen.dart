import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/app_user_with_details.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_branch_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_user_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AppUserService _appUserService = AppUserService();
  final KiotVietBranchService _branchService = KiotVietBranchService();
  final KiotVietUserService _kiotVietUserService = KiotVietUserService();

  late Future<List<AppUserWithDetails>> _usersFuture;
  late Future<List<KiotVietBranch>> _branchesFuture;
  late Future<List<KiotVietUser>> _kiotVietUsersFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _usersFuture = _appUserService.getUsersWithDetails();
    _branchesFuture = _branchService.getBranches();
    _kiotVietUsersFuture = _kiotVietUserService.getUsers();
  }

  void _refreshData() {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: FutureBuilder<List<AppUserWithDetails>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có người dùng nào.'));
          }

          final users = snapshot.data!;

          return FutureBuilder(
            future: Future.wait([_branchesFuture, _kiotVietUsersFuture]),
            builder: (context, dropdownSnapshot) {
              if (dropdownSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allBranches = dropdownSnapshot.data?[0] as List<KiotVietBranch>? ?? [];
              final allKiotVietUsers = dropdownSnapshot.data?[1] as List<KiotVietUser>? ?? [];

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDetails = users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userDetails.appUser.displayName ?? userDetails.appUser.email ?? 'N/A',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(userDetails.appUser.email ?? 'Không có email'),
                          const SizedBox(height: 16),
                          _buildBranchDropdown(userDetails, allBranches),
                          const SizedBox(height: 12),
                          _buildKiotVietUserDropdown(userDetails, allKiotVietUsers),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBranchDropdown(
      AppUserWithDetails userDetails, List<KiotVietBranch> allBranches) {
    return DropdownButtonFormField<int?>(
      initialValue: userDetails.linkedBranch?.id,
      decoration: const InputDecoration(
        labelText: 'Chi nhánh KiotViet',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      // Add a null option to allow un-linking
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Chưa liên kết', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        ...allBranches.map((branch) {
          return DropdownMenuItem<int?>(
            value: branch.id,
            child: Text(branch.branchName),
          );
        }),
      ],
      onChanged: (branchId) async {
        DocumentReference? newRef;
        if (branchId != null) {
          // Find the document reference for the selected branch ID
          final branchDoc = await _firestore
              .collection('kiotviet_branches')
              .where('id', isEqualTo: branchId)
              .limit(1)
              .get();
          if (branchDoc.docs.isNotEmpty) {
            newRef = branchDoc.docs.first.reference;
          }
        }
        await _appUserService.updateUserBranch(userDetails.appUser.uid, newRef);
        _refreshData(); // Refresh UI to show changes
      },
    );
  }

  Widget _buildKiotVietUserDropdown(
      AppUserWithDetails userDetails, List<KiotVietUser> allKiotVietUsers) {
    return DropdownButtonFormField<int?>(
      initialValue: userDetails.linkedKiotVietUser?.id,
      decoration: const InputDecoration(
        labelText: 'Người dùng KiotViet',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Chưa liên kết', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        ...allKiotVietUsers.map((user) {
          return DropdownMenuItem<int?>(
            value: user.id,
            child: Text(user.givenName),
          );
        }),
      ],
      onChanged: (userId) async {
        DocumentReference? newRef;
        if (userId != null) {
          final userDoc = await _firestore
              .collection('kiotviet_users')
              .where('id', isEqualTo: userId)
              .limit(1)
              .get();
          if (userDoc.docs.isNotEmpty) {
            newRef = userDoc.docs.first.reference;
          }
        }
        await _appUserService.updateUserKiotVietUser(userDetails.appUser.uid, newRef);
        _refreshData();
      },
    );
  }

  // Helper to get firestore instance, as it's not directly available in the state
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
}
