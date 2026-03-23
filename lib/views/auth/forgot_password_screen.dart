import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import 'widgets/luxury_auth_scaffold.dart';
import 'widgets/luxury_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  /// Quay lại màn hình đăng nhập
  void _goBackToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  /// Gửi email khôi phục mật khẩu bằng Firebase Auth
  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final err = await context.read<AuthController>().sendPasswordResetEmail(_emailCtl.text.trim());



    setState(() => _loading = false);
    if (!mounted) return;

    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi email khôi phục mật khẩu.\nVui lòng kiểm tra hộp thư của bạn.',
          ),
        ),
      );
      _goBackToLogin();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryAuthScaffold(
        title: 'Quên mật khẩu',
        subtitle: 'Nhập email để nhận liên kết khôi phục',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              LuxuryLabeledField(
                label: 'Email',
                hint: 'Nhập email đã đăng ký',
                controller: _emailCtl,
                prefixIcon: const Icon(Icons.email_outlined),
                validator: (v) =>
                (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập email'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _reset,
                  child: Text(
                    _loading ? 'Đang gửi...' : 'Gửi yêu cầu',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        // === FOOTER: liên kết quay lại đăng nhập ===
        footer: InkWell(
          onTap: _goBackToLogin,
          child: const Text(
            'Quay lại đăng nhập',
            style: TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
