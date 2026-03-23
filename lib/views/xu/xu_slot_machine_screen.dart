// lib/views/xu/xu_slot_machine_screen.dart
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/xu_controller.dart';
import 'xu_slot_models.dart';
import 'xu_slot_widgets.dart';

import 'package:fl_chart/fl_chart.dart';

class _SlotHistoryEntry {
  final DateTime time;
  final int bet;
  final int multiplier; // 0 nếu thua
  final int delta; // win - bet (âm nếu thua)
  final bool isJackpot;
  final List<SlotSymbol> result;

  const _SlotHistoryEntry({
    required this.time,
    required this.bet,
    required this.multiplier,
    required this.delta,
    required this.isJackpot,
    required this.result,
  });

  bool get isWin => multiplier > 0;

  int get totalWin => isWin ? bet * multiplier : 0;
}

class XuSlotMachineScreen extends StatefulWidget {
  const XuSlotMachineScreen({super.key});

  @override
  State<XuSlotMachineScreen> createState() => _XuSlotMachineScreenState();
}

class _XuSlotMachineScreenState extends State<XuSlotMachineScreen> {
  static const int _reelCount = 5;

  final math.Random _rnd = math.Random();
  late List<SlotSymbol> _current;

  bool _spinning = false;
  final List<int> _betOptions = [50, 100, 200, 500, 1000, 5000];

  int _selectedBet = 50;

  bool _jackpotShake = false;
  bool _justHitJackpot = false;

  String? _lastResultMessage;
  bool _lastResultIsWin = false;
  final List<int> _lastMultipliers = [];
  bool _showPaytable = true;

  List<int> _winningIndices = [];

  DateTime? _lastJackpotTime;
  int? _lastJackpotProfit; // lãi thêm khi Jackpot (win - bet)

  /// Lịch sử ván chơi trong phiên (tối đa 50 ván gần nhất)
  final List<_SlotHistoryEntry> _history = [];

  /// ⭐ Runtime config (admin chỉnh được) – sync với global trong xu_slot_models.dart
  int _minMatchToWin = kMinMatchToWin;
  int _jackpotMultiplierThreshold = kJackpotMultiplierThreshold;

  @override
  void initState() {
    super.initState();
    _current = List.generate(
      _reelCount,
          (_) => _pickRandomSymbol(),
    );

    _loadSlotRuntimeConfig(); // ⭐ đọc config từ Firestore
  }

  /// ⭐ Đọc cấu hình minMatchToWin + jackpotMultiplierThreshold
  /// + symbolWeights + matchFactors từ Firestore
  Future<void> _loadSlotRuntimeConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('xu_game_config')
          .doc('slot')
          .get();
      final data = doc.data();
      if (data == null) return;

      // --------- minMatch & jackpot threshold ----------
      final int? minMatch =
      (data['minMatchToWin'] as num?)?.toInt();
      final int? jackpotThres =
      (data['jackpotMultiplierThreshold'] as num?)?.toInt();

      // --------- symbolWeights: { "seven": 1, "money": 3, ... } ----------
      Map<String, int>? symbolWeights;
      final swRaw = data['symbolWeights'];
      if (swRaw is Map) {
        final tmp = <String, int>{};
        swRaw.forEach((key, value) {
          final k = key.toString();
          final v = (value as num?)?.toInt();
          if (v != null && v >= 0) {
            tmp[k] = v;
          }
        });
        if (tmp.isNotEmpty) {
          symbolWeights = tmp;
        }
      }

      // --------- matchFactors: { "3": 1, "4": 2, "5": 3, ... } ----------
      Map<int, int>? matchFactors;
      final mfRaw = data['matchFactors'];
      if (mfRaw is Map) {
        final tmp = <int, int>{};
        mfRaw.forEach((key, value) {
          final count = int.tryParse(key.toString());
          final factor = (value as num?)?.toInt();
          if (count != null && factor != null && factor > 0) {
            tmp[count] = factor;
          }
        });
        if (tmp.isNotEmpty) {
          matchFactors = tmp;
        }
      }

      // Áp vào global config trong xu_slot_models.dart
      applyRuntimeSlotConfig(
        minMatchToWin: minMatch,
        jackpotMultiplierThreshold: jackpotThres,
        matchCountFactor: matchFactors,
        symbolWeights: symbolWeights,
      );

