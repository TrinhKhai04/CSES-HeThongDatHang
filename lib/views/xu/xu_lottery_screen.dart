// lib/views/xu/xu_lottery_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart'; // (không dùng trực tiếp nhưng giữ cũng không sao)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';

import '../../controllers/xu_controller.dart';
import '../../models/xu_lottery_models.dart';
import '../../services/xu_lottery_service.dart';

class XuLotteryScreen extends StatefulWidget {
  const XuLotteryScreen({super.key});

  @override
  State<XuLotteryScreen> createState() => _XuLotteryScreenState();
}

class _XuLotteryScreenState extends State<XuLotteryScreen>
    with TickerProviderStateMixin {
  late final XuLotteryService _service;
  TabController? _tabController;

  List<XuLotteryGame> _games = [];
  bool _loadingGames = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = XuLotteryService();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final games = await _service.fetchActiveGames();
      if (!mounted) return;

      _tabController?.dispose();
      _tabController = null;

      if (games.isEmpty) {
        setState(() {
          _games = [];
          _loadingGames = false;
          _error = 'Hiện chưa có game xổ số nào đang mở.';
        });
      } else {
        final controller = TabController(length: games.length, vsync: this);

        setState(() {
          _games = games;
          _loadingGames = false;
          _error = null;
          _tabController = controller;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGames = false;
        _error = 'Lỗi khi tải danh sách game: $e';
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Chưa đăng nhập, không thể chơi xổ số.');
    }
    return user.uid;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    if (_loadingGames) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          centerTitle: true,
          elevation: 0,
          title: Text(
            'Xổ số Xu CSES',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: _XuBalanceBadge(),
            ),
          ],
        ),
        body: Center(child: Text(_error!)),
      );
    }

    if (_games.isEmpty || _tabController == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          centerTitle: true,
          elevation: 0,
          title: Text(
            'Xổ số Xu CSES',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: _XuBalanceBadge(),
            ),
          ],
        ),
        body: const Center(
          child: Text('Hiện chưa có game xổ số nào đang mở.'),
        ),
      );
    }

    final tabController = _tabController!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Xổ số Xu CSES',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: _XuBalanceBadge(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              labelPadding: const EdgeInsets.only(right: 24),
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: cs.primary,
                  width: 2.5,
                ),
                insets: const EdgeInsets.symmetric(horizontal: 12),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: _games.map((g) => Tab(text: g.title)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: _games.map((g) {
          return _LotteryGameTab(
            game: g,
            service: _service,
            userId: _currentUserId,
          );
        }).toList(),
      ),
    );
  }
}

/// Badge Xu trên AppBar
class _XuBalanceBadge extends StatelessWidget {
  const _XuBalanceBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<XuController>(
      builder: (context, xu, _) {
        final balance = xu.balance; // từ XuController

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '$balance Xu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LotteryGameTab extends StatefulWidget {
  final XuLotteryGame game;
  final XuLotteryService service;
  final String userId;

  const _LotteryGameTab({
    required this.game,
    required this.service,
    required this.userId,
  });

  @override
  State<_LotteryGameTab> createState() => _LotteryGameTabState();
}

class _LotteryGameTabState extends State<_LotteryGameTab> {
  XuLotteryDraw? _nextDraw;
  bool _loadingDraw = true;
  String? _drawError;

  int _selectedNumber = 0;
  final TextEditingController _betCtl = TextEditingController();
  bool _buying = false;

  Timer? _countdownTimer;
  Duration _timeToDraw = Duration.zero;

  // Confetti controller
  final ConfettiController _confettiController =
  ConfettiController(duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    _selectedNumber = 0;
    _betCtl.text = widget.game.ticketPrice.toString();
    _loadNextDraw();
  }

  @override
  void didUpdateWidget(covariant _LotteryGameTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) {
      _resetForNewGame();
      _loadNextDraw();
    }
  }

  void _resetForNewGame() {
    _nextDraw = null;
    _loadingDraw = true;
    _drawError = null;
    _selectedNumber = 0;
    _betCtl.text = widget.game.ticketPrice.toString();
    _cancelTimer();
  }

  Future<void> _loadNextDraw() async {
    setState(() {
      _loadingDraw = true;
      _drawError = null;
    });
    _cancelTimer();

    try {
      final draw = await widget.service.getNextOpenDraw(widget.game.id);
      if (!mounted) return;
      if (draw == null) {
        setState(() {
          _nextDraw = null;
          _loadingDraw = false;
          _drawError = 'Hiện chưa có kỳ quay nào đang mở cho game này.';
        });
      } else {
        setState(() {
          _nextDraw = draw;
          _loadingDraw = false;
        });
        _startCountdown(draw);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nextDraw = null;
        _loadingDraw = false;
        _drawError = 'Lỗi khi tải kỳ quay: $e';
      });
    }
  }

