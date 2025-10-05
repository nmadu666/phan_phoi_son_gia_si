import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:phan_phoi_son_gia_si/core/models/app_user.dart';
import 'package:phan_phoi_son_gia_si/core/models/app_user_with_details.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_branch.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_user.dart';

class AppUserService {
  final FirebaseFirestore _firestore;

  AppUserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<AppUser> get _usersCollection => _firestore
      .collection('users')
      .withConverter<AppUser>(
        fromFirestore: (snapshot, _) => AppUser.fromFirestore(snapshot),
        toFirestore: (user, _) => user.toFirestore(),
      );

  /// Retrieves a stream of the AppUser document from Firestore.
  Stream<AppUser?> userStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) => doc.data());
  }

  /// Retrieves a single AppUser document from Firestore.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.data();
  }

  /// Checks if the user's profile is complete.
  bool isProfileComplete(AppUser? user) {
    return user != null &&
        user.kiotvietBranchRef != null &&
        user.kiotvietUserRef != null;
  }

  /// Fetches all AppUsers and resolves their linked KiotViet branch and user details.
  Future<List<AppUserWithDetails>> getUsersWithDetails() async {
    final usersSnapshot = await _usersCollection.get();
    final List<AppUserWithDetails> detailedUsers = [];

    for (final userDoc in usersSnapshot.docs) {
      final appUser = userDoc.data();
      KiotVietBranch? branch;
      KiotVietUser? kiotvietUser;

      // Resolve KiotViet Branch
      if (appUser.kiotvietBranchRef != null) {
        branch = await getBranchFromRef(appUser.kiotvietBranchRef);
      }

      // Resolve KiotViet User
      if (appUser.kiotvietUserRef != null) {
        final userDoc = await appUser.kiotvietUserRef!.get();
        if (userDoc.exists) {
          kiotvietUser = KiotVietUser.fromFirestore(
            userDoc as DocumentSnapshot<Map<String, dynamic>>,
          );
        }
      }

      detailedUsers.add(
        AppUserWithDetails(
          appUser: appUser,
          linkedBranch: branch,
          linkedKiotVietUser: kiotvietUser,
        ),
      );
    }

    return detailedUsers;
  }

  /// Fetches KiotVietBranch details from a DocumentReference.
  Future<KiotVietBranch?> getBranchFromRef(DocumentReference? branchRef) async {
    if (branchRef == null) return null;
    try {
      final doc = await branchRef.get();
      if (doc.exists) {
        return KiotVietBranch.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
    } catch (e) {
      print("Error fetching branch details from reference: $e");
    }
    return null;
  }

  /// Fetches KiotVietUser details from a DocumentReference.
  Future<KiotVietUser?> getUserFromRef(DocumentReference? userRef) async {
    if (userRef == null) return null;
    try {
      final doc = await userRef.get();
      if (doc.exists) {
        return KiotVietUser.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
    } catch (e) {
      print("Error fetching KiotViet user details from reference: $e");
    }
    return null;
  }

  /// Updates the linked KiotViet branch for a specific AppUser.
  Future<void> updateUserBranch(
    String uid,
    DocumentReference? branchRef,
  ) async {
    await _usersCollection.doc(uid).update({'kiotvietBranchRef': branchRef});
  }

  /// Updates the linked KiotViet user for a specific AppUser.
  Future<void> updateUserKiotVietUser(
    String uid,
    DocumentReference? userRef,
  ) async {
    await _usersCollection.doc(uid).update({'kiotvietUserRef': userRef});
  }

  /// Creates or updates a user document in Firestore when a user signs in.
  /// This ensures that every Firebase Auth user has a corresponding document
  /// in the 'users' collection.
  /// It also attempts to automatically link the AppUser to a KiotVietUser based on email
  /// if the link does not already exist.
  Future<void> createOrUpdateUserDocument(auth.User firebaseUser) async {
    final userDocRef = _usersCollection.doc(firebaseUser.uid);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      // Document does not exist, create it for the first time.
      DocumentReference? kiotvietUserRef;
      if (firebaseUser.email != null) {
        try {
          final kiotvietUserQuery = await _firestore
              .collection('kiotviet_users')
              .where('userName', isEqualTo: firebaseUser.email!.toLowerCase())
              .limit(1)
              .get();
          if (kiotvietUserQuery.docs.isNotEmpty) {
            kiotvietUserRef = kiotvietUserQuery.docs.first.reference;
          }
        } catch (e) {
          print('Error trying to auto-link KiotViet user on creation: $e');
        }
      }
      // Create the AppUser object and set it.
      final newUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
        kiotvietUserRef: kiotvietUserRef,
      );
      // newUser.role = 'sale'; // Gán vai trò mặc định là 'sale'
      await userDocRef.set(newUser);
    } else {
      // Document exists, just update basic info.
      // The auto-linking logic is only for the initial creation.
      // Manual linking is done via the UserManagementScreen.
      await userDocRef.update({
        'email': firebaseUser.email,
        'displayName': firebaseUser.displayName,
      });
    }
  }
}
