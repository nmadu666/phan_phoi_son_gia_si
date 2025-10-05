import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phan_phoi_son_gia_si/core/models/app_user.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/auth_service.dart';
import 'package:phan_phoi_son_gia_si/core/services/kiotviet_branch_service.dart';
import 'package:provider/provider.dart';

class BranchSelector extends StatefulWidget {
  const BranchSelector({super.key});

  @override
  State<BranchSelector> createState() => _BranchSelectorState();
}

class _BranchSelectorState extends State<BranchSelector> {
  final AppUserService _appUserService = AppUserService();
  final KiotVietBranchService _branchService = KiotVietBranchService();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<AppUser?>(
      stream: _appUserService.userStream(currentUser.uid),
      builder: (context, appUserSnapshot) {
        if (!appUserSnapshot.hasData) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final appUser = appUserSnapshot.data!;
        final currentBranchRef = appUser.kiotvietBranchRef;

        return FutureBuilder<KiotVietBranch?>(
          future: _fetchBranchDetails(currentBranchRef),
          builder: (context, branchSnapshot) {
            final currentBranchName =
                branchSnapshot.data?.branchName ?? 'Đang tải...';

            return InkWell(
              onTap: () => _showBranchMenu(context, appUser),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: Row(
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
      },
    );
  }

  Future<KiotVietBranch?> _fetchBranchDetails(
    DocumentReference? branchRef,
  ) async {
    if (branchRef == null) return null;
    try {
      final doc = await branchRef.get();
      if (doc.exists) {
        return KiotVietBranch.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
    } catch (e) {
      print("Error fetching branch details: $e");
    }
    return null;
  }

  void _showBranchMenu(BuildContext context, AppUser appUser) async {
    final allBranches = await _branchService.getBranches();
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

    if (selectedBranchId != null) {
      try {
        final branchDoc = await FirebaseFirestore.instance
            .collection('kiotviet_branches')
            .where('id', isEqualTo: selectedBranchId)
            .limit(1)
            .get();
        if (branchDoc.docs.isNotEmpty) {
          await _appUserService.updateUserBranch(
            appUser.uid,
            branchDoc.docs.first.reference,
          );
        }
      } catch (e) {
        print("Error updating user branch: $e");
      }
    }
  }
}
