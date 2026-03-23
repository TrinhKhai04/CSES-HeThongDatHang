import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _obscure1 = true, _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _newCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  void _show(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final newPass = _newCtl.text.trim();
    final confirm = _confirmCtl.text.trim();

    if (newPass.length < 6) { _show('Mật khẩu phải ≥ 6 ký tự'); return; }
    if (newPass != confirm) { _show('Xác nhận mật khẩu không khớp'); return; }

    setState(() => _loading = true);
    try {
      final msg = await context.read<AuthController>().updatePassword(newPass);
      if (!mounted) return;
      if (msg == null) {
        _show('✅ Đổi mật khẩu thành công');
        Navigator.pop(context);
      } else if (msg.contains('requires-recent-login')) {
        _show('Phiên đăng nhập đã cũ. Hãy đăng nhập lại rồi thử đổi mật khẩu.');
      } else {
        _show('❌ $msg');
      }
    } catch (e) {
      _show('❌ Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _newCtl,
            obscureText: _obscure1,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              labelText: 'Xác nhận mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.check),
            label: Text(_loading ? 'Đang đổi…' : 'Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }
}