      if (!mounted) return;
      setState(() {
        _minMatchToWin = kMinMatchToWin;
        _jackpotMultiplierThreshold = kJackpotMultiplierThreshold;
      });
    } catch (_) {
      // ignore lỗi, dùng default
    }
  }

  /// Random symbol theo trọng số config (runtime) – dùng kSlotSymbolWeights global
  SlotSymbol _pickRandomSymbol() {
    final totalWeight = kSlotSymbols.fold<int>(
      0,
          (sum, s) => sum + (kSlotSymbolWeights[s.type] ?? 1),
    );
    int r = _rnd.nextInt(totalWeight);
    for (final s in kSlotSymbols) {
      final w = (kSlotSymbolWeights[s.type] ?? 1);
      if (r < w) return s;
      r -= w;
    }
    return kSlotSymbols.last;
  }

  /// Phân tích kết quả -> multiplier + symbol thắng + các ô thắng
  /// 👉 Dùng _minMatchToWin (từ Firestore) + kMatchCountFactor (global).
  SlotResultMeta _metaForResult(List<SlotSymbol> result) {
    final Map<SlotSymbol, int> counts = {};
    for (final s in result) {
      counts[s] = (counts[s] ?? 0) + 1;
    }

    SlotSymbol? bestSymbol;
    int bestCount = 0;

    counts.forEach((symbol, count) {
      if (count > bestCount ||
          (count == bestCount &&
              symbol.baseReward > (bestSymbol?.baseReward ?? 0))) {
        bestCount = count;
        bestSymbol = symbol;
      }
    });

    // ⭐ Dùng _minMatchToWin (admin chỉnh)
    if (bestSymbol == null || bestCount < _minMatchToWin) {
      return const SlotResultMeta(0, null, []);
    }

    final factor = kMatchCountFactor[bestCount] ?? 0;
    if (factor == 0) {
      return const SlotResultMeta(0, null, []);
    }

    final multiplier = bestSymbol!.baseReward * factor;

    final winningIndices = <int>[];
    for (int i = 0; i < result.length; i++) {
      if (result[i] == bestSymbol) {
        winningIndices.add(i);
      }
    }

    return SlotResultMeta(multiplier, bestSymbol, winningIndices);
  }

  /// Format "2 giờ trước", "3 ngày trước", "Vừa xong"
  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }

  /// Format "HH:mm dd/MM"
  String _formatFullTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    return '$hh:$mm · $d/$m';
  }

  Future<void> _spin() async {
    if (_spinning) return;

    // Haptic + âm cần gạt
    HapticFeedback.mediumImpact();
    await SlotSoundPlayer.instance.playLever();

    final auth = context.read<AuthController>();
    final xuController = context.read<XuController>();
    final uid = auth.user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Bạn cần đăng nhập để chơi máy xèng.'),
        ),
      );
      return;
    }

    final int balance = xuController.balance;
    final int bet = _selectedBet;

    if (balance < bet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Số Xu hiện có không đủ để đặt cược.'),
        ),
      );
      return;
    }

    setState(() {
      _spinning = true;
      _winningIndices = [];
    });

    // Bật sound quay liên tục
    await SlotSoundPlayer.instance.startSpinLoop();

    // =====================================================
    // 1. Giai đoạn quay nhanh (mọi cột cùng tốc độ)
    // =====================================================
    const int fastSteps = 12;
    for (int i = 0; i < fastSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 45));
      if (!mounted) return;
      setState(() {
        _current = List.generate(
          _reelCount,
              (_) => _pickRandomSymbol(),
        );
      });
    }

    // =====================================================
    // 2. Giai đoạn quay chậm dần (delay tăng dần)
    // =====================================================
    const int slowSteps = 8;
    for (int i = 0; i < slowSteps; i++) {
      final int delayMs = 60 + i * 10; // từ ~60ms → ~130ms
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;
      setState(() {
        _current = List.generate(
          _reelCount,
              (_) => _pickRandomSymbol(),
        );
      });
    }

    // =====================================================
    // 3. Chọn kết quả cuối cùng (hiển thị)
    // =====================================================
    final List<SlotSymbol> finalResult = List.generate(
      _reelCount,
          (_) => _pickRandomSymbol(),
    );

    // =====================================================
    // 4. Hiệu ứng dừng "mờ từ từ" từ trái qua phải
    // =====================================================
    const int settleStepsPerReel = 4;

    for (int reel = 0; reel < _reelCount; reel++) {
      for (int step = 0; step < settleStepsPerReel; step++) {
        final int delayMs = 70 + step * 25 + reel * 20;
        await Future.delayed(Duration(milliseconds: delayMs));
        if (!mounted) return;

        setState(() {
          _current = List.generate(_reelCount, (index) {
            if (index < reel) {
              return finalResult[index];
            } else if (index == reel) {
              if (step == settleStepsPerReel - 1) {
                return finalResult[index];
              } else {
                return _pickRandomSymbol();
              }
            } else {
              return _pickRandomSymbol();
            }
          });
        });
      }
    }

    // Đảm bảo tất cả đều về đúng finalResult
    if (!mounted) return;
    setState(() {
      _current = finalResult;
    });

    // Tắt sound quay
    await SlotSoundPlayer.instance.stopSpinLoop();

    // Dùng meta để biết ô nào sáng (winningIndices),
    // multiplierHint lấy từ luật symbol
    final meta = _metaForResult(finalResult);

    int delta;
    int multiplier;
    bool isJackpot;

    final now = DateTime.now();

    try {
      // Gọi logic payout theo cấu hình admin (tiers payout)
      delta = await xuController.playSlotWithConfig(
        uid: uid,
        bet: bet,
        symbols: finalResult.map((s) => s.emoji).toList(),
        multiplierHint: meta.multiplier, // 👈 quan trọng
      );

      final payout = bet + delta; // = bet * multiplier nếu thắng
      if (payout <= 0) {
        multiplier = 0;
      } else {
        multiplier = payout ~/ bet;
      }

      // ⭐ Jackpot dựa trên ngưỡng admin cấu hình
      isJackpot = multiplier >= _jackpotMultiplierThreshold;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content:
          Text('Có lỗi khi cập nhật Xu, vui lòng thử lại sau.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final bool isWin = multiplier > 0;
    final int win = bet * multiplier;

    setState(() {
      _spinning = false;
      _lastResultIsWin = isWin;
      _winningIndices =
      isWin ? meta.winningIndices : []; // chỉ highlight khi có thưởng

      if (isWin) {
        _lastResultMessage =
        '+${win - bet} Xu  ·  Tổng: $win Xu (x$multiplier)';
      } else {
        _lastResultMessage = '-$bet Xu (thua cược)';
      }

      _lastMultipliers.insert(0, multiplier);
      if (_lastMultipliers.length > 5) {
        _lastMultipliers.removeLast();
      }

      // Cập nhật lịch sử ván chơi
      _history.insert(
        0,
        _SlotHistoryEntry(
          time: now,
          bet: bet,
          multiplier: multiplier,
          delta: win - bet,
          isJackpot: isJackpot,
          result: finalResult,
        ),
      );
      if (_history.length > 50) {
        _history.removeLast();
      }

      // Nếu Jackpot -> lưu thông tin để hiển thị badge
      if (isJackpot) {
        _lastJackpotTime = now;
        _lastJackpotProfit = win - bet;
      }
    });

    // Âm thắng / jackpot
    if (isJackpot) {
      await SlotSoundPlayer.instance.playJackpot();
      HapticFeedback.heavyImpact();
    } else if (isWin) {
      await SlotSoundPlayer.instance.playWin();
      HapticFeedback.lightImpact();
    }

    // Hiệu ứng rung + dialog Jackpot
    if (isJackpot) {
      setState(() {
        _jackpotShake = true;
        _justHitJackpot = true;
      });

      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) {
          setState(() => _jackpotShake = false);
        }
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _justHitJackpot = false);
        }
      });

      final String title = 'Jackpot rồi! 🎉';
      final String message =
          'Bạn cược $bet Xu và nhận được $win Xu (x$multiplier lần cược).\n'
          'Lãi thêm ${win - bet} Xu đã được cộng vào ví của bạn.';

      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFF7D6),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: kGoldDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Color(0xFF4B5563),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Chơi tiếp',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _showHistorySheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final innerTheme = Theme.of(ctx);
        final media = MediaQuery.of(ctx);

        final int totalSpins = _history.length;
        final int totalProfit =
        _history.fold<int>(0, (sum, e) => sum + e.delta);
        final int winCount =
            _history.where((e) => e.isWin).length;
        final double winRate =
        totalSpins > 0 ? (winCount * 100 / totalSpins) : 0;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: media.size.height * 0.7,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Lịch sử máy xèng',
                        style: innerTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (totalSpins > 0)
                        Text(
                          '$totalSpins ván gần nhất',
                          style:
                          innerTheme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),

                // ====== CARD BIỂU ĐỒ LÃI/LỖ ======
                if (totalSpins > 1)
                  _buildHistoryChartCard(
                    innerTheme,
                    totalProfit: totalProfit,
                    totalSpins: totalSpins,
                    winRate: winRate,
                  ),

                const Divider(height: 1),

                // ====== DANH SÁCH CHI TIẾT ======
                Expanded(
                  child: _history.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(

                      ),
                      child: Text(
                        'Bạn chưa có ván máy xèng nào.\nHãy kéo cần để thử vận may nhé!',
                        style: innerTheme.textTheme.bodyMedium
                            ?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        20, 10, 20, 20),
                    itemBuilder: (context, index) {
                      final e = _history[index];
                      final isWin = e.isWin;
                      final isJackpot = e.isJackpot;
                      final totalWin = e.totalWin;

                      String resultText;
                      Color resultColor;
                      if (isWin) {
                        resultText =
                        '+${totalWin - e.bet} Xu (tổng $totalWin Xu)';
                        resultColor =
                        const Color(0xFF16A34A); // xanh thắng
                      } else {
                        resultText =
                        '-${e.bet} Xu (thua cược)';
                        resultColor =
                        const Color(0xFFDC2626); // đỏ thua
                      }

                      return Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isJackpot
                                  ? const Color(0xFFFFF7D6)
                                  : const Color(0xFFE5F0FF),
                              borderRadius:
                              BorderRadius.circular(999),
                            ),
                            child: Icon(
                              isJackpot
                                  ? Icons
                                  .workspace_premium_rounded
                                  : (isWin
                                  ? Icons.star_rounded
                                  : Icons.close_rounded),
                              size: 18,
                              color: isJackpot
                                  ? kGoldDark
                                  : (isWin
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF9CA3AF)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _formatFullTime(e.time),
                                      style: innerTheme
                                          .textTheme.bodySmall
                                          ?.copyWith(
                                        color: const Color(
                                            0xFF6B7280),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'x${e.multiplier}',
                                      style: innerTheme
                                          .textTheme.bodySmall
                                          ?.copyWith(
                                        fontWeight:
                                        FontWeight.w600,
                                        color: isWin
                                            ? const Color(
                                            0xFF2563EB)
                                            : const Color(
                                            0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  resultText,
                                  style: innerTheme
                                      .textTheme.bodyMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: resultColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cược: ${e.bet} Xu'
                                      '${isJackpot ? '  ·  Jackpot 🎉' : ''}',
                                  style: innerTheme
                                      .textTheme.bodySmall
                                      ?.copyWith(
                                    color:
                                    const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) =>
                    const Divider(
                      height: 18,
                      thickness: 0.4,
                    ),
                    itemCount: _history.length,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //------------------------------ vẽ biểu đồ --------------------

  Widget _buildHistoryChartCard(
      ThemeData theme, {
        required int totalProfit,
        required int totalSpins,
        required double winRate,
      }) {
    if (_history.length < 2) {
      return const SizedBox.shrink();
    }

    // Tính các điểm FlSpot: lãi/lỗ tích lũy theo thời gian
    final List<FlSpot> spots = [];
    double cumulative = 0;

    // Vẽ từ ván cũ -> ván mới
    for (int i = _history.length - 1; i >= 0; i--) {
      final e = _history[i];
      cumulative += e.delta.toDouble();
      final x = (_history.length - 1 - i).toDouble();
      spots.add(FlSpot(x, cumulative));
    }

    double minY = spots.map((e) => e.y).reduce(math.min);
    double maxY = spots.map((e) => e.y).reduce(math.max);

    // Luôn bao gồm mốc 0 để thấy rõ đang lời / lỗ
    minY = math.min(minY, 0);
    maxY = math.max(maxY, 0);

    // Cho thêm padding trên dưới để đường không dính sát viền
    const double paddingY = 10;
    minY -= paddingY;
    maxY += paddingY;

    final bool up = totalProfit >= 0;
    final Color lineColor =
    up ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ----- summary hàng trên -----
          Row(
            children: [
              Row(
                children: [
                  Icon(
                    up
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 18,
                    color: lineColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalProfit >= 0
                        ? '+$totalProfit Xu'
                        : '$totalProfit Xu',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: lineColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Tỉ lệ thắng: ${winRate.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: spots.length.toDouble() - 1,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),

                // ⭐ Baseline 0 (đường ngang mờ mờ)
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: const Color(0xFFCBD5F5),
                      strokeWidth: 1,
                      dashArray: const [5, 4],
                    ),
                  ],
                ),

                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 2.2,
                    color: lineColor,

                    // ⭐ Dot chỉ hiển thị ở điểm cuối
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        return spot == spots.last;
                      },
                      getDotPainter:
                          (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: lineColor,
                        );
                      },
                    ),

                    // Vùng tô phía dưới đường
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withOpacity(0.20),
                          lineColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //---------------------------------------------------

  Widget _buildJackpotBadgeAndHistory(ThemeData theme) {
    final hasJackpot =
        _lastJackpotTime != null && _lastJackpotProfit != null;

    final text = hasJackpot
        ? 'Lần Jackpot gần nhất: +$_lastJackpotProfit Xu · ${_formatTimeAgo(_lastJackpotTime!)}'
        : 'Chưa có Jackpot nào, thử vận may nhé!';

    final textColor =
    hasJackpot ? const Color(0xFF92400E) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: hasJackpot
                    ? const LinearGradient(
                  colors: [Color(0xFFFFF7D6), Color(0xFFFFEDD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: hasJackpot
                    ? null
                    : const Color(0xFFF3F4F6), // nhạt hơn cho trạng thái thường
                border: Border.all(
                  color: hasJackpot
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasJackpot
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFE5E7EB),
                    ),
                    child: Icon(
                      hasJackpot
                          ? Icons.workspace_premium_rounded
                          : Icons.bolt_rounded,
                      size: 14,
                      color:
                      hasJackpot ? kGoldDark : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: hasJackpot
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _showHistorySheet,
            style: TextButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            icon: const Icon(
              Icons.history_rounded,
              size: 16,
              color: Color(0xFF4B5563),
            ),
            label: const Text(
              'Lịch sử',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xu = context.watch<XuController>();

    final int balance = xu.balance;
    final bool canSpin = !_spinning && balance >= _betOptions.first;

    // Nếu chọn mức cược > số Xu hiện có -> tự giảm xuống mức phù hợp
    if (balance < _selectedBet) {
      final affordable = _betOptions.where((b) => b <= balance).toList();
      if (affordable.isNotEmpty) {
        _selectedBet = affordable.last;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kBlue),
        title: Text(
          'Máy xèng CSES',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 380;
            final horizontal = isCompact ? 16.0 : 20.0;
            final machineHorizontal = isCompact ? 18.0 : 22.0;

            return Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE6EEFF), Color(0xFFF9FAFB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),

                        // Banner
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontal),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD66B),
                                  Color(0xFFFFAE4A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.casino_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kéo cần, trúng quà Xu ✨',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Đặt cược Xu của bạn. Từ $_minMatchToWin biểu tượng giống nhau trở lên ở 5 ô sẽ nhận thưởng tương ứng!',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: Colors.white
                                              .withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Xu + mức cược
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontal),
                          child: _BetSection(
                            balance: balance,
                            selectedBet: _selectedBet,
                            betOptions: _betOptions,
                            onBetChanged: (bet) {
                              setState(() => _selectedBet = bet);
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Badge Jackpot + nút Lịch sử
                        _buildJackpotBadgeAndHistory(theme),

                        // Card máy xèng
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: machineHorizontal),
                          child: SlotMachineCard(
                            reelCount: _reelCount,
                            current: _current,
                            canSpin: canSpin,
                            spinning: _spinning,
                            jackpotShake: _jackpotShake,
                            justHitJackpot: _justHitJackpot,
                            lastResultMessage: _lastResultMessage,
                            lastResultIsWin: _lastResultIsWin,
                            lastMultipliers: _lastMultipliers,
                            showPaytable: _showPaytable,
                            selectedBet: _selectedBet,
                            winningIndices: _winningIndices,
                            lastJackpotTime: _lastJackpotTime,
                            lastJackpotProfit: _lastJackpotProfit,
                            onSpin: canSpin ? _spin : null,
                            onTogglePaytable: () {
                              setState(() {
                                _showPaytable = !_showPaytable;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Note cuối
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontal + 4, 0, horizontal + 4, 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Trò chơi mang tính giải trí, CSES Xu không có giá trị quy đổi thành tiền mặt.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ================== ÂM THANH MÁY XÈNG ==================

class SlotSoundPlayer {
  SlotSoundPlayer._();

  static final SlotSoundPlayer instance = SlotSoundPlayer._();

  final AudioPlayer _sfxPlayer =
  AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _loopPlayer =
  AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  Future<void> playLever() async {
    try {
      await _sfxPlayer.play(
        AssetSource('sounds/lever_click.mp3'),
      );
    } catch (e) {
      debugPrint('playLever error: $e');
    }
  }

  Future<void> startSpinLoop() async {
    try {
      await _loopPlayer.play(
        AssetSource('sounds/reel_tick.mp3'),
      );
    } catch (e) {
      debugPrint('startSpinLoop error: $e');
    }
  }

  Future<void> stopSpinLoop() async {
    try {
      await _loopPlayer.stop();
    } catch (e) {
      debugPrint('stopSpinLoop error: $e');
    }
  }

  Future<void> playWin() async {
    try {
      await _sfxPlayer.play(
        AssetSource('sounds/win_small.mp3'),
      );
    } catch (e) {
      debugPrint('playWin error: $e');
    }
  }

  Future<void> playJackpot() async {
    try {
      await _sfxPlayer.play(
        AssetSource('sounds/jackpot_big.mp3'),
      );
    } catch (e) {
      debugPrint('playJackpot error: $e');
    }
  }
}

//-------------------------------------- Xu cược -----------------
//----------------------------- Xu + cược --------------------------------
class _BetSection extends StatelessWidget {
  final int balance;
  final int selectedBet;
  final List<int> betOptions;
  final ValueChanged<int> onBetChanged;

  const _BetSection({
    required this.balance,
    required this.selectedBet,
    required this.betOptions,
    required this.onBetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final String balanceText = '$balance Xu';

    final double ratio =
    balance > 0 ? (selectedBet / balance).clamp(0.0, 1.0) : 0.0;
    final int ratioPercent =
    balance > 0 ? (ratio * 100).round().clamp(0, 999) : 0;

    // Gợi ý mức độ “an toàn” của cược
    String riskLabel;
    Color riskBg;
    Color riskText;

    if (balance == 0 || selectedBet == 0) {
      riskLabel = 'Chưa chọn';
      riskBg = const Color(0xFFF3F4F6);
      riskText = const Color(0xFF6B7280);
    } else if (ratio <= 0.05) {
      riskLabel = 'An toàn';
      riskBg = const Color(0xFFD1FAE5);
      riskText = const Color(0xFF047857);
    } else if (ratio <= 0.10) {
      riskLabel = 'Vừa phải';
      riskBg = const Color(0xFFFEF3C7);
      riskText = const Color(0xFF92400E);
    } else {
      riskLabel = 'Rủi ro cao';
      riskBg = const Color(0xFFFEE2E2);
      riskText = const Color(0xFFB91C1C);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF9FBFF),
            Color(0xFFE5EDFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFDBEAFE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------ Hàng Xu hiện có + nhãn độ an toàn ------
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ví CSES Xu',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            balanceText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đang cược: $selectedBet Xu/ván',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  riskLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: riskText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ------ Thanh % cược / Xu hiện có ------
          Text(
            'Tỉ lệ cược so với Xu hiện có',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '~ $ratioPercent% số Xu của bạn',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                'Nên đặt 1–5% Xu đang có',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ------ Tiêu đề “Chọn mức cược” ------
          Text(
            'Chọn mức cược',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),

          // ------ Dòng chip mức cược (tự wrap) ------
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: betOptions.map((bet) {
                  final bool selected = bet == selectedBet;
                  final bool disabled = balance < bet;

                  final Color borderColor;
                  final Color bgColor;
                  final Gradient? gradient;
                  final List<BoxShadow> shadows;

                  if (disabled) {
                    borderColor = const Color(0xFFE5E7EB);
                    bgColor = const Color(0xFFF3F4F6);
                    gradient = null;
                    shadows = const [];
                  } else if (selected) {
                    borderColor = Colors.transparent;
                    bgColor = Colors.transparent;
                    gradient = const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    );
                    shadows = [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ];
                  } else {
                    borderColor = const Color(0xFFBFDBFE);
                    bgColor = Colors.white;
                    gradient = null;
                    shadows = [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ];
                  }

                  final textColor = disabled
                      ? const Color(0xFF9CA3AF)
                      : (selected ? Colors.white : const Color(0xFF1F2937));

                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: disabled
                        ? null
                        : () {
                      HapticFeedback.selectionClick();
                      onBetChanged(bet);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor, width: 1.1),
                        boxShadow: shadows,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            size: 16,
                            color: disabled
                                ? const Color(0xFFCBD5F5)
                                : (selected
                                ? Colors.white
                                : const Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$bet Xu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          if (disabled) ...[
                            const SizedBox(width: 4),
                            Text(
                              'Không đủ',
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
