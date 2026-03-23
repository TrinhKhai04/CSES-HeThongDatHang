import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'users';

  // ==================== GOOGLE SIGN-IN ====================
  Future<User?> signInWithGoogle() async {
    final google = GoogleSignIn(scopes: const ['email']);

    // 1️⃣ Mở chọn tài khoản Google
    final account = await google.signIn();
    if (account == null) return null; // user bấm hủy

    // 2️⃣ Lấy token xác thực
    final gAuth = await account.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // 3️⃣ Đăng nhập Firebase
    final userCred = await _auth.signInWithCredential(cred);
    final user = userCred.user;
    if (user == null) return null;

    // 4️⃣ Tạo hoặc cập nhật profile Firestore (giữ nguyên role cũ)
    final ref = _db.collection(_collection).doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // 🆕 Lần đầu đăng nhập -> tạo profile mặc định
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? '',
        'photoURL': user.photoURL,
        'provider': 'google',
        'role': 'user',
        'isBlocked': false,
        'blockUntil': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'lastLogin': DateTime.now().millisecondsSinceEpoch,
      });
      print("🆕 Tạo mới profile Google cho ${user.email}");
    } else {
      // ✅ Nếu đã tồn tại: không ghi đè role
      final existing = snap.data()!;
      final currentRole = existing['role'] ?? 'user';

      final updatedData = {
        'email': user.email ?? existing['email'],
        'name': user.displayName ?? existing['name'],
        'photoURL': user.photoURL ?? existing['photoURL'],
        'provider': 'google',
        'lastLogin': DateTime.now().millisecondsSinceEpoch,
        'role': currentRole, // ✅ Giữ nguyên quyền cũ
        'isBlocked': existing['isBlocked'] ?? false,
        'blockUntil': existing['blockUntil'],
        'createdAt': existing['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };

      await ref.update(updatedData);
      print("✅ Đăng nhập lại Google cho ${user.email} (giữ role=$currentRole)");
    }

    return user;
  }

  // ==================== EMAIL LOGIN / REGISTER ====================
  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await _db.collection(_collection).doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'phone': phone,
      'name': name,
      'role': 'user',
      'isBlocked': false,
      'blockUntil': null,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return user;
  }

  Future<User?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  // ==================== FIRESTORE PROFILE ====================
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> createProfileIfNotExists({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final ref = _db.collection(_collection).doc(uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set(data);
      print("🆕 Tạo profile mới cho $uid");
    } else {
      final existing = snap.data()!;
      final merged = Map<String, dynamic>.from(existing);
      data.forEach((key, value) {
        if (!merged.containsKey(key) || merged[key] == null) {
          merged[key] = value;
        }
      });
      await ref.set(merged, SetOptions(merge: true));
      print("✅ Giữ nguyên profile, không ghi đè role");
    }
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(_collection).doc(uid).set(data, SetOptions(merge: true));
  }

  // ==================== AUTH HELPERS ====================
  User? get currentUser => _auth.currentUser;

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
