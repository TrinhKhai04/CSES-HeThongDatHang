// lib/views/admin/xu/admin_xu_lottery_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/xu_lottery_models.dart';
import '../../../services/xu_lottery_service.dart';
import '../../../services/admin_xu_lottery_service.dart';

class AdminXuLotteryScreen extends StatefulWidget {
  final String adminId; // uid admin hiện tại

  const AdminXuLotteryScreen({
    super.key,
    required this.adminId,
  });

  @override
  State<AdminXuLotteryScreen> createState() => _AdminXuLotteryScreenState();
}

class _AdminXuLotteryScreenState extends State<AdminXuLotteryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final XuLotteryService _userService;
  late final AdminXuLotteryService _adminService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userService = XuLotteryService();
    _adminService = AdminXuLotteryService(adminId: widget.adminId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Xổ số Xu'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Game'),
            Tab(text: 'Kỳ quay'),
            Tab(text: 'Cài đặt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdminLotteryGamesTab(
            userService: _userService,
            adminService: _adminService,
          ),
          _AdminLotteryDrawsTab(
            userService: _userService,
            adminService: _adminService,
          ),
          _AdminLotteryRuntimeTab(
            adminService: _adminService,
          ),
        ],
      ),
    );
  }
}

/// ===================================================================
/// TAB 1: GAME CONFIG
/// ===================================================================

class _AdminLotteryGamesTab extends StatelessWidget {
  final XuLotteryService userService;
  final AdminXuLotteryService adminService;

