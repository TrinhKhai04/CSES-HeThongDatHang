// ignore_for_file: unnecessary_const
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../controllers/user_controller.dart';

/// ============================================================================
/// 🍏 AdminUserDetailScreen – Màn hình chi tiết người dùng
/// ----------------------------------------------------------------------------
/// ✅ Phong cách iOS, tự thích ứng Dark/Light
/// ✅ KHÔNG đổi logic Firestore/Auth
/// ============================================================================
class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  // 🌱 Biến tạm để lưu thông tin chỉnh sửa
  String? _newName;
  String? _newPhone;
  String? _newEmail;
  String? _newRole;

  @override
  Widget build(BuildContext context) {
    // Nhận dữ liệu truyền qua route (UserAccount hoặc userID)
    final arg = ModalRoute.of(context)!.settings.arguments;
    final uc = context.watch<UserController>();
    final UserAccount? user = arg is UserAccount ? arg : null;

    // ====== Dark/Light tokens ======
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final surface = CupertinoColors.systemBackground.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Scaffold(
      backgroundColor: bg, // trước đây: const Color(0xFFF9F9FB)
      appBar: AppBar(
        backgroundColor: surface, // trước đây: Colors.white
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: label), // trước đây: Colors.black87
        title: Text(
          user?.name ?? 'Chi tiết người dùng',
          style: TextStyle(
            color: label, // trước đây: Colors.black
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),

      // 🕓 Dùng Stream để lắng nghe thay đổi realtime từ Firestore
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.id ?? (arg as String))
            .snapshots(),
        builder: (context, snap) {
          // Hiển thị vòng xoay khi đang tải
          if (!snap.hasData) {
            return const Center(child: CupertinoActivityIndicator(radius: 14));
          }

          // Nếu không tồn tại document
          final doc = snap.data!;
          if (!doc.exists) {
            return const Center(child: Text('Không tìm thấy người dùng'));
          }

          // Parse Firestore → Model
          final u = UserAccount.fromDoc(doc);

          // ✅ Lưu giá trị mặc định nếu chưa có
          _newName ??= u.name;
          _newPhone ??= u.phone;
          _newEmail ??= u.email ?? '';
          _newRole ??= u.role;

          // Lấy chữ cái đầu tên (để hiển thị avatar)
          final first = (u.name.isNotEmpty ? u.name[0] : '?').toUpperCase();

          // 📅 Xử lý hiển thị trạng thái khoá tài khoản
          String statusText = u.isBlocked ? 'Đã khóa' : 'Hoạt động';
          if (u.blockUntil != null &&
              u.blockUntil! > DateTime.now().millisecondsSinceEpoch) {
            final remain = Duration(
              milliseconds: u.blockUntil! - DateTime.now().millisecondsSinceEpoch,
            );
            final h = remain.inHours;
            final m = remain.inMinutes.remainder(60);
            statusText = 'Khóa tạm ${h > 0 ? "$h giờ " : ""}${m > 0 ? "$m phút" : ""}';
          }

          // ===================== Giao diện chính =====================
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // 🧩 1️⃣ Thông tin cơ bản (avatar, tên, email)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _appleCardStyle(context), // đổi để tự thích ứng
                child: Row(
                  children: [
                    // 👤 Avatar tròn hiển thị ký tự đầu tên
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: u.isBlocked
                          ? const Color(0x33FF3B30) // đỏ nhạt (alpha 0x33)
                          : const Color(0x3334C759), // xanh nhạt
                      child: Text(
                        first,
                        style: TextStyle(
                          fontSize: 26,
                          color: u.isBlocked
                              ? const Color(0xFFFF3B30)
                              : const Color(0xFF34C759),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // 👇 Thông tin chính
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: label)),
                          const SizedBox(height: 4),
                          Text(u.email ?? '—', style: TextStyle(color: secondary)),
                          Text(u.phone, style: TextStyle(color: secondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 🧾 2️⃣ Chi tiết tài khoản (vai trò, trạng thái, ngày tạo)
              _buildInfoCard(context, 'Chi tiết tài khoản', [
                _InfoRow(label: 'Vai trò', value: u.role),
                _InfoRow(label: 'Trạng thái', value: statusText),
                if (u.createdAt != null)
                  _InfoRow(
                    label: 'Ngày tạo',
                    value: DateTime.fromMillisecondsSinceEpoch(u.createdAt!)
                        .toString()
                        .substring(0, 16),
                  ),
              ]),
              const SizedBox(height: 18),

              // 📝 3️⃣ Chỉnh sửa thông tin người dùng
              _buildEditCard(context, uc, u),
              const SizedBox(height: 18),

              // 🔒 4️⃣ Khóa / Mở khóa tài khoản
              _buildBlockCard(context, uc, u),
              const SizedBox(height: 18),

              // 🗑️ 5️⃣ Xoá người dùng
              _buildDeleteCard(context, uc, u),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 🍏 CARD HIỂN THỊ THÔNG TIN
  // ===========================================================================
  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    final dividerColor = Theme.of(context).colorScheme.outlineVariant;
    final titleColor = CupertinoColors.label.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _appleCardStyle(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: titleColor,
              )),
          Divider(height: 20, thickness: 0.6, color: dividerColor),
          ...children,
        ],
      ),
    );
  }

  // ===========================================================================
  // 🧩 CARD CHỈNH SỬA THÔNG TIN NGƯỜI DÙNG
  // ===========================================================================
  Widget _buildEditCard(BuildContext context, UserController uc, UserAccount u) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _appleCardStyle(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chỉnh sửa thông tin',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: CupertinoColors.label.resolveFrom(context),
              )),
          Divider(
            height: 20,
            thickness: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _buildTextField(context, 'Họ và tên', _newName!, (v) {
            setState(() => _newName = v);
          }),
          const SizedBox(height: 8),
          _buildTextField(context, 'Số điện thoại', _newPhone!, (v) {
            setState(() => _newPhone = v);
          }),
          const SizedBox(height: 8),
          _buildTextField(context, 'Email', _newEmail!, (v) {
            setState(() => _newEmail = v);
          }),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _newRole,
            items: const [
              DropdownMenuItem(value: 'user', child: Text('Người dùng')),
              DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
            ],
            decoration: InputDecoration(
              labelText: 'Vai trò',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            onChanged: (role) => setState(() => _newRole = role),
          ),
          const SizedBox(height: 12),
          // ✅ Nút lưu thay đổi (kiểu iOS)
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: () async {
              await uc.updateUser(u.id, {
                'name': _newName,
                'phone': _newPhone,
                'email': _newEmail,
                'role': _newRole,
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Đã lưu thay đổi thông tin người dùng'),
                  ),
                );
              }
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🔒 CARD KHÓA / MỞ KHÓA NGƯỜI DÙNG
  // ===========================================================================
  Widget _buildBlockCard(BuildContext context, UserController uc, UserAccount u) {
    const activeColor = Color(0xFF34C759); // Xanh Apple
    const redColor = Color(0xFFFF3B30);   // Đỏ Apple

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _appleCardStyle(context),
      child: u.isBlocked
      // 👉 Nếu đang bị khoá → hiển thị nút mở khoá
          ? CupertinoButton.filled(
        borderRadius: BorderRadius.circular(10),
        color: activeColor,
        onPressed: () async {
          await uc.updateUser(u.id, {'isBlocked': false, 'blockUntil': null});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Đã mở khóa tài khoản thành công!')),
            );
          }
        },
        child: const Text('Mở khóa tài khoản ngay'),
      )
      // 👉 Nếu chưa bị khoá → hiển thị lựa chọn khoá tạm / vĩnh viễn
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khóa tài khoản',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: CupertinoColors.label.resolveFrom(context),
              )),
          Divider(
            height: 20,
            thickness: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: 'Thời hạn khóa tạm thời',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 giờ')),
              DropdownMenuItem(value: 6, child: Text('6 giờ')),
              DropdownMenuItem(value: 12, child: Text('12 giờ')),
              DropdownMenuItem(value: 24, child: Text('1 ngày')),
            ],
            onChanged: (hours) async {
              if (hours == null) return;
              final until = DateTime.now().add(Duration(hours: hours)).millisecondsSinceEpoch;
              await uc.updateUser(u.id, {'isBlocked': true, 'blockUntil': until});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🚫 Đã khóa tài khoản trong $hours giờ')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            color: redColor,
            borderRadius: BorderRadius.circular(10),
            onPressed: () async {
              await uc.updateUser(u.id, {'isBlocked': true, 'blockUntil': null});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🚫 Đã khóa vĩnh viễn tài khoản!')),
                );
              }
            },
            child: const Text('Khóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ❌ CARD XOÁ NGƯỜI DÙNG (Cupertino AlertDialog)
  // ===========================================================================
  Widget _buildDeleteCard(BuildContext context, UserController uc, UserAccount u) {
    const redColor = Color(0xFFFF3B30);

    return CupertinoButton(
      borderRadius: BorderRadius.circular(10),
      color: redColor.withOpacity(0.12), // nhẹ nhàng ở cả Dark/Light
      onPressed: () async {
        final ok = await showCupertinoDialog<bool>(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Xóa người dùng?', style: TextStyle(color: redColor)),
            content: const Text(
              'Hành động này không thể hoàn tác.\nNgười dùng sẽ bị xóa khỏi Firestore.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Hủy'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Xác nhận xóa'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
        if (ok == true) {
          await uc.deleteUser(u.id);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: redColor,
                content: Text('🗑️ Đã xóa người dùng'),
              ),
            );
          }
        }
      },
      child: const Text(
        'Xóa người dùng',
        style: TextStyle(color: redColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ===========================================================================
  // 🧱 TextField cơ bản (bo tròn, nền tự đổi theo theme)
  // ===========================================================================
  Widget _buildTextField(
      BuildContext context,
      String label,
      String value,
      Function(String) onChanged,
      ) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        filled: true,
        fillColor: cs.surfaceContainerLowest, // auto Dark/Light
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
      ),
      onChanged: onChanged,
    );
  }

  // 🎨 Style dùng chung cho Card Apple Style — auto Dark/Light
  BoxDecoration _appleCardStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = CupertinoColors.systemBackground.resolveFrom(context);

    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cs.outlineVariant),
      boxShadow: isDark
          ? const [] // Dark: bỏ bóng cho đỡ “mốc”
          : const [
        BoxShadow(
          color: Color(0x1A000000), // 10% đen
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }
}

// ============================================================================
// 🍏 InfoRow – Một dòng hiển thị nhãn & giá trị (vai trò, trạng thái,...)
// ============================================================================
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final valueColor = CupertinoColors.label.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: titleColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
