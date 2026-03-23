// lib/views/admin/xu/xu_minigame_stats_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _kBlue = Color(0xFF007AFF);

/// Card thống kê mini-game Xu: Slot, Wheel, Farm
///
/// Dùng trên trang admin dashboard:
/// XuMiniGameStatsCard()
class XuMiniGameStatsCard extends StatefulWidget {
  /// Callback mở màn cấu hình tỉ lệ Vòng quay Xu
  final VoidCallback? onOpenWheelConfig;

  /// Callback mở màn cấu hình payout Máy xèng CSES
  final VoidCallback? onOpenSlotConfig;

  const XuMiniGameStatsCard({
    super.key,
    this.onOpenWheelConfig,
    this.onOpenSlotConfig,
  });

  @override
  State<XuMiniGameStatsCard> createState() => _XuMiniGameStatsCardState();
}

enum _StatsRange { week, month }
enum _LogFilter { all, jackpot, loss }

class _GameStats {
  final int totalBet;
  final int totalPayout;
  final int playCount;
  final int jackpotCount;

  const _GameStats({
    required this.totalBet,
    required this.totalPayout,
    required this.playCount,
    required this.jackpotCount,
  });

  double get rtp => totalBet == 0 ? 0 : totalPayout / totalBet;

  // ✅ Net theo góc nhìn hệ thống: thu - chi
  int get net => totalBet - totalPayout;

  static const empty =
  _GameStats(totalBet: 0, totalPayout: 0, playCount: 0, jackpotCount: 0);
}

class _XuMiniSummary {
  final _GameStats slot;
  final _GameStats wheel;
  final _GameStats farm;

  const _XuMiniSummary({
    required this.slot,
    required this.wheel,
    required this.farm,
  });

  int get totalBet => slot.totalBet + wheel.totalBet + farm.totalBet;
  int get totalPayout =>
      slot.totalPayout + wheel.totalPayout + farm.totalPayout;

  // ✅ hệ thống lãi = Bet > Payout
  int get totalNet => totalBet - totalPayout;

  int get totalPlays => slot.playCount + wheel.playCount + farm.playCount;
  int get totalJackpots =>
      slot.jackpotCount + wheel.jackpotCount + farm.jackpotCount;

  double get rtp => totalBet == 0 ? 0 : totalPayout / totalBet;
}


/// 1 log mini-game
class _GameLogEntry {
  final int bet;
  final int payout;
  final DateTime? createdAt;
  final bool isJackpot;

  const _GameLogEntry({
    required this.bet,
    required this.payout,
    required this.createdAt,
    required this.isJackpot,
  });

  // ✅ Net hệ thống cho từng lượt
  int get net => bet - payout;
}