  const _AdminLotteryGamesTab({
    required this.userService,
    required this.adminService,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
        constraints.maxWidth > 640 ? 640.0 : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('xu_lottery_games')
                  .orderBy('title')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Text('Lỗi khi tải danh sách game'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Chưa có game xổ số nào.'));
                }

                final games =
                docs.map((d) => XuLotteryGame.fromSnapshot(d)).toList();

                return ListView.separated(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final g = games[index];
                    return Card(
                      elevation: 1,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: title + chip mode
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    g.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _modeLabel(g.mode),
                                    style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              g.subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _InfoChip(
                                  label: 'Giá vé',
                                  value: '${g.ticketPrice} Xu',
                                ),
                                _InfoChip(
                                  label: 'Payout',
                                  value: '${g.payoutMultiplier}x',
                                ),
                                _InfoChip(
                                  label: 'Vé/kỳ',
                                  value: '${g.maxTicketsPerDraw}',
                                ),
                                _InfoChip(
                                  label: 'Xu/ngày',
                                  value: g.maxDailyBetPerUser.toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Switch(
                                        value: g.isActive,
                                        onChanged: (v) async {
                                          await adminService.toggleGameActive(
                                            gameId: g.id,
                                            isActive: v,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('Kích hoạt'),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Switch(
                                        value: g.isVisibleOnClient,
                                        onChanged: (v) async {
                                          await adminService.toggleGameActive(
                                            gameId: g.id,
                                            isActive: g.isActive,
                                            isVisibleOnClient: v,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('Hiển thị'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.tune_rounded),
                                  onPressed: () {
                                    _showEditGameBottomSheet(
                                      context,
                                      game: g,
                                      adminService: adminService,
                                    );
                                  },
                                  tooltip: 'Sửa cấu hình',
                                ),
                              ],
                            ),

                            // NEW: Auto-loop cho game interval
                            if (g.mode == LotteryMode.interval) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Switch(
                                    value: g.autoLoopEnabled,
                                    onChanged: (v) async {
                                      await adminService.toggleGameAutoLoop(
                                        gameId: g.id,
                                        enabled: v,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Auto-loop: tự tạo kỳ mới & cho phép engine tự động quay liên tục.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _modeLabel(LotteryMode mode) {
    switch (mode) {
      case LotteryMode.interval:
        return 'Interval';
      case LotteryMode.daily:
        return 'Daily';
      case LotteryMode.weekly:
        return 'Weekly';
    }
  }

  void _showEditGameBottomSheet(
      BuildContext context, {
        required XuLotteryGame game,
        required AdminXuLotteryService adminService,
      }) {
    final ticketPriceCtl =
    TextEditingController(text: game.ticketPrice.toString());
    final payoutCtl =
    TextEditingController(text: game.payoutMultiplier.toString());
    final maxTicketsCtl =
    TextEditingController(text: game.maxTicketsPerDraw.toString());
    final maxDailyCtl =
    TextEditingController(text: game.maxDailyBetPerUser.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
            constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sửa cấu hình: ${game.title}',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ticketPriceCtl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Giá vé (Xu)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: payoutCtl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Payout multiplier (x)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: maxTicketsCtl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Vé tối đa/kỳ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxDailyCtl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Xu tối đa/ngày',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () async {
                            final ticketPrice =
                                int.tryParse(ticketPriceCtl.text.trim()) ??
                                    game.ticketPrice;
                            final payout =
                                int.tryParse(payoutCtl.text.trim()) ??
                                    game.payoutMultiplier;
                            final maxTickets =
                                int.tryParse(maxTicketsCtl.text.trim()) ??
                                    game.maxTicketsPerDraw;
                            final maxDaily =
                                int.tryParse(maxDailyCtl.text.trim()) ??
                                    game.maxDailyBetPerUser;

                            final updated = XuLotteryGame(
                              id: game.id,
                              title: game.title,
                              subtitle: game.subtitle,
                              mode: game.mode,
                              intervalMinutes: game.intervalMinutes,
                              drawHour: game.drawHour,
                              drawMinute: game.drawMinute,
                              weekday: game.weekday,
                              ticketPrice: ticketPrice,
                              maxBetPerTicket: game.maxBetPerTicket,
                              maxTicketsPerDraw: maxTickets,
                              maxDailyBetPerUser: maxDaily,
                              payoutMultiplier: payout,
                              nearWin1RefundRate: game.nearWin1RefundRate,
                              nearWin2RefundRate: game.nearWin2RefundRate,
                              allowAdminOverride: game.allowAdminOverride,
                              isActive: game.isActive,
                              isVisibleOnClient: game.isVisibleOnClient,
                              autoLoopEnabled: game.autoLoopEnabled,
                              autoLoopStopAt: game.autoLoopStopAt,
                              createdAt: game.createdAt,
                              updatedAt: DateTime.now(),
                              updatedBy: null,
                            );

                            await adminService.updateGameConfig(updated);

                            if (context.mounted) Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                          ),
                          child: const Text('Lưu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: cs.outline,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===================================================================
/// TAB 2: DRAWS (KỲ QUAY)
/// ===================================================================

enum _DrawStatusFilter { all, open, locked, settled, cancelled }

class _AdminLotteryDrawsTab extends StatefulWidget {
  final XuLotteryService userService;
  final AdminXuLotteryService adminService;

  const _AdminLotteryDrawsTab({
    required this.userService,
    required this.adminService,
  });

  @override
  State<_AdminLotteryDrawsTab> createState() => _AdminLotteryDrawsTabState();
}

class _AdminLotteryDrawsTabState extends State<_AdminLotteryDrawsTab> {
  String? _selectedGameId;

  _DrawStatusFilter _statusFilter = _DrawStatusFilter.all;
  bool _onlyUpcoming = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
        constraints.maxWidth > 640 ? 640.0 : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // ----------------- HEADER: CHỌN GAME + THÊM KỲ -----------------
                FutureBuilder<List<XuLotteryGame>>(
                  future: FirebaseFirestore.instance
                      .collection('xu_lottery_games')
                      .orderBy('title')
                      .get()
                      .then((snap) => snap.docs
                      .map((d) => XuLotteryGame.fromSnapshot(d))
                      .toList()),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final games = snap.data!;
                    if (games.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa có game xổ số.'),
                      );
                    }

                    _selectedGameId ??= games.first.id;
                    final selectedGame = games.firstWhere(
                          (g) => g.id == _selectedGameId,
                      orElse: () => games.first,
                    );

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        elevation: 0,
                        color: cs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Text('Game:'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildGameSelector(
                                  context,
                                  games,
                                  selectedGame,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _selectedGameId == null
                                    ? null
                                    : () => _showCreateDrawDialog(
                                  context,
                                  game: selectedGame,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Thêm kỳ'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ----------------- FILTER BAR GIỐNG ĐƠN HÀNG -----------------
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trạng thái',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: cs.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusChip(
                              context: context,
                              label: 'Tất cả',
                              filter: _DrawStatusFilter.all,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              context: context,
                              label: 'Đang mở',
                              filter: _DrawStatusFilter.open,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              context: context,
                              label: 'Đã khoá',
                              filter: _DrawStatusFilter.locked,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              context: context,
                              label: 'Đã quay',
                              filter: _DrawStatusFilter.settled,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              context: context,
                              label: 'Đã huỷ',
                              filter: _DrawStatusFilter.cancelled,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Switch(
                            value: _onlyUpcoming,
                            onChanged: (v) {
                              setState(() => _onlyUpcoming = v);
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Chỉ hiện kỳ sắp tới (ẩn bớt kỳ cũ để danh sách gọn hơn)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ----------------- LIST KỲ QUAY -----------------
                Expanded(
                  child: _selectedGameId == null
                      ? const Center(
                    child: Text('Chọn game để xem kỳ quay.'),
                  )
                      : StreamBuilder<List<XuLotteryDraw>>(
                    stream: widget.userService.drawsStreamForGame(
                      _selectedGameId!,
                      limit: 100,
                    ),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Center(
                            child: Text('Lỗi khi tải kỳ quay'));
                      }
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final now = DateTime.now();
                      final allDraws = snap.data!;

                      // Lọc theo trạng thái + chỉ kỳ sắp tới
                      final filtered = allDraws.where((d) {
                        if (_onlyUpcoming &&
                            d.scheduledAt.toLocal().isBefore(now)) {
                          return false;
                        }
                        switch (_statusFilter) {
                          case _DrawStatusFilter.all:
                            return true;
                          case _DrawStatusFilter.open:
                            return d.status == LotteryDrawStatus.open;
                          case _DrawStatusFilter.locked:
                            return d.status ==
                                LotteryDrawStatus.locked;
                          case _DrawStatusFilter.settled:
                            return d.status ==
                                LotteryDrawStatus.settled;
                          case _DrawStatusFilter.cancelled:
                            return d.status ==
                                LotteryDrawStatus.cancelled;
                        }
                      }).toList()
                        ..sort((a, b) =>
                            a.scheduledAt.compareTo(b.scheduledAt));

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text(
                              'Không có kỳ quay nào với bộ lọc này.'),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final d = filtered[index];
                          final statusColor =
                          _statusColor(cs, d.status);
                          final timeStr =
                          DateFormat('HH:mm, dd/MM/yyyy')
                              .format(d.scheduledAt.toLocal());

                          final isCancelled =
                              d.status == LotteryDrawStatus.cancelled;

                          return Card(
                            elevation: 1,
                            color: isCancelled
                                ? cs.errorContainer.withOpacity(0.06)
                                : cs.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isCancelled
                                    ? cs.error.withOpacity(0.4)
                                    : cs.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  // --- Dòng 1: mã kỳ + trạng thái ---
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d.drawCode,
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                            fontWeight:
                                            FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .withOpacity(0.12),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _statusLabel(d.status),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Giờ quay: $timeStr',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // --- Chỉ số Vé / Cược / Trả thưởng / KQ ---
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _InfoChip(
                                        label: 'Vé',
                                        value:
                                        d.totalTickets.toString(),
                                      ),
                                      _InfoChip(
                                        label: 'Tổng cược',
                                        value: '${d.totalBetXu} Xu',
                                      ),
                                      _InfoChip(
                                        label: 'Trả thưởng',
                                        value: '${d.totalPrizeXu} Xu',
                                      ),
                                      if (d.jackpotNumber != null)
                                        _InfoChip(
                                          label: 'KQ',
                                          value: d.jackpotNumber!
                                              .toString()
                                              .padLeft(2, '0'),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),

                                  // --- Thanh action ---
                                  Row(
                                    children: [
                                      _DrawActionButton(
                                        icon: Icons.edit_rounded,
                                        label: 'Preset',
                                        onTap: d.isSettled
                                            ? null
                                            : () => _showPresetDialog(
                                          context,
                                          d,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _DrawActionButton(
                                        icon: Icons.lock_rounded,
                                        label: 'Khoá',
                                        onTap: d.isOpen
                                            ? () async {
                                          await widget
                                              .adminService
                                              .lockDrawNow(d.id);
                                        }
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      _DrawActionButton(
                                        icon: Icons
                                            .play_circle_fill_rounded,
                                        label: 'Settle',
                                        onTap: d.isSettled
                                            ? null
                                            : () async {
                                          await widget
                                              .adminService
                                              .requestSettleDrawNow(
                                              d.id);
                                        },
                                      ),
                                      const Spacer(),
                                      _DrawActionButton(
                                        icon: Icons.cancel_rounded,
                                        label: 'Huỷ kỳ',
                                        color: cs.error,
                                        onTap: d.isSettled
                                            ? null
                                            : () async {
                                          final ok =
                                          await _confirm(
                                            context,
                                            'Xác nhận huỷ kỳ quay này? Bạn phải đảm bảo backend đã/ sẽ refund vé.',
                                          );
                                          if (!ok) return;
                                          await widget
                                              .adminService
                                              .cancelDraw(
                                            drawId: d.id,
                                            reason:
                                            'Huỷ tay từ Admin UI',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Chip chọn trạng thái
  Widget _buildStatusChip({
    required BuildContext context,
    required String label,
    required _DrawStatusFilter filter,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _statusFilter == filter;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // Chip chọn game + bottom sheet giống Đơn hàng
  Widget _buildGameSelector(
      BuildContext context,
      List<XuLotteryGame> games,
      XuLotteryGame selectedGame,
      ColorScheme cs,
      ) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        final selectedId = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            return SafeArea(
              top: false,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, index) {
                  final g = games[index];
                  final selected = g.id == _selectedGameId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(ctx, g.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primary.withOpacity(0.06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: selected ? cs.primary : cs.outline,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (g.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    g.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );

        if (selectedId != null) {
          setState(() {
            _selectedGameId = selectedId;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedGame.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme cs, LotteryDrawStatus status) {
    switch (status) {
      case LotteryDrawStatus.open:
        return cs.primary;
      case LotteryDrawStatus.locked:
        return cs.tertiary;
      case LotteryDrawStatus.settled:
        return cs.secondary;
      case LotteryDrawStatus.cancelled:
        return cs.error;
    }
  }

  String _statusLabel(LotteryDrawStatus status) {
    switch (status) {
      case LotteryDrawStatus.open:
        return 'Đang mở';
      case LotteryDrawStatus.locked:
        return 'Đã khoá';
      case LotteryDrawStatus.settled:
        return 'Đã quay';
      case LotteryDrawStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  // ----------------- Dialog tạo kỳ mới -----------------
  Future<void> _showCreateDrawDialog(
      BuildContext context, {
        required XuLotteryGame game,
      }) async {
    final codeCtl = TextEditingController();
    final presetCtl = TextEditingController();
    DateTime? scheduled;

    final now = DateTime.now();

    // Mặc định giờ quay:
    // - interval_5m: now + intervalMinutes
    // - game khác: giờ tròn + 1 tiếng
    if (game.mode == LotteryMode.interval && (game.intervalMinutes ?? 0) > 0) {
      final tmp = now.add(Duration(minutes: game.intervalMinutes!));
      scheduled = DateTime(
        tmp.year,
        tmp.month,
        tmp.day,
        tmp.hour,
        tmp.minute,
      );
    } else {
      scheduled = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Thêm kỳ quay mới (${game.title})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Mã kỳ (drawCode)',
                    hintText: 'VD: 2025-12-31-20:00-special',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scheduled != null
                            ? 'Giờ quay: ${DateFormat('HH:mm, dd/MM/yyyy').format(scheduled!.toLocal())}'
                            : 'Chưa chọn giờ quay',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                          initialDate: scheduled ?? now,
                        );
                        if (date == null) return;

                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(
                            scheduled ?? now,
                          ),
                        );
                        if (time == null) return;

                        scheduled = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        (ctx as Element).markNeedsBuild();
                      },
                      child: const Text('Chọn giờ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: presetCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Preset số trúng (optional, 0–99)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (scheduled == null) return;

                final code = codeCtl.text.trim().isEmpty
                    ? scheduled!.toIso8601String()
                    : codeCtl.text.trim();

                int? preset;
                if (presetCtl.text.trim().isNotEmpty) {
                  preset = int.tryParse(presetCtl.text.trim());
                }

                // Khóa vé:
                // - interval_5m: 60 giây
                // - game khác: 3600 giây (1 tiếng)
                final int lockBeforeSeconds =
                (game.id == 'interval_5m') ? 60 : 3600;

                await widget.adminService.createDraw(
                  gameId: game.id,
                  drawCode: code,
                  scheduledAt: scheduled!.toUtc(),
                  lockBeforeSeconds: lockBeforeSeconds,
                  adminPresetNumber: preset,
                );

                if (context.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
              ),
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );
  }

  // ----------------- Dialog preset -----------------
  Future<void> _showPresetDialog(
      BuildContext context, XuLotteryDraw draw) async {
    final ctl = TextEditingController(
      text: draw.adminPresetNumber?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Preset số trúng'),
          content: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số (0–99, để trống = bỏ preset)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final text = ctl.text.trim();
                int? value;
                if (text.isNotEmpty) {
                  value = int.tryParse(text);
                }
                await widget.adminService.setAdminPresetNumber(
                  drawId: draw.id,
                  adminPresetNumber: value,
                );
                if (context.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
              ),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  // ----------------- Dialog confirm huỷ -----------------
  Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Xác nhận'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
              ),
              child: const Text('Đồng ý'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

/// ===================================================================
/// TAB 2.1: DRAW ACTION BUTTON
/// ===================================================================

class _DrawActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _DrawActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurfaceVariant;
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===================================================================
/// TAB 3: RUNTIME GLOBAL
/// ===================================================================

class _AdminLotteryRuntimeTab extends StatelessWidget {
  final AdminXuLotteryService adminService;

  const _AdminLotteryRuntimeTab({
    required this.adminService,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
        constraints.maxWidth > 640 ? 640.0 : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('xu_lottery_runtime')
                  .doc('global')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Text('Lỗi khi tải cấu hình hệ thống'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data =
                    snap.data!.data() as Map<String, dynamic>? ?? {};
                final runtime = XuLotteryRuntime.fromJson(data);

                final maintCtl = TextEditingController(
                  text: runtime.maintenanceMessage,
                );

                return ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  children: [
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: SwitchListTile(
                        title: const Text('Tạm dừng toàn bộ xổ số'),
                        subtitle: const Text(
                          'Người dùng sẽ không thể mua vé ở tất cả game',
                        ),
                        value: runtime.isAllLotteryPaused,
                        onChanged: (v) async {
                          await adminService.togglePauseAllLottery(v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: SwitchListTile(
                        title: const Text('Bắt buộc random kết quả'),
                        subtitle: const Text(
                          'Bỏ qua mọi preset số trúng từ admin',
                        ),
                        value: runtime.forceRandomMode,
                        onChanged: (v) async {
                          await adminService.toggleForceRandomMode(v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // NEW: autoEngineEnabled
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: SwitchListTile(
                        title: const Text('Bật engine tự động'),
                        subtitle: const Text(
                          'Cho phép client engine tự động chốt kết quả và tạo kỳ mới cho các game interval đang bật Auto-loop.',
                        ),
                        value: runtime.autoEngineEnabled,
                        onChanged: (v) async {
                          await adminService.toggleAutoEngine(v);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Thông báo bảo trì / ghi chú cho người dùng',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: maintCtl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                            'VD: Hệ thống xổ số đang bảo trì từ 00:00–02:00...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await adminService.updateRuntime(
                            maintenanceMessage: maintCtl.text.trim(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                              const Text('Đã lưu cấu hình runtime'),
                              backgroundColor: cs.primary,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Lưu'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
