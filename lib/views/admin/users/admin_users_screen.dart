// ignore_for_file: unnecessary_const
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../controllers/user_controller.dart';
import '../../../routes/app_routes.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserController>().attachStream();
      }
    });
  }

  /// ---------- Helpers: confirm + re-auth cho thao tác nhạy cảm ----------

  Future<bool> _showConfirmDialog(
      BuildContext context, {
        required String title,
        required String message,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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

  Future<bool> _reauthIfNeeded(BuildContext context) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return false;

    final providers = current.providerData.map((p) => p.providerId).toList();
    final hasPassword = providers.contains('password');
    final hasGoogle = providers.contains('google.com');

    // ----- Email / password -----
    if (hasPassword) {
      final pwdCtl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
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
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pwdCtl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Mật khẩu admin',
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
        return false;
      }

      final pwd = pwdCtl.text.trim();
      if (pwd.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Vui lòng nhập mật khẩu.')),
          );
        }
        return false;
      }

      try {
        final email = current.email;
        if (email == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Tài khoản admin hiện tại không có email/password để xác thực.'),
              ),
            );
          }
          return false;
        }

        final cred =
        EmailAuthProvider.credential(email: email, password: pwd);
        await current.reauthenticateWithCredential(cred);
        return true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Mật khẩu không đúng.')),
          );
        }
        return false;
      }
    }

    // ----- Google Sign-In -----
    if (hasGoogle) {
      try {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                Text('Đã huỷ xác thực Google, thao tác không thực hiện.'),
              ),
            );
          }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('❌ Xác thực Google không thành công.')),
          );
        }
        return false;
      }
    }

    // Provider khác (facebook, anonymous, ...) → đã có confirm nên cho qua
    return true;
  }

  Future<void> _handleToggleBlock(UserAccount u) async {
    final actionText = u.isBlocked ? 'mở khoá' : 'khoá';
    final confirmed = await _showConfirmDialog(
      context,
      title: u.isBlocked ? 'Mở khoá tài khoản' : 'Khoá tài khoản',
      message:
      'Bạn có chắc muốn $actionText tài khoản ${u.name}? Bạn vẫn có thể thay đổi lại sau.',
    );
    if (!confirmed) return;

    final reauthed = await _reauthIfNeeded(context);
    if (!reauthed) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(u.id)
        .update({'isBlocked': !u.isBlocked});

    if (!mounted) return;
    context.read<UserController>().attachStream();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          u.isBlocked ? '✅ Đã mở khoá tài khoản.' : '✅ Đã khoá tài khoản.',
        ),
      ),
    );
  }

  Future<void> _handleDelete(UserAccount u) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Xoá tài khoản',
      message:
      'Thao tác này không thể hoàn tác.\nBạn có chắc muốn xoá tài khoản ${u.name}?',
    );
    if (!confirmed) return;

    final reauthed = await _reauthIfNeeded(context);
    if (!reauthed) return;

    await FirebaseFirestore.instance.collection('users').doc(u.id).delete();

    if (!mounted) return;
    context.read<UserController>().attachStream();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Đã xoá tài khoản.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uc = context.watch<UserController>();
    final users = uc.users;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.primary),
        title: Text(
          'Quản lý người dùng',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: () => uc.attachStream(),
          ),
          IconButton(
            tooltip: 'Thêm người dùng mới',
            icon: const Icon(CupertinoIcons.person_add),
            onPressed: () => _showAddUserDialog(context, uc),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search iOS-style
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              placeholder: 'Tìm theo tên, email hoặc SĐT...',
              onChanged: uc.setKeyword,
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              itemColor: cs.onSurfaceVariant,
              placeholderStyle:
              TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              style: TextStyle(color: cs.onSurface),
            ),
          ),

          Expanded(
            child: uc.isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : users.isEmpty
                ? const _EmptyState()
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: users.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final u = users[index];

                return _UserTile(
                  user: u,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.adminUserDetail,
                    arguments: u,
                  ),
                  onToggleBlock: () => _handleToggleBlock(u),
                  onDelete: () => _handleDelete(u),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- Add user popup (giữ logic) ----------------------
  Future<void> _showAddUserDialog(
      BuildContext context, UserController uc) async {
    final nameCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final emailCtl = TextEditingController();
    String role = 'user';
    final cs = Theme.of(context).colorScheme;

    await showCupertinoModalPopup(
      context: context,
      builder: (popupCtx) {
        // Dùng StatefulBuilder để đổi role và rebuild dropdown
        return StatefulBuilder(
          builder: (ctx, setState) {
            return CupertinoActionSheet(
              title: const Text('Thêm người dùng mới'),
              // để Flutter tự tính chiều cao, nếu thiếu thì cuộn
              message: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoTextField(
                      controller: nameCtl,
                      placeholder: 'Họ và tên',
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      style: TextStyle(color: cs.onSurface),
                      placeholderStyle: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: phoneCtl,
                      placeholder: 'Số điện thoại',
                      keyboardType: TextInputType.phone,
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      style: TextStyle(color: cs.onSurface),
                      placeholderStyle: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: emailCtl,
                      placeholder: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      style: TextStyle(color: cs.onSurface),
                      placeholderStyle: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // Vai trò
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Material(
                        // cung cấp Material ancestor cho DropdownButton
                        color: Colors.transparent,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: role,
                            isExpanded: true,
                            dropdownColor: cs.surface,
                            style: TextStyle(color: cs.onSurface),
                            items: const [
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('Người dùng'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Quản trị viên'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                role = v;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    final phone = phoneCtl.text.trim();
                    final email = emailCtl.text.trim();

                    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text('⚠️ Vui lòng nhập đầy đủ thông tin.'),
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final cred = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                          email: email, password: '123456');
                      final id = cred.user!.uid;

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(id)
                          .set({
                        'id': id,
                        'name': name,
                        'phone': phone,
                        'email': email,
                        'role': role,
                        'isBlocked': false,
                        'createdAt':
                        DateTime.now().millisecondsSinceEpoch,
                      });

                      uc.attachStream();
                      if (mounted) {
                        Navigator.pop(context); // đóng sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '✅ Đã thêm người dùng mới (mật khẩu: 123456)'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                            Text('❌ Lỗi khi tạo người dùng: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================== User Tile mới ==============================
class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
    required this.onToggleBlock,
    required this.onDelete,
  });

  final UserAccount user;
  final VoidCallback onTap;
  final VoidCallback onToggleBlock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF34C759);
    const blockedColor = Color(0xFFFF3B30);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final first = (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase();

    final statusFg = user.isBlocked ? blockedColor : activeColor;
    final statusBg = user.isBlocked
        ? blockedColor.withOpacity(isDark ? 0.18 : 0.12)
        : activeColor.withOpacity(isDark ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(.30)
                : Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: statusBg,
            child: Text(
              first,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email ?? user.phone,
                    style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        user.isBlocked
                            ? CupertinoIcons.xmark_circle_fill
                            : CupertinoIcons.check_mark_circled_solid,
                        size: 16,
                        color: statusFg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.isBlocked ? 'Đã khoá' : 'Hoạt động',
                        style: TextStyle(
                          fontSize: 13,
                          color: statusFg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip:
            user.isBlocked ? 'Mở khoá tài khoản' : 'Khoá tài khoản',
            icon: Icon(
              user.isBlocked ? Icons.lock_open : Icons.lock_outline,
            ),
            color: user.isBlocked ? cs.primary : cs.onSurfaceVariant,
            onPressed: onToggleBlock,
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(Icons.delete_outline),
            color: cs.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ================================ Empty State ================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.person_2_fill,
              size: 70, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            'Chưa có người dùng',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn dấu “+” ở góc phải để thêm người dùng mới',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
