import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/google_auth_controller.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _googleLoading = false;
  bool _googleOtherLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _idCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Email + Password
  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthController>();
    final ok = await auth.login(_idCtl.text.trim(), _passCtl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pushReplacementNamed(
        context,
        auth.isAdmin ? AppRoutes.adminRoot : AppRoutes.root,
      );
    } else {
      final msg = auth.errorMessage ?? 'Sai tài khoản hoặc mật khẩu';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  // Google login (lấy role từ Firestore)
  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    final google = GoogleAuthController();

    final userCred = await google.signInWithGoogle();
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    final auth = context.read<AuthController>();
    await auth.loadCurrentUser();

    setState(() => _googleLoading = false);

    if (userCred != null && auth.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đăng nhập Google thành công (${auth.profile?['role']})',
          ),
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        auth.isAdmin ? AppRoutes.adminRoot : AppRoutes.root,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập Google thất bại')),
      );
    }
  }

  // Google khác
  Future<void> _loginWithAnotherGoogle() async {
    setState(() => _googleOtherLoading = true);
    final google = GoogleAuthController();
    await google.signOut();

    final userCred = await google.signInWithGoogle();
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    final auth = context.read<AuthController>();
    await auth.loadCurrentUser();

    setState(() => _googleOtherLoading = false);

    if (userCred != null && auth.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đăng nhập thành công (${auth.profile?['role']})',
          ),
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        auth.isAdmin ? AppRoutes.adminRoot : AppRoutes.root,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập Google thất bại')),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    final double maxWidth = width > 480 ? 420 : 480;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // Phần form cho phép scroll
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header tối giản kiểu Apple
                          Text(
                            'Chào mừng trở lại',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CSES',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2563EB),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Card form phẳng, viền mảnh
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Label nhỏ
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Tài khoản',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _idCtl,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      prefixIcon:
                                      Icon(Icons.alternate_email_outlined),
                                      hintText: 'Email hoặc số điện thoại',
                                    ),
                                    validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Vui lòng nhập tài khoản'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),

                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Mật khẩu',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passCtl,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _doLogin(),
                                    decoration: InputDecoration(
                                      prefixIcon:
                                      const Icon(Icons.lock_outline),
                                      hintText: 'Nhập mật khẩu',
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                              () => _obscure = !_obscure,
                                        ),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) =>
                                    (v == null || v.length < 6)
                                        ? 'Mật khẩu ≥ 6 ký tự'
                                        : null,
                                  ),

                                  const SizedBox(height: 18),

                                  // Nút đăng nhập
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _doLogin,
                                      child: Text(
                                        _loading
                                            ? 'Đang đăng nhập…'
                                            : 'Đăng nhập',
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Nút Google chuẩn thương hiệu (nền trắng, viền mảnh)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: _googleLoading
                                          ? null
                                          : _loginWithGoogle,
                                      icon: _googleLoading
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : Image.asset(
                                        'assets/google_logo.png',
                                        height: 22,
                                      ),
                                      label: Text(
                                        _googleLoading
                                            ? 'Đang đăng nhập...'
                                            : 'Đăng nhập bằng Google',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black87,
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Google khác (link màu primary)
                                  TextButton(
                                    onPressed: _googleOtherLoading
                                        ? null
                                        : _loginWithAnotherGoogle,
                                    child: _googleOtherLoading
                                        ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : Text(
                                      'Đăng nhập bằng tài khoản Google khác',
                                      style: TextStyle(
                                        color: cs.primary,
                                        decoration:
                                        TextDecoration.underline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  // Quên mật khẩu
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.forgotPassword,
                                    ),
                                    child: const Text('Quên mật khẩu'),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Đăng ký
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Chưa có tài khoản?',
                                style: theme.textTheme.bodyMedium,
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.register,
                                ),
                                child: Text(
                                  'Đăng ký',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Badge version ở cuối màn hình
                const SizedBox(height: 4),
                const AppVersionBadge(compact: true),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget hiển thị version app (lấy từ pubspec.yaml)
class AppVersionBadge extends StatefulWidget {
  final bool compact; // true: chỉ hiện v1.0.0, false: kèm build number

  const AppVersionBadge({super.key, this.compact = false});

  @override
  State<AppVersionBadge> createState() => _AppVersionBadgeState();
}

class _AppVersionBadgeState extends State<AppVersionBadge> {
  String? _versionText;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version;
      final build = info.buildNumber;

      setState(() {
        _versionText =
        widget.compact ? 'v$version' : 'v$version ($build)';
      });
    } catch (_) {
      // Nếu lỗi thì không hiển thị gì
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_versionText == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final secondary =
        theme.textTheme.bodySmall?.color ?? cs.onSurface.withOpacity(0.6);

    // Badge kiểu Apple: pill sáng, gradient rất nhẹ, shadow mỏng
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface.withOpacity(0.9),
            cs.surfaceVariant.withOpacity(0.7),
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.8),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // “Logo” tròn nhỏ
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary.withOpacity(0.4),
                width: 0.7,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'C',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'CSES',
            style: TextStyle(
              fontSize: 11.5,
              color: secondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '•',
            style: TextStyle(
              fontSize: 11,
              color: secondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _versionText!,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
