import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  User? _firebaseUser;
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _firebaseUser;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _profile?['role'] == 'admin';
  bool get isLoggedIn => _firebaseUser != null;

  // ============================ RESTORE SESSION ============================
  Future<void> restore() async {
    _setLoading(true);
    try {
      if (kDebugMode) print("🔁 [AuthController] Restoring Firebase session...");
      _firebaseUser = _repo.currentUser;
      if (_firebaseUser == null) return;

      _profile = await _repo.getProfile(_firebaseUser!.uid);
      if (_profile == null) return;

      final blockUntil = _profile?['blockUntil'];
      if (blockUntil != null && blockUntil is int) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now >= blockUntil) {
          await _repo.updateProfile(_firebaseUser!.uid, {
            'isBlocked': false,
            'blockUntil': null,
          });
          _profile?['isBlocked'] = false;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', _firebaseUser!.uid);
      await prefs.setString('role', _profile?['role'] ?? 'user');

      print("✅ Restored session: ${_firebaseUser!.email}, role=${_profile?['role']}");
    } catch (e) {
      print("❌ Restore error: $e");
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================ LOGIN ============================
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      _firebaseUser = await _repo.login(email, password);
      if (_firebaseUser == null) return false;

      _profile = await _repo.getProfile(_firebaseUser!.uid);
      if (_profile?['isBlocked'] == true) {
        _errorMessage = 'Tài khoản bị khóa';
        await _repo.logout();
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', _firebaseUser!.uid);
      await prefs.setString('role', _profile?['role'] ?? 'user');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================ REGISTER ============================
  Future<String?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _setLoading(true);
    try {
      _firebaseUser = await _repo.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      _profile = await _repo.getProfile(_firebaseUser!.uid);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', _firebaseUser!.uid);
      await prefs.setString('role', _profile?['role'] ?? 'user');
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================ GOOGLE LOGIN ============================
  Future<void> loadCurrentUser() async {
    try {
      _setLoading(true);
      _firebaseUser = FirebaseAuth.instance.currentUser;
      if (_firebaseUser == null) return;

      final snap = await _repo.getProfile(_firebaseUser!.uid);

      if (snap != null && snap.isNotEmpty) {
        _profile = snap;
        await _repo.updateProfile(_firebaseUser!.uid, {
          'name': _firebaseUser!.displayName ?? snap['name'],
          'photoURL': _firebaseUser!.photoURL ?? snap['photoURL'],
          'email': _firebaseUser!.email ?? snap['email'],
          'provider': 'google',
          'lastLogin': DateTime.now().millisecondsSinceEpoch,
          'role': snap['role'] ?? 'user', // ✅ Giữ nguyên role cũ
        });
      } else {
        final newProfile = {
          'uid': _firebaseUser!.uid,
          'email': _firebaseUser!.email,
          'name': _firebaseUser!.displayName ?? '',
          'photoURL': _firebaseUser!.photoURL ?? '',
          'role': 'user',
          'isBlocked': false,
          'provider': 'google',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'lastLogin': DateTime.now().millisecondsSinceEpoch,
        };
        await _repo.createProfileIfNotExists(uid: _firebaseUser!.uid, data: newProfile);
        _profile = newProfile;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', _firebaseUser!.uid);
      await prefs.setString('role', _profile?['role'] ?? 'user');

      print("✅ [AuthController] loadCurrentUser OK: ${_firebaseUser!.email} (role=${_profile?['role']})");
    } catch (e) {
      print("❌ [AuthController] loadCurrentUser error: $e");
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================ PROFILE ============================
  Future<void> refreshProfile() async {
    if (_firebaseUser == null) return;
    _profile = await _repo.getProfile(_firebaseUser!.uid);
    notifyListeners();
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _repo.updateProfile(uid, data);
    await refreshProfile();
  }

  Future<String?> updatePassword(String newPassword) async {
    if (newPassword.length < 6) return 'Mật khẩu mới phải ≥ 6 ký tự';
    try {
      await _repo.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Mật khẩu quá yếu';
        case 'requires-recent-login':
          return 'Phiên đăng nhập đã cũ, vui lòng đăng nhập lại rồi thử đổi.';
        default:
          return e.message ?? 'Không thể đổi mật khẩu';
      }
    } catch (e) {
      return e.toString();
    }
  }


  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _repo.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ============================ LOGOUT ============================
  Future<void> logout() async {
    await _repo.logout();
    _firebaseUser = null;
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
    await prefs.remove('role');
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
