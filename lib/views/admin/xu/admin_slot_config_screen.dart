// lib/views/admin/xu/admin_slot_config_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../xu/xu_slot_models.dart';

const _kBlue = Color(0xFF007AFF);

class AdminSlotConfigScreen extends StatefulWidget {
  const AdminSlotConfigScreen({super.key});

  @override
  State<AdminSlotConfigScreen> createState() => _AdminSlotConfigScreenState();
}

class _AdminSlotConfigScreenState extends State<AdminSlotConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _minMatchToWin = kMinMatchToWin;
  int _jackpotMultiplierThreshold = kJackpotMultiplierThreshold;

  /// Trọng số runtime cho từng symbol
  Map<SlotSymbolType, int> _symbolWeights =
  Map<SlotSymbolType, int>.from(kSlotSymbolWeights);

  /// Hệ số theo số lượng symbol trùng
  Map<int, int> _matchFactors =
  Map<int, int>.from(kMatchCountFactor);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  SlotSymbol _symbolByType(SlotSymbolType t) {
    return kSlotSymbols.firstWhere((s) => s.type == t);
  }

  SlotSymbolType? _typeFromName(String key) {
    for (final t in SlotSymbolType.values) {
      if (t.name == key) return t;
    }
    return null;
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('slot')
          .get();

      final data = doc.data();

      // Bắt đầu từ default
      int minMatch = kMinMatchToWin;
      int jackpotThres = kJackpotMultiplierThreshold;
      final Map<SlotSymbolType, int> symbolWeights =
      Map<SlotSymbolType, int>.from(kSlotSymbolWeights);
      final Map<int, int> matchFactors =
      Map<int, int>.from(kMatchCountFactor);

      if (data != null) {
        final minMatchRaw = (data['minMatchToWin'] as num?)?.toInt();
        final jackpotRaw =
        (data['jackpotMultiplierThreshold'] as num?)?.toInt();

        if (minMatchRaw != null) {
          minMatch = minMatchRaw.clamp(2, 5);
        }
        if (jackpotRaw != null && jackpotRaw > 0) {
          jackpotThres = jackpotRaw;
        }

        final swRaw = data['symbolWeights'];
        if (swRaw is Map<String, dynamic>) {
          swRaw.forEach((key, value) {
            final t = _typeFromName(key);
            final w = (value as num?)?.toInt();
            if (t != null && w != null && w > 0) {
              symbolWeights[t] = w;
            }
          });
        }

        final mfRaw = data['matchFactors'];
        if (mfRaw is Map<String, dynamic>) {
          mfRaw.forEach((key, value) {
            final count = int.tryParse(key);
            final f = (value as num?)?.toInt();
            if (count != null && f != null && f > 0) {
              matchFactors[count] = f;
            }
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _minMatchToWin = minMatch;
        _jackpotMultiplierThreshold = jackpotThres;
        _symbolWeights = symbolWeights;
        _matchFactors = matchFactors;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi khi tải cấu hình: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Chuẩn bị map để lưu Firestore
      final Map<String, int> symbolWeights = {};
      for (final t in SlotSymbolType.values) {
        symbolWeights[t.name] = (_symbolWeights[t] ?? 1).clamp(1, 999);
      }

      final Map<String, int> matchFactors = {};
      for (final entry in _matchFactors.entries) {
        matchFactors[entry.key.toString()] =
            entry.value.clamp(1, 999);
      }

      await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('slot')
          .set(
        {
          'minMatchToWin': _minMatchToWin,
          'jackpotMultiplierThreshold': _jackpotMultiplierThreshold,
          'symbolWeights': symbolWeights,
          'matchFactors': matchFactors,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Đã lưu cấu hình Máy xèng CSES.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Lỗi khi lưu cấu hình: $e';
      });
    }
  }

  void _resetToDefault() {
    HapticFeedback.selectionClick();
    setState(() {
      _minMatchToWin = kMinMatchToWin;
      _jackpotMultiplierThreshold = kJackpotMultiplierThreshold;
      _symbolWeights =
      Map<SlotSymbolType, int>.from(kSlotSymbolWeights);
      _matchFactors = Map<int, int>.from(kMatchCountFactor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình Máy xèng CSES'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveConfig,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text(
              'Lưu',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadConfig,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Intro
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.casino_rounded,
                        color: Color(0xFFF97316),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Điều chỉnh tỉ lệ thắng, jackpot và trọng số biểu tượng cho mini-game Máy xèng CSES. '
                            'Thay đổi có hiệu lực ngay cho ván chơi mới.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildWinAndJackpotCard(theme),
              const SizedBox(height: 16),
              _buildSymbolWeightCard(theme),
              const SizedBox(height: 16),
              _buildMatchFactorCard(theme),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _resetToDefault,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Khôi phục mặc định'),
                ),
              ),

              const SizedBox(height: 4),
              Text(
                'Lưu ý: Đây là cấu hình lý thuyết. RTP thực tế còn phụ thuộc hành vi cược của người chơi. '
                    'Anh có thể xem thêm thẻ "Thống kê mini-game Xu" để theo dõi RTP thực tế.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── CARD: Điều kiện thắng & Jackpot ─────────────────────

  Widget _buildWinAndJackpotCard(ThemeData theme) {
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Điều kiện thắng & Jackpot',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thiết lập số lượng biểu tượng giống nhau tối thiểu để thắng và ngưỡng nhân cược để tính là Jackpot.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _IntSettingRow(
            title: 'Số biểu tượng giống nhau tối thiểu để thắng',
            subtitle: 'Khuyến nghị: 3–4. Giá trị hiện tại: $_minMatchToWin',
            value: _minMatchToWin,
            min: 2,
            max: 5,
            unit: 'biểu tượng',
            onChanged: (v) {
              setState(() => _minMatchToWin = v);
            },
          ),
          const SizedBox(height: 10),
          _IntSettingRow(
            title: 'Ngưỡng nhân cược để tính Jackpot',
            subtitle:
            'Ví dụ: 50 nghĩa là từ x50 lần cược trở lên sẽ được tính là Jackpot.',
            value: _jackpotMultiplierThreshold,
            min: 5,
            max: 999,
            unit: 'x',
            onChanged: (v) {
              setState(() => _jackpotMultiplierThreshold = v);
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────── CARD: Trọng số biểu tượng ─────────────────────

  Widget _buildSymbolWeightCard(ThemeData theme) {
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trọng số xuất hiện biểu tượng',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trọng số càng cao thì biểu tượng càng dễ xuất hiện. '
                'Hãy giữ tổng thể cân bằng để RTP không bị lệch quá nhiều.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: SlotSymbolType.values.map((t) {
              final symbol = _symbolByType(t);
              final w = _symbolWeights[t] ?? 1;

              String label;
              switch (t) {
                case SlotSymbolType.seven:
                  label = 'Số 7 may mắn';
                  break;
                case SlotSymbolType.money:
                  label = 'Túi tiền vàng';
                  break;
                case SlotSymbolType.star:
                  label = 'Ngôi sao';
                  break;
                case SlotSymbolType.cherry:
                  label = 'Trái cherry';
                  break;
                case SlotSymbolType.lemon:
                  label = 'Trái chanh';
                  break;
                case SlotSymbolType.bell:
                  label = 'Chuông vàng';
                  break;
              }

              return _IntSettingRow.small(
                leading: Text(
                  symbol.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                title: label,
                subtitle: 'Trọng số: $w',
                value: w,
                min: 1,
                max: 99,
                unit: '',
                onChanged: (v) {
                  setState(() {
                    _symbolWeights[t] = v;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ───────────────────── CARD: Hệ số theo số symbol ─────────────────────

  Widget _buildMatchFactorCard(ThemeData theme) {
    final cs = theme.colorScheme;

    final counts = [2, 3, 4, 5];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hệ số theo số biểu tượng giống nhau',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ví dụ: 3 biểu tượng giống nhau nhân 2, 4 biểu tượng nhân 4, 5 biểu tượng nhân 8...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: counts.map((c) {
              final f = _matchFactors[c] ?? 0;
              return _IntSettingRow.small(
                title: '$c biểu tượng giống nhau',
                subtitle: f > 0
                    ? 'Hệ số: x$f (nhân với hệ số cơ bản của từng symbol)'
                    : 'Để 0 nếu muốn vô hiệu hoá mức này',
                value: f,
                min: 0,
                max: 999,
                unit: 'x',
                onChanged: (v) {
                  setState(() {
                    _matchFactors[c] = v;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── WIDGET PHỤ: Hàng chỉnh số int ─────────────────────

class _IntSettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final String unit;
  final Widget? leading;
  final ValueChanged<int> onChanged;

  const _IntSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.leading,
  });

  const _IntSettingRow.small({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void change(int delta) {
      HapticFeedback.selectionClick();
      int next = value + delta;
      if (next < min) next = min;
      if (next > max) next = max;
      onChanged(next);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperIconButton(
                  icon: Icons.remove_rounded,
                  onTap: () => change(-1),
                ),
                const SizedBox(width: 4),
                Text(
                  unit.isEmpty ? '$value' : '$value $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                _StepperIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => change(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 18,
          color: _kBlue,
        ),
      ),
    );
  }
}
