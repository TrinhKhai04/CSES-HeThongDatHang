// lib/views/admin/xu/admin_xu_minigame_stats_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';
import 'xu_minigame_stats_card.dart';

class AdminXuMiniGameStatsScreen extends StatelessWidget {
  const AdminXuMiniGameStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    // Responsive max width cho nội dung ở giữa
    final double maxContentWidth;
    if (width >= 1200) {
      maxContentWidth = 640;
    } else if (width >= 800) {
      maxContentWidth = 560;
    } else if (width >= 600) {
      maxContentWidth = 520;
    } else {
      maxContentWidth = width; // mobile: full width (vẫn có padding 16)
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Thống kê mini-game Xu'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            onSelected: (value) {
              if (value == 'wheel') {
                _showWheelConfigSheet(context);
              } else if (value == 'slot') {
                _showSlotConfigSheet(context);
              } else if (value == 'lottery') {
                _openXuLotteryAdmin(context);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'wheel',
                child: Text('Cấu hình tỉ lệ Vòng quay Xu'),
              ),
              PopupMenuItem(
                value: 'slot',
                child: Text('Cấu hình payout Máy xèng CSES'),
              ),
              PopupMenuItem(
                value: 'lottery',
                child: Text('Quản lý Xổ số Xu CSES'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              cs.surfaceVariant.withOpacity(0.35),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Nội dung chính cuộn được
                Expanded(
                  child: ListView(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      XuMiniGameStatsCard(
                        onOpenWheelConfig: () => _showWheelConfigSheet(context),
                        onOpenSlotConfig: () => _showSlotConfigSheet(context),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Nút quản lý Xổ số Xu, dính đáy, bo tròn đẹp hơn
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                        ),
                        onPressed: () => _openXuLotteryAdmin(context),
                        icon: const Icon(
                          Icons.confirmation_number_outlined,
                          size: 20,
                        ),
                        label: const Text(
                          'Quản lý Xổ số Xu CSES',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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

/// Điều hướng sang AdminXuLotteryScreen, truyền adminId hiện tại
void _openXuLotteryAdmin(BuildContext context) {
  final auth = context.read<AuthController>();
  final adminId = auth.user?.uid ?? '';

  Navigator.of(context).pushNamed(
    AppRoutes.adminXuLottery,
    arguments: {'adminId': adminId},
  );
}

///////////////////////////////////////////////////////////////////////////////
// Bottom sheet: cấu hình tỉ lệ thưởng Vòng quay Xu
///////////////////////////////////////////////////////////////////////////////

void _showWheelConfigSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _WheelConfigSheet(),
  );
}

class _WheelRewardForm {
  int amount;
  int weight;

  _WheelRewardForm({required this.amount, required this.weight});
}

class _WheelConfigSheet extends StatefulWidget {
  const _WheelConfigSheet();

  @override
  State<_WheelConfigSheet> createState() => _WheelConfigSheetState();
}

class _WheelConfigSheetState extends State<_WheelConfigSheet> {
  bool _loading = true;
  bool _saving = false;
  List<_WheelRewardForm> _rewards = [];

  int get _totalWeight =>
      _rewards.fold<int>(0, (sum, r) => sum + (r.weight > 0 ? r.weight : 0));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('wheel')
          .get();
      final data = doc.data();
      if (data != null && data['rewards'] is List) {
        final tmp = <_WheelRewardForm>[];
        for (final item in (data['rewards'] as List)) {
          if (item is Map) {
            final amount = (item['amount'] as num?)?.toInt() ?? 0;
            final weight = (item['weight'] as num?)?.toInt() ?? 0;
            if (amount > 0 && weight > 0) {
              tmp.add(_WheelRewardForm(amount: amount, weight: weight));
            }
          }
        }
        if (tmp.isNotEmpty) {
          _rewards = tmp;
        }
      }

      if (_rewards.isEmpty) {
        _rewards = [
          _WheelRewardForm(amount: 50, weight: 50),
          _WheelRewardForm(amount: 100, weight: 30),
          _WheelRewardForm(amount: 200, weight: 15),
          _WheelRewardForm(amount: 500, weight: 5),
        ];
      }
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cleaned = _rewards
          .where((r) => r.amount > 0 && r.weight > 0)
          .map((r) => {'amount': r.amount, 'weight': r.weight})
          .toList();

      await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('wheel')
          .set(
        {
          'rewards': cleaned,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cấu hình Vòng quay Xu.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu cấu hình: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  String _weightPercentText(int w) {
    final total = _totalWeight;
    if (total <= 0 || w <= 0) return '';
    final p = w * 100 / total;
    return '≈ ${p.toStringAsFixed(1)}%';
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Giải thích tỉ lệ thưởng'),
          content: const SingleChildScrollView(
            child: Text(
              '• Thưởng (Xu): số Xu người chơi nhận được khi trúng ô đó.\n'
                  '• Trọng số: càng lớn thì ô đó càng dễ xuất hiện khi quay.\n'
                  '• Tỉ lệ ≈ (Trọng số / Tổng trọng số). Tổng trọng số không cần = 100.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            top: 12,
            left: 16,
            right: 16,
          ),
          child: _loading
              ? const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          )
              : Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cấu hình tỉ lệ thưởng – Vòng quay Xu',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Tooltip(
                    message:
                    'Giải thích về Trọng số, tỉ lệ và cách tính xác suất.',
                    child: IconButton(
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                      ),
                      onPressed: _showHelpDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Điều chỉnh danh sách phần thưởng và trọng số tương ứng.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Σ Trọng số: $_totalWeight',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00695C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Không cần = 100%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding:
                        const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Thưởng (Xu)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                      cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Trọng số',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                      cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    'Tỉ lệ',
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                      cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ..._buildRewardFields(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _rewards.length >= 6
                        ? null
                        : () {
                      setState(() {
                        _rewards.add(
                          _WheelRewardForm(
                              amount: 0, weight: 0),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm mốc thưởng'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    )
                        : const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRewardFields() {
    final cs = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    for (int i = 0; i < _rewards.length; i++) {
      final r = _rewards[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: r.amount.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thưởng (Xu)',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim()) ?? 0;
                      _rewards[i] = _WheelRewardForm(
                        amount: parsed,
                        weight: _rewards[i].weight,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: r.weight.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Trọng số',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim()) ?? 0;
                      _rewards[i] = _WheelRewardForm(
                        amount: _rewards[i].amount,
                        weight: parsed,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _weightPercentText(r.weight),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Xóa',
                      onPressed: _rewards.length <= 1
                          ? null
                          : () {
                        setState(() {
                          _rewards.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

///////////////////////////////////////////////////////////////////////////////
// Bottom sheet: Cấu hình payout Máy xèng CSES
///////////////////////////////////////////////////////////////////////////////

void _showSlotConfigSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SlotConfigSheet(),
  );
}

class _SlotTierForm {
  int multiplier;
  int weight;

  _SlotTierForm({required this.multiplier, required this.weight});
}

class _SlotSymbolWeightForm {
  final String key;
  final String label;
  int weight;

  _SlotSymbolWeightForm({
    required this.key,
    required this.label,
    required this.weight,
  });
}

class _SlotConfigSheet extends StatefulWidget {
  const _SlotConfigSheet();

  @override
  State<_SlotConfigSheet> createState() => _SlotConfigSheetState();
}

class _SlotConfigSheetState extends State<_SlotConfigSheet> {
  bool _loading = true;
  bool _saving = false;
  List<_SlotTierForm> _tiers = [];
  List<_SlotSymbolWeightForm> _symbolWeightsForms = [];
  int _minMatchToWin = 3;
  int _jackpotThreshold = 15;

  int get _totalWeight =>
      _tiers.fold<int>(0, (sum, r) => sum + (r.weight > 0 ? r.weight : 0));

  double get _estimatedRtp {
    final total = _totalWeight;
    if (total <= 0) return 0;
    double expectedMultiplier = 0;
    for (final t in _tiers) {
      if (t.weight <= 0) continue;
      expectedMultiplier += (t.multiplier * t.weight) / total;
    }
    return expectedMultiplier * 100;
  }

  List<_SlotSymbolWeightForm> _defaultSymbolForms() {
    return [
      _SlotSymbolWeightForm(
        key: 'seven',
        label: 'Số 7 may mắn (7️⃣)',
        weight: 2,
      ),
      _SlotSymbolWeightForm(
        key: 'money',
        label: 'Túi tiền (💰)',
        weight: 3,
      ),
      _SlotSymbolWeightForm(
        key: 'star',
        label: 'Ngôi sao (⭐)',
        weight: 4,
      ),
      _SlotSymbolWeightForm(
        key: 'cherry',
        label: 'Cherry (🍒)',
        weight: 5,
      ),
      _SlotSymbolWeightForm(
        key: 'lemon',
        label: 'Lemon (🍋)',
        weight: 5,
      ),
      _SlotSymbolWeightForm(
        key: 'bell',
        label: 'Chuông vàng (🔔)',
        weight: 3,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('slot')
          .get();
      final data = doc.data();

      _symbolWeightsForms = _defaultSymbolForms();

      if (data != null) {
        _minMatchToWin =
            (data['minMatchToWin'] as num?)?.toInt() ?? 3;
        _jackpotThreshold =
            (data['jackpotMultiplierThreshold'] as num?)?.toInt() ?? 15;

        if (data['tiers'] is List) {
          final tmp = <_SlotTierForm>[];
          for (final item in (data['tiers'] as List)) {
            if (item is Map) {
              final mul = (item['multiplier'] as num?)?.toInt() ?? 0;
              final w = (item['weight'] as num?)?.toInt() ?? 0;
              if (mul >= 0 && w > 0) {
                tmp.add(_SlotTierForm(multiplier: mul, weight: w));
              }
            }
          }
          if (tmp.isNotEmpty) _tiers = tmp;
        }

        final rawSymbolWeights = data['symbolWeights'];
        if (rawSymbolWeights is Map<String, dynamic>) {
          _symbolWeightsForms = _defaultSymbolForms().map((form) {
            final w = (rawSymbolWeights[form.key] as num?)?.toInt();
            return _SlotSymbolWeightForm(
              key: form.key,
              label: form.label,
              weight: w != null && w >= 0 ? w : form.weight,
            );
          }).toList();
        }
      }

      if (_tiers.isEmpty) {
        _tiers = [
          _SlotTierForm(multiplier: 0, weight: 40),
          _SlotTierForm(multiplier: 2, weight: 30),
          _SlotTierForm(multiplier: 5, weight: 20),
          _SlotTierForm(multiplier: 10, weight: 9),
          _SlotTierForm(multiplier: 50, weight: 1),
        ];
      }
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cleaned = _tiers
          .where((t) => t.multiplier >= 0 && t.weight > 0)
          .map((t) => {
        'multiplier': t.multiplier,
        'weight': t.weight,
      })
          .toList();

      final symbolWeightsMap = <String, int>{};
      for (final s in _symbolWeightsForms) {
        if (s.weight >= 0) {
          symbolWeightsMap[s.key] = s.weight;
        }
      }

      await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('slot')
          .set(
        {
          'tiers': cleaned,
          'minMatchToWin': _minMatchToWin,
          'jackpotMultiplierThreshold': _jackpotThreshold,
          'symbolWeights': symbolWeightsMap,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cấu hình Máy xèng CSES.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu cấu hình: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  String _weightPercentText(int w) {
    final total = _totalWeight;
    if (total <= 0 || w <= 0) return '';
    final p = w * 100 / total;
    return '≈ ${p.toStringAsFixed(1)}%';
  }

  void _showSectionHelp(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            top: 12,
            left: 16,
            right: 16,
          ),
          child: _loading
              ? const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          )
              : Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cấu hình payout – Máy xèng CSES',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Tooltip(
                    message:
                    'Giải thích chi tiết về luật thắng, biểu tượng và multiplier.',
                    child: IconButton(
                      icon: const Icon(Icons.info_outline_rounded),
                      onPressed: () => _showSectionHelp(
                        'Giải thích cấu hình Máy xèng',
                        '• Luật thắng cơ bản: quy định bao nhiêu ô trùng thì được trả thưởng, '
                            'và multiplier từ mốc nào trở lên được coi là Jackpot.\n\n'
                            '• Tỉ lệ xuất hiện biểu tượng: biểu tượng càng hiếm thì nên đặt trọng số thấp.\n\n'
                            '• Các mốc payout (multiplier): quyết định mức thưởng khi người chơi trúng nhiều ô giống nhau.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Điều chỉnh luật thắng, tỉ lệ biểu tượng và bảng payout.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Block 1: Luật thắng cơ bản
                      Container(
                        margin:
                        const EdgeInsets.only(top: 4, bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Luật thắng cơ bản',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message:
                                  'Quy định bao nhiêu ô trùng thì thắng và multiplier nào là Jackpot.',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showSectionHelp(
                                          'Luật thắng cơ bản',
                                          '• Số ô trùng tối thiểu: ví dụ đặt 3 nghĩa là phải có ít nhất 3 ô giống nhau '
                                              'trên một dòng/thanh thì mới được tính payout.\n\n'
                                              '• Ngưỡng Jackpot (x): mọi kết quả có multiplier lớn hơn hoặc bằng ngưỡng này '
                                              'sẽ được đánh dấu là Jackpot trong log.',
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thiết lập điều kiện thắng & mốc Jackpot.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                    _minMatchToWin.toString(),
                                    keyboardType:
                                    TextInputType.number,
                                    decoration:
                                    const InputDecoration(
                                      labelText:
                                      'Số ô trùng tối thiểu',
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      final parsed =
                                      int.tryParse(v.trim());
                                      setState(() {
                                        _minMatchToWin =
                                        (parsed != null &&
                                            parsed >= 2)
                                            ? parsed
                                            : 3;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                    _jackpotThreshold.toString(),
                                    keyboardType:
                                    TextInputType.number,
                                    decoration:
                                    const InputDecoration(
                                      labelText:
                                      'Ngưỡng Jackpot (x)',
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      final parsed =
                                      int.tryParse(v.trim());
                                      setState(() {
                                        _jackpotThreshold =
                                        (parsed != null &&
                                            parsed > 0)
                                            ? parsed
                                            : 15;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2F1),
                                    borderRadius:
                                    BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Σ Trọng số payout: $_totalWeight',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00695C),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius:
                                    BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'RTP ước tính: ${_estimatedRtp.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Block 2: Tỉ lệ xuất hiện biểu tượng
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tỉ lệ xuất hiện biểu tượng',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message:
                                  'Điều chỉnh độ hiếm của từng biểu tượng trong 5 ô.',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showSectionHelp(
                                          'Tỉ lệ xuất hiện biểu tượng',
                                          'Mỗi biểu tượng có một trọng số riêng. Khi máy xèng random, '
                                              'trọng số càng lớn thì biểu tượng đó càng dễ được chọn. '
                                              'Đặt 0 để gần như không xuất hiện (hoặc chỉ xuất hiện rất hiếm).',
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Điều chỉnh độ hiếm của từng biểu tượng.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                cs.surface.withOpacity(0.9),
                                borderRadius:
                                BorderRadius.circular(16),
                              ),
                              child: Column(
                                children:
                                _buildSymbolWeightFields(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Block 3: Các mốc payout
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Các mốc payout (multiplier)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message:
                                  'Thiết lập bảng thưởng dựa trên multiplier.',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showSectionHelp(
                                          'Các mốc payout',
                                          'Mỗi dòng là một loại kết quả có multiplier nhất định và trọng số xuất hiện.\n'
                                              'Ví dụ: multiplier = 5, trọng số = 20 nghĩa là kết quả x5 bet có xác suất '
                                              'tương ứng với trọng số 20 trong tổng tất cả trọng số.',
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bảng hệ số nhân trên tiền cược.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                  10, 8, 10, 8),
                              decoration: BoxDecoration(
                                color:
                                cs.surface.withOpacity(0.95),
                                borderRadius:
                                BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Multiplier (x)',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            fontWeight:
                                            FontWeight.w600,
                                            color:
                                            cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Trọng số',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            fontWeight:
                                            FontWeight.w600,
                                            color:
                                            cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          'Tỉ lệ',
                                          textAlign: TextAlign.right,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            fontWeight:
                                            FontWeight.w600,
                                            color:
                                            cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ..._buildTierFields(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _tiers.length >= 8
                        ? null
                        : () {
                      setState(() {
                        _tiers.add(
                          _SlotTierForm(
                              multiplier: 0, weight: 0),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm mốc'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    )
                        : const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSymbolWeightFields() {
    final cs = Theme.of(context).colorScheme;
    return _symbolWeightsForms.map((s) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withOpacity(0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                s.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: s.weight.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Trọng số',
                  isDense: true,
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v.trim()) ?? 0;
                  setState(() {
                    s.weight = parsed;
                  });
                },
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTierFields() {
    final widgets = <Widget>[];
    for (int i = 0; i < _tiers.length; i++) {
      final t = _tiers[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: t.multiplier.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Multiplier (x)',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v.trim()) ?? 0;
                    _tiers[i] = _SlotTierForm(
                      multiplier: parsed,
                      weight: _tiers[i].weight,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: t.weight.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trọng số',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v.trim()) ?? 0;
                    _tiers[i] = _SlotTierForm(
                      multiplier: _tiers[i].multiplier,
                      weight: parsed,
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _weightPercentText(t.weight),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Xóa',
                    onPressed: _tiers.length <= 1
                        ? null
                        : () {
                      setState(() {
                        _tiers.removeAt(i);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}