class _XuMiniGameStatsCardState extends State<XuMiniGameStatsCard> {
  _StatsRange _range = _StatsRange.week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDBEAFE), Color(0xFF60A5FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống kê',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Theo dõi Bet / Payout, RTP và Jackpot của các mini-game.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RangeChips(
                value: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<_XuMiniSummary>(
            future: _loadStats(_range),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Chưa có dữ liệu mini-game trong khoảng thời gian này.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }

              final summary = snapshot.data!;
              final maxXu = (summary.totalBet.abs() > summary.totalPayout.abs())
                  ? summary.totalBet.abs()
                  : summary.totalPayout.abs();

              final rtp = summary.rtp * 100; // %
              final rtpText =
              summary.totalBet == 0 ? '—' : '${rtp.toStringAsFixed(1)}%';

              // ----------- Biểu đồ đơn giản: Xu thu / Xu chi ----------- //
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    'Tổng quan ${_range == _StatsRange.week ? 'tuần này' : 'tháng này'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BarRow(
                    label: 'Xu thu (Bet)',
                    value: summary.totalBet,
                    maxValue: maxXu,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 6),
                  _BarRow(
                    label: 'Xu chi (Payout)',
                    value: summary.totalPayout,
                    maxValue: maxXu,
                    color: const Color(0xFF10B981), // xanh lãi
                  ),
                  const SizedBox(height: 10),

                  // 🔥 Hàng chip + tổng kết
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.start,
                    children: [
                      _StatisticChip(
                        label: 'RTP',
                        value: rtpText,
                        leading: Icons.pie_chart_rounded,
                      ),
                      _StatisticChip(
                        label: 'Lượt chơi',
                        value: '${summary.totalPlays}',
                        leading: Icons.play_arrow_rounded,
                      ),
                      _StatisticChip(
                        label: 'Jackpot',
                        value: '${summary.totalJackpots}',
                        leading: Icons.celebration_rounded,
                      ),
                      _NetBadge(net: summary.totalNet),
                    ],
                  ),

                  _RtpAlertBadge(rtpRatio: summary.rtp),

                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withOpacity(0.6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Theo từng game',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PerGameRow(
                    name: 'Máy xèng CSES',
                    icon: Icons.casino_rounded,
                    stats: summary.slot,
                    color: cs.primary,
                    onTap: () => _openGameDetail(
                      context: context,
                      title: 'Máy xèng CSES',
                      collection: 'xu_slot_plays',
                      stats: summary.slot,
                    ),
                  ),
                  _PerGameRow(
                    name: 'Vòng quay may mắn',
                    icon: Icons.replay_rounded,
                    stats: summary.wheel,
                    color: const Color(0xFFF97316),
                    onTap: () => _openGameDetail(
                      context: context,
                      title: 'Vòng quay may mắn',
                      collection: 'xu_wheel_plays',
                      stats: summary.wheel,
                    ),
                  ),
                  _PerGameRow(
                    name: 'Nông trại CSES',
                    icon: Icons.agriculture_rounded,
                    stats: summary.farm,
                    color: const Color(0xFF10B981),
                    onTap: () => _openGameDetail(
                      context: context,
                      title: 'Nông trại CSES',
                      collection: 'xu_farm_collects',
                      stats: summary.farm,
                    ),
                  ),

                  // 🆕 SECTION: CẤU HÌNH MINI-GAME
                  if (widget.onOpenWheelConfig != null ||
                      widget.onOpenSlotConfig != null) ...[
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cấu hình mini-game',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.onOpenWheelConfig != null)
                      _ConfigRow(
                        icon: Icons.tune_rounded,
                        color: _kBlue,
                        title: 'Cấu hình tỉ lệ Vòng quay Xu',
                        subtitle:
                        'Điều chỉnh xác suất phần thưởng, jackpot, ô Xu.',
                        onTap: widget.onOpenWheelConfig!,
                      ),
                    if (widget.onOpenSlotConfig != null)
                      _ConfigRow(
                        icon: Icons.casino_rounded,
                        color: const Color(0xFFF97316),
                        title: 'Cấu hình payout Máy xèng CSES',
                        subtitle:
                        'Thiết lập bảng thưởng, hệ số nhân, jackpot.',
                        onTap: widget.onOpenSlotConfig!,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ================== LOAD FIRESTORE STATS ==================

  Future<_XuMiniSummary> _loadStats(_StatsRange range) async {
    final now = DateTime.now();

    late DateTime from;
    late DateTime to;

    if (range == _StatsRange.week) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      from = DateTime(monday.year, monday.month, monday.day);
      to = from.add(const Duration(days: 7));
    } else {
      from = DateTime(now.year, now.month, 1);
      if (now.month == 12) {
        to = DateTime(now.year + 1, 1, 1);
      } else {
        to = DateTime(now.year, now.month + 1, 1);
      }
    }

    final fromTs = Timestamp.fromDate(from);
    final toTs = Timestamp.fromDate(to);

    final slotStats = await _queryGame('xu_slot_plays', fromTs, toTs);
    final wheelStats = await _queryGame('xu_wheel_plays', fromTs, toTs);
    final farmStats = await _queryGame('xu_farm_collects', fromTs, toTs);

    return _XuMiniSummary(
      slot: slotStats,
      wheel: wheelStats,
      farm: farmStats,
    );
  }

  Future<_GameStats> _queryGame(
      String collection,
      Timestamp from,
      Timestamp to,
      ) async {
    final fs = FirebaseFirestore.instance;

    final snap = await fs
        .collection(collection)
        .where('createdAt', isGreaterThanOrEqualTo: from)
        .where('createdAt', isLessThan: to)
        .get();

    if (snap.docs.isEmpty) return _GameStats.empty;

    int totalBet = 0;
    int totalPayout = 0;
    int playCount = 0;
    int jackpotCount = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final bet = (data['bet'] as num?)?.toInt() ?? 0;
      final payout = (data['payout'] as num?)?.toInt() ?? 0;
      final isJackpot = data['isJackpot'] == true;

      totalBet += bet;
      totalPayout += payout;
      playCount += 1;
      if (isJackpot) jackpotCount += 1;
    }

    return _GameStats(
      totalBet: totalBet,
      totalPayout: totalPayout,
      playCount: playCount,
      jackpotCount: jackpotCount,
    );
  }

  // ================== DETAIL BOTTOM SHEET (1,2,3) ==================

  Future<List<_GameLogEntry>> _fetchRecentLogs(String collection,
      {int limit = 50}) async {
    final fs = FirebaseFirestore.instance;

    final snap = await fs
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      final ts = data['createdAt'] as Timestamp?;
      return _GameLogEntry(
        bet: (data['bet'] as num?)?.toInt() ?? 0,
        payout: (data['payout'] as num?)?.toInt() ?? 0,
        createdAt: ts?.toDate(),
        isJackpot: data['isJackpot'] == true,
      );
    }).toList();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _friendlyDateLabel(DateTime d) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(d.year, d.month, d.day);
    final diff = todayOnly.difference(dateOnly).inDays;

    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$hh:$mm · $dd/$mo';
  }

  Future<void> _openGameDetail({
    required BuildContext context,
    required String title,
    required String collection,
    required _GameStats stats,
  }) async {
    final cs = Theme.of(context).colorScheme;

    final logs = await _fetchRecentLogs(collection);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        _LogFilter currentFilter = _LogFilter.all;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (sheetContext, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                List<_GameLogEntry> filtered = logs;
                if (currentFilter == _LogFilter.jackpot) {
                  filtered = logs.where((e) => e.isJackpot).toList();
                } else if (currentFilter == _LogFilter.loss) {
                  filtered = logs.where((e) => e.net < 0).toList();
                }

                // group theo ngày (1)
                final List<Widget> logWidgets = [];
                String? lastDateKey;

                for (final log in filtered) {
                  final createdAt = log.createdAt;
                  if (createdAt == null) continue;

                  final dk = _dateKey(createdAt);
                  if (dk != lastDateKey) {
                    lastDateKey = dk;
                    logWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Text(
                          _friendlyDateLabel(createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  logWidgets.add(
                    _LogRow(
                      log: log,
                      timeLabel: _formatTime(createdAt),
                    ),
                  );
                }

                final hasLog = logWidgets.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _range == _StatsRange.week ? 'Tuần này' : 'Tháng này',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Chip tổng quan cho game
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatisticChip(
                            label: 'Bet',
                            value: '${stats.totalBet}',
                            leading: Icons.call_made_rounded,
                          ),
                          _StatisticChip(
                            label: 'Payout',
                            value: '${stats.totalPayout}',
                            leading: Icons.call_received_rounded,
                          ),
                          _StatisticChip(
                            label: 'Net',
                            value: stats.net >= 0
                                ? '+${stats.net}'
                                : '-${stats.net.abs()}',
                            leading: Icons.trending_up_rounded,
                          ),
                          _StatisticChip(
                            label: 'RTP',
                            value: stats.totalBet == 0
                                ? '—'
                                : '${(stats.rtp * 100).toStringAsFixed(1)}%',
                            leading: Icons.pie_chart_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _RtpAlertBadge(rtpRatio: stats.rtp),
                    ),
                    const SizedBox(height: 14),

                    // Filter log (3) – cho scroll ngang để không bị tràn
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _LogFilterChip(
                              label: 'Tất cả',
                              selected: currentFilter == _LogFilter.all,
                              onTap: () => setSheetState(
                                      () => currentFilter = _LogFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _LogFilterChip(
                              label: 'Jackpot',
                              selected: currentFilter == _LogFilter.jackpot,
                              onTap: () => setSheetState(
                                      () => currentFilter = _LogFilter.jackpot),
                            ),
                            const SizedBox(width: 8),
                            _LogFilterChip(
                              label: 'Lượt lỗ',
                              selected: currentFilter == _LogFilter.loss,
                              onTap: () => setSheetState(
                                      () => currentFilter = _LogFilter.loss),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Lịch sử gần đây',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: hasLog
                            ? logWidgets
                            : [
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Chưa có lượt chơi nào trong khoảng thời gian này.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                  color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ================== UI PHỤ ==================

class _RangeChips extends StatelessWidget {
  final _StatsRange value;
  final ValueChanged<_StatsRange> onChanged;

  const _RangeChips({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget _buildChip(_StatsRange r, String label) {
      final selected = value == r;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? _kBlue.withOpacity(0.12) : cs.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _kBlue : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? _kBlue : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Dùng Wrap để auto xuống dòng nếu chật
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _buildChip(_StatsRange.week, 'Tuần này'),
        _buildChip(_StatsRange.month, 'Tháng này'),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _BarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (maxValue <= 0) {
      return Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '0',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    final ratio = (value.abs() / maxValue).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style:
            theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio == 0 ? 0.04 : ratio,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatisticChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? leading;

  const _StatisticChip({
    required this.label,
    required this.value,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Icon(
              leading,
              size: 13,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetBadge extends StatelessWidget {
  final int net;

  const _NetBadge({required this.net});

  @override
  Widget build(BuildContext context) {
    if (net == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isProfit = net >= 0;
    final bg = (isProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626))
        .withOpacity(0.09);
    final fg = isProfit ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isProfit
            ? 'Hệ thống đang lãi +$net Xu'
            : 'Hệ thống đang lỗ ${net.abs()} Xu',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Badge cảnh báo RTP bất thường (5)
class _RtpAlertBadge extends StatelessWidget {
  final double rtpRatio; // 1.0 = 100%

  const _RtpAlertBadge({required this.rtpRatio});

  @override
  Widget build(BuildContext context) {
    final pct = rtpRatio * 100;
    // Không có dữ liệu
    if (pct == 0) return const SizedBox.shrink();

    // Vùng an toàn: 80% - 120%
    if (pct >= 80 && pct <= 120) return const SizedBox.shrink();

    final isTooHigh = pct > 120;
    final bg =
    isTooHigh ? const Color(0xFFFFE4E6) : const Color(0xFFFFFBEB); // đỏ / vàng
    final fg = isTooHigh ? const Color(0xFFB91C1C) : const Color(0xFF92400E);
    final icon =
    isTooHigh ? Icons.warning_amber_rounded : Icons.info_outline_rounded;
    final text = isTooHigh
        ? 'RTP cao bất thường, kiểm tra lại cấu hình payout / jackpot.'
        : 'RTP thấp, mini-game đang thu nhiều Xu của người chơi.';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerGameRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final _GameStats stats;
  final Color color;
  final VoidCallback? onTap;

  const _PerGameRow({
    required this.name,
    required this.icon,
    required this.stats,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rtpPercent =
    stats.totalBet == 0 ? '—' : '${(stats.rtp * 100).toStringAsFixed(1)}%';

    final isProfit = stats.net >= 0;
    final netText =
    stats.net == 0 ? 'Hoà vốn' : (isProfit ? 'Đang lãi' : 'Đang lỗ');
    final netColor = stats.net == 0
        ? cs.onSurfaceVariant
        : (isProfit ? const Color(0xFF15803D) : const Color(0xFFB91C1C));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),

              // nội dung bên trái
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Lượt chơi: ${stats.playCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Jackpot: ${stats.jackpotCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      netText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: netColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // cột số liệu bên phải – cho vào Flexible để tự co khi màn hẹp
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bet: ${stats.totalBet}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      'Payout: ${stats.totalPayout}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    Text(
                      'RTP: $rtpPercent',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row cấu hình mini-game – nằm trong card chính
class _ConfigRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ConfigRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip filter log (3)
class _LogFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LogFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _kBlue.withOpacity(0.12) : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _kBlue : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? _kBlue : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 1 dòng log (2 – highlight Jackpot)
class _LogRow extends StatelessWidget {
  final _GameLogEntry log;
  final String timeLabel;

  const _LogRow({
    required this.log,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final delta = log.net;
    final isJackpot = log.isJackpot;

    Color deltaColor;
    if (delta > 0) {
      deltaColor = const Color(0xFF16A34A);
    } else if (delta < 0) {
      deltaColor = const Color(0xFFDC2626);
    } else {
      deltaColor = cs.onSurfaceVariant;
    }

    final bg =
    isJackpot ? const Color(0xFFFFFBEB) : Colors.transparent; // vàng nhạt

    final deltaStr = (delta >= 0 ? '+${delta}' : '-${delta.abs()}') + ' Xu';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bet ${log.bet} → Payout ${log.payout}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (isJackpot) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.workspace_premium_rounded,
                                size: 10, color: Color(0xFFF97316)),
                            SizedBox(width: 3),
                            Text(
                              'Jackpot',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF97316),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deltaStr,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: deltaColor,
            ),
          ),
        ],
      ),
    );
  }
}
