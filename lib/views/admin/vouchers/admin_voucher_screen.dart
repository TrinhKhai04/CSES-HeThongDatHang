import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminVoucherScreen extends StatelessWidget {
  const AdminVoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('vouchers');

    return Scaffold(
      appBar: AppBar(title: const Text('Khuyến mãi / Voucher')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('startAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Chưa có voucher nào'));
          }

          String fmtMs(int? ms) {
            if (ms == null || ms <= 0) return '—';
            final dt = DateTime.fromMillisecondsSinceEpoch(ms);
            final mm = dt.minute.toString().padLeft(2, '0');
            final hh = dt.hour.toString().padLeft(2, '0');
            final dd = dt.day.toString().padLeft(2, '0');
            final mo = dt.month.toString().padLeft(2, '0');
            return '$dd/$mo/${dt.year} $hh:$mm';
          }

          String vnd(num n) {
            final s = n.toStringAsFixed(0);
            final b = StringBuffer();
            for (int i = 0; i < s.length; i++) {
              final r = s.length - i;
              b.write(s[i]);
              if (r > 1 && r % 3 == 1) b.write(',');
            }
            return '₫${b.toString()}';
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();

              final code = (m['code'] ?? d.id).toString();
              final isPercent = m['isPercent'] == true;
              final discount = (m['discount'] ?? 0);
              final startAt = (m['startAt'] as int?);
              final endAt = (m['endAt'] as int?);
              final desc = (m['description'] ?? '') as String;

              final minSubtotal = (m['minSubtotal'] as num?)?.toDouble();
              final maxDiscount = (m['maxDiscount'] as num?)?.toDouble();

              final active = (m['active'] is bool) ? (m['active'] as bool) : true;

              final used = (m['usedCount'] as int?) ?? 0;
              final qtyLimitRaw = m['qtyLimit'];
              final int? qtyLimit = qtyLimitRaw == null
                  ? null
                  : (qtyLimitRaw is int ? qtyLimitRaw : (qtyLimitRaw as num).toInt());

              int? remaining;
              if (qtyLimit == null || qtyLimit <= 0) {
                remaining = null; // vô hạn
              } else {
                final r = qtyLimit - used;
                remaining = r < 0 ? 0 : r;
              }

              final perUserLimit = (m['perUserLimit'] as int?) ?? 0;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(code, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Switch(
                        value: active,
                        onChanged: (on) {
                          d.reference.set({'active': on}, SetOptions(merge: true));
                        },
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(isPercent
                          ? 'Giảm ${(discount * 100).toStringAsFixed(0)}%'
                          : 'Giảm ${vnd((discount as num).toDouble())}'),
                      if (minSubtotal != null) Text('Đơn tối thiểu: ${vnd(minSubtotal)}'),
                      if (maxDiscount != null && isPercent) Text('Trần giảm: ${vnd(maxDiscount)}'),
                      Text('Hiệu lực: ${fmtMs(startAt)} → ${fmtMs(endAt)}'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (qtyLimit == null || qtyLimit <= 0)
                            const Text('Không giới hạn lượt', style: TextStyle(fontSize: 12))
                          else ...[
                            Text('Đã dùng: $used/$qtyLimit', style: const TextStyle(fontSize: 12)),
                            Text('Còn: ${remaining ?? 0} lượt', style: const TextStyle(fontSize: 12)),
                          ],
                          if (perUserLimit > 0)
                            Text('Mỗi user: $perUserLimit', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                  onTap: () => _openForm(context, col, initial: m),
                  trailing: IconButton(
                    tooltip: 'Xoá',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Xoá voucher?'),
                          content: Text('Bạn chắc chắn xoá "$code"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await d.reference.delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã xoá voucher $code')),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, col),
        label: const Text('Thêm voucher'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // ========= Form tạo/sửa =========
  Future<void> _openForm(
      BuildContext context,
      CollectionReference<Map<String, dynamic>> col, {
        Map<String, dynamic>? initial,
      }) async {
    final isEdit = initial != null;

    final codeCtl = TextEditingController(text: (initial?['code'] ?? '').toString());
    final discountCtl = TextEditingController(text: '${initial?['discount'] ?? ''}');
    final minCtl = TextEditingController(text: '${initial?['minSubtotal'] ?? ''}');
    final maxCtl = TextEditingController(text: '${initial?['maxDiscount'] ?? ''}');
    final descCtl = TextEditingController(text: (initial?['description'] ?? '').toString());

    final qtyCtl = TextEditingController(text: '${initial?['qtyLimit'] ?? ''}');
    final perUserCtl = TextEditingController(text: '${initial?['perUserLimit'] ?? ''}');
    bool active = (initial?['active'] is bool) ? initial!['active'] as bool : true;

    bool isPercent = initial?['isPercent'] == true;
    int? startAt = initial?['startAt'] as int?;
    int? endAt = initial?['endAt'] as int?;

    final oldCode = (initial?['code'] ?? '').toString().toUpperCase();
    final usedOld = (initial?['usedCount'] as int?) ?? 0;
    final qtyOld = (initial?['qtyLimit'] as int?) ?? 0;
    final remainOld = qtyOld <= 0 ? null : (qtyOld - usedOld < 0 ? 0 : qtyOld - usedOld);

    String fmtMs(int? ms) {
      if (ms == null || ms <= 0) return 'Chọn thời gian';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final mm = dt.minute.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$dd/$mo/${dt.year} $hh:$mm';
    }

    Future<int?> pickDateTime(BuildContext ctx, {int? init}) async {
      final now = DateTime.now();
      final initDt = init != null ? DateTime.fromMillisecondsSinceEpoch(init) : now;
      final d = await showDatePicker(
        context: ctx,
        initialDate: initDt,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
      );
      if (d == null) return null;
      final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(initDt));
      if (t == null) return null;
      final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      return dt.millisecondsSinceEpoch;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        void rebuild() => (ctx as Element).markNeedsBuild();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEdit ? 'Sửa voucher' : 'Tạo voucher', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),

                // Thông tin lượt (chỉ hiển thị khi sửa)
                if (isEdit) ...[
                  Wrap(
                    spacing: 12,
                    children: [
                      Text('Đã dùng: $usedOld', style: const TextStyle(fontSize: 12)),
                      Text(
                        qtyOld <= 0 ? 'Không giới hạn lượt' : 'Còn: ${remainOld ?? 0} lượt',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                TextField(
                  controller: codeCtl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã voucher (CODE)',
                    hintText: 'VD: GIAM10K',
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isPercent ? 'Tỷ lệ (0.1 = 10%)' : 'Số tiền (VND)',
                          hintText: isPercent ? '0.05, 0.1, ...' : '20000, 50000, ...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Phần trăm'),
                        Switch(
                          value: isPercent,
                          onChanged: (v) {
                            isPercent = v;
                            rebuild();
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                TextField(
                  controller: minCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Đơn tối thiểu (VND, tuỳ chọn)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Trần giảm tối đa (VND, tuỳ chọn)',
                  ),
                ),
                const SizedBox(height: 8),

                // ===== SỐ LƯỢNG & PER-USER =====
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng toàn hệ thống (tuỳ chọn)',
                          hintText: 'Để trống/0 = không giới hạn',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: perUserCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giới hạn mỗi user (tuỳ chọn)',
                          hintText: 'Để trống/0 = không giới hạn',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final v = await pickDateTime(ctx, init: startAt);
                          if (v != null) {
                            startAt = v;
                            rebuild();
                          }
                        },
                        child: Text('Bắt đầu: ${fmtMs(startAt)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final v = await pickDateTime(ctx, init: endAt);
                          if (v != null) {
                            endAt = v;
                            rebuild();
                          }
                        },
                        child: Text('Kết thúc: ${fmtMs(endAt)}'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả (tuỳ chọn)'),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    const Text('Kích hoạt'),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: (v) {
                        active = v;
                        rebuild();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'Lưu thay đổi' : 'Tạo'),
                  onPressed: () async {
                    final code = codeCtl.text.trim().toUpperCase();
                    final discount = double.tryParse(discountCtl.text.trim()) ?? 0.0;
                    final minSubtotal = double.tryParse(minCtl.text.trim());
                    final maxDiscount = double.tryParse(maxCtl.text.trim());
                    final desc = descCtl.text.trim();
                    final qty = int.tryParse(qtyCtl.text.trim());
                    final perUser = int.tryParse(perUserCtl.text.trim());

                    // Validate
                    if (code.isEmpty) {
                      _toast(ctx, 'Mã không được trống');
                      return;
                    }
                    if (isPercent && (discount <= 0 || discount >= 1)) {
                      _toast(ctx, 'Tỷ lệ phải trong (0, 1). Ví dụ 0.1 = 10%');
                      return;
                    }
                    if (!isPercent && discount <= 0) {
                      _toast(ctx, 'Số tiền giảm phải > 0');
                      return;
                    }
                    if (startAt != null && endAt != null && endAt! <= startAt!) {
                      _toast(ctx, 'Thời gian kết thúc phải sau thời gian bắt đầu');
                      return;
                    }

                    final data = <String, dynamic>{
                      'id': code,
                      'code': code,
                      'discount': discount,
                      'isPercent': isPercent,
                      'description': desc.isEmpty ? null : desc,
                      'startAt': startAt,
                      'endAt': endAt,
                      'minSubtotal': minSubtotal,
                      'maxDiscount': maxDiscount,
                      'active': active,
                      if (qty != null && qty > 0) 'qtyLimit': qty,
                      if (perUser != null && perUser > 0) 'perUserLimit': perUser,
                      if (!isEdit) 'usedCount': 0, // khởi tạo khi tạo mới
                    }..removeWhere((k, v) => v == null);

                    await col.doc(code).set(data, SetOptions(merge: true));
                    if (isEdit && oldCode.isNotEmpty && oldCode != code) {
                      await col.doc(oldCode).delete();
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? 'Đã cập nhật $code' : 'Đã tạo voucher $code'),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }
}
