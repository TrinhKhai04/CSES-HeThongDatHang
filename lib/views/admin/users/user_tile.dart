import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../controllers/user_controller.dart';

/// Hiển thị 1 người dùng trong danh sách — style gọn, auto Dark/Light.
class UserTile extends StatelessWidget {
  final UserAccount user;
  final VoidCallback onTap;
  final VoidCallback onToggleBlock;
  final VoidCallback onDelete;

  const UserTile({
    super.key,
    required this.user,
    required this.onTap,
    required this.onToggleBlock,
    required this.onDelete,
  });

  /// Bước 1: hỏi confirm thao tác (luôn luôn hiển thị)
  Future<bool> _showConfirmDialog(
      BuildContext context, {
        required String title,
        required String message,
      }) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    ) ??
        false;
    return ok;
  }

  /// Bước 2: sau khi confirm, re-auth nếu có thể
  Future<bool> _reauthIfNeeded(BuildContext context) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return false;

    final cs = Theme.of(context).colorScheme;
    final providers = current.providerData.map((p) => p.providerId).toList();
    final hasPassword = providers.contains('password');
    final hasGoogle = providers.contains('google.com');

    // ========== Case: email / password ==========
    if (hasPassword) {
      final pwdCtl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Xác thực lại'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhập lại mật khẩu admin để tiếp tục.',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pwdCtl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu admin',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          );
        },
      ) ??
          false;

      if (!ok) {
        pwdCtl.dispose();
        return false;
      }

      final pwd = pwdCtl.text.trim();
      pwdCtl.dispose();
      if (pwd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Vui lòng nhập mật khẩu.')),
        );
        return false;
      }

      try {
        final email = current.email;
        if (email == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                Text('Tài khoản admin hiện tại không có email/password.')),
          );
          return false;
        }

        final cred = EmailAuthProvider.credential(
          email: email,
          password: pwd,
        );
        await current.reauthenticateWithCredential(cred);
        return true;
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Mật khẩu không đúng.')),
        );
        return false;
      }
    }

    // ========== Case: Google Sign-In ==========
    if (hasGoogle) {
      try {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Đã huỷ xác thực Google.')),
          );
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await current.reauthenticateWithCredential(credential);
        return true;
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('❌ Xác thực Google không thành công.')),
        );
        return false;
      }
    }

    // ========== Fallback: provider khác (facebook, anon, ...) ==========
    // Không re-auth được, nhưng tới đây là đã có confirm dialog rồi.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final first = (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase();

    const appleGreen = Color(0xFF34C759);
    final statusFg = user.isBlocked ? cs.error : appleGreen;
    final statusBg = user.isBlocked
        ? cs.error.withOpacity(isDark ? 0.18 : 0.12)
        : appleGreen.withOpacity(isDark ? 0.18 : 0.12);

    return ListTile(
      tileColor: cs.surface,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: cs.surfaceContainerHighest,
        child: Text(
          first,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.isBlocked ? 'Đã khóa' : 'Hoạt động',
              style: TextStyle(
                color: statusFg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${user.phone}  •  ${user.email ?? "—"}  •  ${user.role}',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: user.isBlocked ? 'Mở khóa' : 'Khóa tài khoản',
            icon: Icon(user.isBlocked ? Icons.lock_open : Icons.lock_outline),
            color: user.isBlocked ? cs.primary : cs.onSurfaceVariant,
            onPressed: () async {
              // 1) confirm thao tác
              final confirmed = await _showConfirmDialog(
                context,
                title:
                user.isBlocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
                message:
                'Xác nhận ${user.isBlocked ? "mở khóa" : "khóa"} tài khoản ${user.name}.',
              );
              if (!confirmed) return;

              // 2) re-auth
              final reauthed = await _reauthIfNeeded(context);
              if (reauthed) onToggleBlock();
            },
          ),
          IconButton(
            tooltip: 'Xóa',
            icon: const Icon(Icons.delete_outline),
            color: cs.error,
            onPressed: () async {
              // 1) confirm thao tác
              final confirmed = await _showConfirmDialog(
                context,
                title: 'Xoá tài khoản',
                message:
                'Thao tác này không thể hoàn tác.\nBạn có chắc muốn xoá tài khoản ${user.name}?',
              );
              if (!confirmed) return;

              // 2) re-auth
              final reauthed = await _reauthIfNeeded(context);
              if (reauthed) onDelete();
            },
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}
