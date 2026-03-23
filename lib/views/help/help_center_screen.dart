import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';
  String _cat = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() => setState(() => _query = _searchCtl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // ----- data -----
  static const _cats = [
    'Tất cả',
    'Đơn hàng',
    'Thanh toán',
    'Đổi trả / Bảo hành',
    'Tài khoản',
    'Khác',
  ];

  final List<_Faq> _faqs = const [
    _Faq('Tôi có thể đổi trả trong bao lâu?',
        'Bạn có 7 ngày kể từ khi nhận hàng để yêu cầu đổi trả với điều kiện sản phẩm còn nguyên tem mác, đầy đủ phụ kiện.',
        'Đổi trả / Bảo hành'),
    _Faq('Làm sao theo dõi trạng thái đơn hàng?',
        'Vào mục “Đơn hàng của tôi” trong ứng dụng để xem lộ trình hoặc kiểm tra email/SMS đã gửi.',
        'Đơn hàng'),
    _Faq('Hình thức thanh toán hỗ trợ?',
        'Chúng tôi hỗ trợ COD, chuyển khoản, thẻ nội địa/quốc tế và các ví điện tử phổ biến.',
        'Thanh toán'),
    _Faq('Khi nào tôi nhận được hoàn tiền?',
        'Hoàn tiền sẽ xử lý trong 1–3 ngày làm việc sau khi xác nhận hủy/đổi trả thành công.',
        'Thanh toán'),
    _Faq('Phí vận chuyển được tính như thế nào?',
        'Phí hiển thị ở bước thanh toán. Miễn phí nội thành với đơn từ 300.000₫.',
        'Đơn hàng'),
    _Faq('Sản phẩm có bảo hành không?',
        'Có. Sản phẩm chính hãng có bảo hành theo chính sách nhà sản xuất (thường 6–12 tháng).',
        'Đổi trả / Bảo hành'),
    _Faq('Tôi nhập mã giảm giá không được?',
        'Kiểm tra điều kiện áp dụng (giỏ tối thiểu, ngành hàng, hạn dùng). Nếu vẫn lỗi, hãy gửi yêu cầu hỗ trợ.',
        'Khác'),
    _Faq('Làm sao liên hệ nhanh với CSKH?',
        'Bạn có thể email support@cses.store hoặc tạo “Yêu cầu hỗ trợ” bên dưới.',
        'Khác'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // filter
    final list = _faqs.where((f) {
      final q = _query.toLowerCase();
      final okText = q.isEmpty || f.q.toLowerCase().contains(q) || f.a.toLowerCase().contains(q);
      final okCat = _cat == 'Tất cả' || f.cat == _cat;
      return okText && okCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm trợ giúp'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // ---------- search ----------
          TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'Tìm câu hỏi (ví dụ: đổi trả, thanh toán...)',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- contact quick ----------
          const _SectionHeader('Liên hệ nhanh'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.email_rounded,
                  title: 'Email hỗ trợ',
                  subtitle: 'support@cses.store',
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: 'support@cses.store'));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép email hỗ trợ')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactCard(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'Hotline',
                  subtitle: '+84 9xx xxx xxx',
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: '+84 9xx xxx xxx'));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép số hotline')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- category chips ----------
          // ---------- category chips ----------
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cats.map((c) {
              final selected = _cat == c;
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _cat = c),
                showCheckmark: false,
                shape: const StadiumBorder(),
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),


          // ---------- FAQ ----------
          const _SectionHeader('Câu hỏi thường gặp'),
          const SizedBox(height: 8),
          if (list.isEmpty)
            _EmptyState(
              title: 'Không tìm thấy nội dung phù hợp',
              tip: 'Bạn có thể gửi yêu cầu hỗ trợ để chúng tôi phản hồi sớm.',
            )
          else
            _FaqList(list: list),

          const SizedBox(height: 20),

          // ---------- CTA ----------
          FilledButton.icon(
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Gửi yêu cầu hỗ trợ'),
            onPressed: () => _openSupportForm(context),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.confirmation_num_outlined),
            label: const Text('Xem yêu cầu của tôi'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.myTickets),
          ),
        ],
      ),
    );
  }

  void _openSupportForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SupportFormSheet(),
    );
  }
}

// ===== UI parts =====

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 20,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface, // tránh bị mờ
            ),
          ),
        ],
      ),
    );
  }
}


class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 96, // đồng nhất chiều cao
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis, // không xuống dòng xấu
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _FaqList extends StatelessWidget {
  final List<_Faq> list;
  const _FaqList({required this.list});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(list.length, (i) {
        final f = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: Icon(Icons.help_outline, color: cs.primary),
              title: Text(f.q, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(f.cat, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              children: [Text(f.a)],
            ),
          ),
        );
      }),
    );
  }
}


class _EmptyState extends StatelessWidget {
  final String title;
  final String tip;
  const _EmptyState({required this.title, required this.tip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(tip, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Support form sheet =====

class _SupportFormSheet extends StatefulWidget {
  const _SupportFormSheet();

  @override
  State<_SupportFormSheet> createState() => _SupportFormSheetState();
}

class _SupportFormSheetState extends State<_SupportFormSheet> {
  final _form = GlobalKey<FormState>();
  final _subjectCtl = TextEditingController();
  final _messageCtl = TextEditingController();
  final _orderCtl = TextEditingController();
  String _category = 'Đơn hàng';

  @override
  void dispose() {
    _subjectCtl.dispose();
    _messageCtl.dispose();
    _orderCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final profile = auth.profile;

    final email = (user?.email ?? profile?['email'] ?? '').toString();
    final name = (profile?['name'] ?? user?.displayName ?? 'Khách hàng').toString();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tạo yêu cầu hỗ trợ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                items: const [
                  'Đơn hàng',
                  'Thanh toán',
                  'Đổi trả / Bảo hành',
                  'Tài khoản',
                  'Khác',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtl,
                decoration: const InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtl,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Nội dung mô tả',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Vui lòng mô tả tối thiểu 10 ký tự'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orderCtl,
                decoration: const InputDecoration(labelText: 'Mã đơn (nếu có)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Gửi'),
                      onPressed: () async {
                        if (!_form.currentState!.validate()) return;

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          await FirebaseFirestore.instance.collection('support_tickets').add({
                            'userId': user?.uid ?? '',
                            'email': email,
                            'name': name,
                            'category': _category,
                            'subject': _subjectCtl.text.trim(),
                            'message': _messageCtl.text.trim(),
                            'orderId': _orderCtl.text.trim(),
                            'status': 'open',
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context); // loading
                            Navigator.pop(context); // sheet
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã gửi yêu cầu, chúng tôi sẽ phản hồi sớm!')),
                            );
                            Navigator.pushNamed(context, AppRoutes.myTickets);
                          }
                        } catch (e) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi gửi yêu cầu: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== model =====
class _Faq {
  final String q;
  final String a;
  final String cat;
  const _Faq(this.q, this.a, this.cat);
}
