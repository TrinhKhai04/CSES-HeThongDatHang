import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🟢 Đăng nhập bằng Google (mặc định: nếu có phiên cũ thì vào nhanh)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1️⃣ Chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Người dùng bấm "Hủy"

      // 2️⃣ Lấy token xác thực
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // 3️⃣ Tạo credential cho Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4️⃣ Đăng nhập Firebase
      final userCred = await _auth.signInWithCredential(credential);

      // 5️⃣ Ghi hoặc cập nhật người dùng trong Firestore
      await _saveUserToFirestore(userCred.user);

      return userCred;
    } catch (e) {
      print('❌ Lỗi đăng nhập Google: $e');
      return null;
    }
  }

  /// 🔄 Đăng nhập bằng tài khoản khác (ép mở hộp chọn Account Picker)
  Future<UserCredential?> signInWithAnotherGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      await _saveUserToFirestore(userCred.user);

      return userCred;
    } catch (e) {
      print('❌ Lỗi đăng nhập Google (tài khoản khác): $e');
      return null;
    }
  }

  /// 🟡 Lưu người dùng vào Firestore — giữ nguyên role nếu đã tồn tại
  Future<void> _saveUserToFirestore(User? user) async {
    if (user == null) return;

    final usersRef = FirebaseFirestore.instance.collection('users');
    final docRef = usersRef.doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      // 🆕 Tạo mới nếu chưa có (mặc định user)
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'role': 'user',
        'isBlocked': false,
        'provider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
      print('✅ Đã tạo người dùng Google mới: ${user.email}');
    } else {
      // 🧠 Giữ nguyên role cũ (vd admin)
      final existing = doc.data()!;
      final currentRole = existing['role'] ?? 'user';

      await docRef.set({
        'email': user.email ?? existing['email'],
        'name': user.displayName ?? existing['name'],
        'photoURL': user.photoURL ?? existing['photoURL'],
        'provider': 'google',
        'isBlocked': existing['isBlocked'] ?? false,
        'role': currentRole, // ✅ GIỮ NGUYÊN role
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Cập nhật thông tin Google cho ${user.email} (giữ role=$currentRole)');
    }
  }

  /// 🔴 Đăng xuất khỏi cả Firebase & Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    print('👋 Đã đăng xuất Google + Firebase');
  }

  /// ⚙️ Ngắt kết nối (revoke quyền hoàn toàn)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      await _auth.signOut();
      print('🔒 Đã revoke quyền Google và đăng xuất hoàn toàn');
    } catch (e) {
      print('⚠️ Lỗi khi disconnect Google: $e');
    }
  }
}
