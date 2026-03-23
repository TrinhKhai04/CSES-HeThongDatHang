import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/cart_controller.dart'; // <-- quan trọng
import '../../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // 👇 Đợi build xong frame đầu tiên rồi mới chạy _initApp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    try {
      final authController = context.read<AuthController>();

      // Khôi phục session Firebase (nếu có)
      await authController.restore();

      // Chờ 1 chút để hiển thị loading (tuỳ ý)
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Chưa đăng nhập
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // ĐÃ đăng nhập -> gắn giỏ hàng theo UID và khôi phục từ Firestore
      await context.read<CartController>().attachToUser(user.uid);

      if (!mounted) return;

      // Điều hướng theo vai trò
      if (authController.isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.adminRoot);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.root);
      }
    } catch (e) {
      // Nếu có lỗi bất ngờ, chuyển về login để tránh treo
      if (!mounted) return;
      debugPrint('[Splash] init error: $e');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }
}
