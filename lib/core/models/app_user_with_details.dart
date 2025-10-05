import 'package:phan_phoi_son_gia_si/core/models/app_user.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';

/// A wrapper class that holds an AppUser and its resolved details.
/// This is useful for displaying detailed information in the UI without
/// needing to perform lookups inside the widget tree.
class AppUserWithDetails {
  final AppUser appUser;
  final KiotVietBranch? linkedBranch;
  final KiotVietUser? linkedKiotVietUser;

  AppUserWithDetails({
    required this.appUser,
    this.linkedBranch,
    this.linkedKiotVietUser,
  });
}
