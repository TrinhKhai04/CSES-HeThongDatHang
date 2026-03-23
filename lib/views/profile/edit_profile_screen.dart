import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart'; // ⬅️ dùng để fallback về profile

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    final user = auth.profile;
    _nameCtl.text = (user?['name'] ?? '').toString();
    _phoneCtl.text = (user?['phone'] ?? '').toString();
    _addressCtl.text = (user?['address'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();
    if (auth.user == null) return;

    setState(() => _saving = true);
    await auth.updateProfile(auth.user!.uid, {
      'name': _nameCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
      'address': _addressCtl.text.trim(),
    });
    if (!mounted) return;

    setState(() => _saving = false);
    _safeBack(); // 🔙
  }

  void _safeBack() {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    } else {
      // Fallback: khi màn này là route đầu (mở bằng pushReplacement / deeplink)
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Back hệ thống (Android/Web) → hành vi giống nút back
      onWillPop: () async {
        _safeBack();
        return false; // chặn pop mặc định vì ta đã xử lý
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Quay lại',
            onPressed: _safeBack, // ✅ dùng fallback an toàn
          ),
          title: const Text('Chỉnh sửa thông tin'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    prefixIcon: Icon(Icons.home),
                  ),
                  onSubmitted: (_) => _saveChanges(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveChanges,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
