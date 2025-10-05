import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user of this application, stored in the 'users' collection in Firestore.
/// This model links the Firebase Auth user to their specific KiotViet data references.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final DocumentReference? kiotvietBranchRef;
  final DocumentReference? kiotvietUserRef;
  final String? code; // For filtering data, e.g., customers by salesperson code
  final String? role; // For role-based access control, e.g., 'admin', 'sale'

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.kiotvietBranchRef,
    this.kiotvietUserRef,
    this.code,
    this.role,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'],
      displayName: data['displayName'],
      kiotvietBranchRef: data['kiotvietBranchRef'] as DocumentReference?,
      kiotvietUserRef: data['kiotvietUserRef'] as DocumentReference?,
      code: data['code'],
      role: data['role'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (kiotvietBranchRef != null) 'kiotvietBranchRef': kiotvietBranchRef,
      if (kiotvietUserRef != null) 'kiotvietUserRef': kiotvietUserRef,
      if (code != null) 'code': code,
      if (role != null) 'role': role,
    };
  }
}