  void _startCountdown(XuLotteryDraw draw) {
    _cancelTimer();
    _updateTimeToDraw(draw);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTimeToDraw(draw);
    });
  }

  // luôn dùng giờ local để tính countdown
  void _updateTimeToDraw(XuLotteryDraw draw) {
    final now = DateTime.now();
    final scheduled = draw.scheduledAt.toLocal();
    final diff = scheduled.difference(now);
    setState(() {
      _timeToDraw = diff.isNegative ? Duration.zero : diff;
    });
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _betCtl.dispose();
    _cancelTimer();
    _confettiController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleBuyTicket() async {
    if (_nextDraw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có kỳ quay mở, vui lòng thử lại sau.'),
        ),
      );
      return;
    }

    // dùng scheduled local để tính lockTime
    final draw = _nextDraw!;
    final scheduled = draw.scheduledAt.toLocal();
    final now = DateTime.now();

    // =======================
    // ÉP THỜI GIAN KHÓA VÉ
    // =======================
    int lockSeconds = draw.lockBeforeSeconds;
    // Game 5 phút: luôn khóa trước 60 giây
    if (widget.game.id == 'interval_5m') {
      lockSeconds = 60;
    }

    final lockTime =
    scheduled.subtract(Duration(seconds: lockSeconds));
    final isLocked = now.isAfter(lockTime);

    if (isLocked || _timeToDraw == Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đến thời gian khoá vé, vui lòng chờ kỳ tiếp theo.'),
        ),
      );
      return;
    }

    final bet = int.tryParse(_betCtl.text.trim()) ?? 0;
    if (bet < widget.game.ticketPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('Tiền cược tối thiểu là ${widget.game.ticketPrice} Xu.'),
        ),
      );
      return;
    }
    if (bet > widget.game.maxBetPerTicket) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tiền cược tối đa mỗi vé là ${widget.game.maxBetPerTicket} Xu.'),
        ),
      );
      return;
    }

    setState(() {
      _buying = true;
    });

    try {
      final xuController = context.read<XuController>();

      Future<bool> spendXu(int amount, {String reason = ''}) {
        return xuController.spendXuForGame(
          uid: widget.userId,
          amount: amount,
          game: 'lottery_${widget.game.id}',
          reason: reason,
        );
      }

      final ticket = await widget.service.buyTicket(
        userId: widget.userId,
        gameId: widget.game.id,
        pickedNumber: _selectedNumber,
        betXu: bet,
        spendXu: spendXu,
      );

      if (!mounted) return;

      // Confetti khi mua vé thành công
      _confettiController.play();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã mua vé cho kỳ ${_nextDraw!.drawCode} - Số: ${ticket.pickedNumber.toString().padLeft(2, '0')}',
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;

      final message = e.toString().contains('not_enough_xu')
          ? 'Bạn không đủ Xu để cược, vui lòng nạp/bổ sung thêm.'
          : 'Không thể mua vé: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mua vé: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _buying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // responsive: màn rất nhỏ: 4 cột, bình thường: 5, tablet: 6
        final int gridCount =
        width < 340 ? 4 : width < 520 ? 5 : 6;
        final double gridHeight =
        width < 340 ? 260 : width < 520 ? 230 : 210;

        final content = RefreshIndicator(
          onRefresh: _loadNextDraw,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGameHeader(context),
              const SizedBox(height: 12),
              _buildDrawInfo(context),
              const SizedBox(height: 12),
              _buildNumberPicker(context, gridCount, gridHeight),
              const SizedBox(height: 12),
              _buildBetInput(context),
              const SizedBox(height: 12),
              _buildSummaryBar(context),
              const SizedBox(height: 12),
              _buildBuyButton(context),
              const SizedBox(height: 20),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 8),
              Text(
                'Lịch sử vé gần đây',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTicketsHistory(context),
            ],
          ),
        );

        return Stack(
          children: [
            content,
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  emissionFrequency: 0.7,
                  numberOfParticles: 18,
                  maxBlastForce: 20,
                  minBlastForce: 5,
                  gravity: 0.4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────── UI helpers ─────────────────

  /// Header game – gradient + shadow
  Widget _buildGameHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.98),
            cs.primary.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.onPrimary.withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.confirmation_number_rounded,
              color: cs.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.game.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onPrimary.withOpacity(0.85),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildHeaderTag(
                      icon: Icons.flash_on_rounded,
                      label: 'Tần suất cao',
                    ),
                    _buildHeaderTag(
                      icon: Icons.emoji_emotions_rounded,
                      label: 'Vui là chính',
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: 'Giá vé',
                      value: '${widget.game.ticketPrice} Xu',
                    ),
                    _InfoChip(
                      label: 'Payout',
                      value: '${widget.game.payoutMultiplier}x',
                    ),
                    _InfoChip(
                      label: 'Vé/kỳ',
                      value: '${widget.game.maxTicketsPerDraw}',
                    ),
                    _InfoChip(
                      label: 'Xu/ngày',
                      value: widget.game.maxDailyBetPerUser.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag({
    required IconData icon,
    required String label,
    bool dense = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Card kỳ quay – status & countdown
  Widget _buildDrawInfo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingDraw) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_drawError != null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _drawError!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.error),
          ),
        ),
      );
    }

    final draw = _nextDraw!;
    final scheduled = draw.scheduledAt.toLocal();
    final now = DateTime.now();

    // =======================
    // ÉP THỜI GIAN KHÓA VÉ
    // =======================
    int lockSeconds = draw.lockBeforeSeconds;
    if (widget.game.id == 'interval_5m') {
      lockSeconds = 60; // 5 phút: khóa trước 1 phút
    }

    final lockTime =
    scheduled.subtract(Duration(seconds: lockSeconds));
    final isLockedSoon = now.isAfter(lockTime);
    final canBuy = !isLockedSoon && _timeToDraw > Duration.zero;

    final dateStr = DateFormat('HH:mm dd/MM/yyyy').format(scheduled);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (canBuy ? cs.primary : cs.outline).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: canBuy ? cs.primary : cs.outline,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kỳ kế tiếp: ${draw.drawCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: canBuy
                              ? cs.primary.withOpacity(0.08)
                              : cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          canBuy ? 'Đang mở vé' : 'Đang khoá vé',
                          style: TextStyle(
                            fontSize: 11,
                            color: canBuy ? cs.primary : cs.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Giờ quay: $dateStr',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: canBuy ? cs.primary : cs.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          canBuy
                              ? 'Còn: ${_formatDuration(_timeToDraw)}'
                              : 'Vui lòng chờ kỳ tiếp theo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: canBuy ? cs.primary : cs.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadNextDraw,
              tooltip: 'Làm mới kỳ quay',
            ),
          ],
        ),
      ),
    );
  }

  /// Chọn số 00–99
  Widget _buildNumberPicker(
      BuildContext context, int gridCount, double gridHeight) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // tiêu đề + nút random / clear
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn số (00–99)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mỗi vé chọn 1 số – càng ít số càng “gay cấn” hơn',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11, color: cs.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.casino_rounded, size: 18),
                  tooltip: 'Random số',
                  onPressed: () {
                    setState(() {
                      _selectedNumber = Random().nextInt(100);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Bỏ chọn',
                  onPressed: () {
                    setState(() {
                      _selectedNumber = 0;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ô "số đang chọn"
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedNumber.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Số đang chọn',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.outline, fontSize: 11),
                      ),
                      Text(
                        'Đã chọn: ${_selectedNumber.toString().padLeft(2, '0')}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // grid số
            SizedBox(
              height: gridHeight,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: 100,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCount,
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final selected = index == _selectedNumber;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedNumber = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? cs.primary : cs.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? cs.primary
                              : cs.outlineVariant.withOpacity(0.7),
                        ),
                      ),
                      child: Text(
                        index.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tiền cược
  Widget _buildBetInput(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiền cược',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _betCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nhập số Xu muốn cược',
                      filled: true,
                      fillColor: cs.surfaceVariant.withOpacity(0.4),
                      suffixText: 'Xu',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      helperText:
                      'Tối thiểu ${widget.game.ticketPrice}, tối đa ${widget.game.maxBetPerTicket}',
                      helperStyle: TextStyle(
                        color: cs.outline,
                        fontSize: 11,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<int>(
                  tooltip: 'Chọn nhanh',
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: widget.game.ticketPrice,
                      child: Text('+ ${widget.game.ticketPrice}'),
                    ),
                    PopupMenuItem(
                      value: widget.game.ticketPrice * 2,
                      child: Text('+ ${widget.game.ticketPrice * 2}'),
                    ),
                    PopupMenuItem(
                      value: widget.game.ticketPrice * 5,
                      child: Text('+ ${widget.game.ticketPrice * 5}'),
                    ),
                  ],
                  onSelected: (v) {
                    final current = int.tryParse(_betCtl.text.trim()) ?? 0;
                    final next = current + v;
                    final capped = next > widget.game.maxBetPerTicket
                        ? widget.game.maxBetPerTicket
                        : next;
                    _betCtl.text = capped.toString();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Thanh tóm tắt kỳ + số + tiền cược
  Widget _buildSummaryBar(BuildContext context) {
    if (_nextDraw == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    final bet = int.tryParse(_betCtl.text.trim()) ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kỳ ${_nextDraw!.drawCode}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Số: ${_selectedNumber.toString().padLeft(2, '0')} · Cược: $bet Xu',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút mua vé
  Widget _buildBuyButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canBuy = !_buying && _nextDraw != null;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4, top: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primary.withOpacity(0.85),
            ],
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: canBuy ? _handleBuyTicket : null,
            icon: _buying
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(
              Icons.play_circle_fill_rounded,
              size: 22,
            ),
            label: Text(
              _nextDraw == null
                  ? 'Không có kỳ quay'
                  : 'Mua vé kỳ ${_nextDraw!.drawCode}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lịch sử vé – card grouped style
  Widget _buildTicketsHistory(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;
    final historyHeight = height * 0.3 > 260 ? 260.0 : height * 0.3;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        height: historyHeight,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: StreamBuilder<List<XuLotteryTicket>>(
            stream: widget.service.userTicketsStream(
              userId: widget.userId,
              gameId: widget.game.id,
              limit: 20,
            ),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Lỗi khi tải lịch sử vé'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tickets = snap.data!;
              if (tickets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 32,
                        color: cs.outline.withOpacity(0.7),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bạn chưa có vé nào cho game này.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final t = tickets[index];
                  return _TicketRow(ticket: t);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  final XuLotteryTicket ticket;

  const _TicketRow({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final win = ticket.isWin && ticket.prizeXu > 0;
    final createdStr =
    DateFormat('HH:mm dd/MM/yyyy').format(ticket.createdAt.toLocal());

    Color bgColor;
    Color leftBarColor;

    if (ticket.settledAt == null) {
      bgColor = cs.surfaceVariant.withOpacity(0.6);
      leftBarColor = cs.outlineVariant;
    } else if (win) {
      bgColor = cs.primary.withOpacity(0.12);
      leftBarColor = cs.primary;
    } else {
      bgColor = cs.surfaceVariant.withOpacity(0.5);
      leftBarColor = cs.outlineVariant;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thanh màu bên trái
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                color: leftBarColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Avatar + info chính
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: win ? cs.primary : cs.surface,
                    child: Text(
                      ticket.pickedNumber.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 12,
                        color: win ? cs.onPrimary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số ${ticket.pickedNumber.toString().padLeft(2, '0')} · Cược ${ticket.betXu} Xu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          createdStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.outline, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Trailing (trạng thái + giờ)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (ticket.settledAt == null)
                    Text(
                      'Chờ kết quả',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    )
                  else if (win)
                    Text(
                      '+${ticket.prizeXu} Xu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    )
                  else
                    Text(
                      'Trượt',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    ),
                  if (ticket.settledAt != null)
                    Text(
                      DateFormat('HH:mm').format(ticket.settledAt!.toLocal()),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
