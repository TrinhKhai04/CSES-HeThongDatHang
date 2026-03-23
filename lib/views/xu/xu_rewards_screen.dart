// lib/views/xu/xu_rewards_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 để dùng HapticFeedback
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/xu_controller.dart';
import '../../routes/app_routes.dart';
import 'xu_lucky_wheel_screen.dart';
import 'xu_slot_machine_screen.dart'; // 👈 MÁY XÈNG
import 'xu_lottery_screen.dart'; // 👈 XỔ SỐ CSES

// Màu xanh chủ đạo
const _kBlue = Color(0xFF007AFF);
const _kBlueLight = Color(0xFF4F8BFF);
const _kBlueSoft = Color(0xFFE0EDFF);
const _kPageBg = Color(0xFFF5F6FA); // nền grouped sáng

/// Màn hình ưu đãi CSES Xu – kiểu Shopee Xu (tông xanh dương)
class XuRewardsScreen extends StatelessWidget {
  const XuRewardsScreen({super.key});

  // ---------- MODAL HƯỚNG DẪN XU ----------
  void _showXuGuide(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _kBlueSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.info_rounded,
                        color: _kBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Hướng dẫn sử dụng CSES Xu',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '• CSES Xu là điểm thưởng dùng để nhận ưu đãi trên CSES.\n'
                      '• Xu không có giá trị quy đổi thành tiền mặt.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cách kiếm Xu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const _GuideBullet(
                  icon: Icons.check_circle_rounded,
                  text:
                  'Điểm danh mỗi ngày để nhận +Xu theo chuỗi ngày liên tiếp.',
                ),
                const _GuideBullet(
                  icon: Icons.shopping_bag_rounded,
                  text:
                  'Hoàn tất đơn hàng & đánh giá sản phẩm để nhận thêm Xu.',
                ),
                const _GuideBullet(
                  icon: Icons.group_add_rounded,
                  text:
                  'Mời bạn bè mua hàng qua link giới thiệu để nhận Xu thưởng.',
                ),
                const _GuideBullet(
                  icon: Icons.sports_esports_rounded,
                  text:
                  'Tham gia mini game: Nông trại CSES, Vòng quay may mắn, ...',
                  isFuture: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cách dùng Xu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const _GuideBullet(
                  icon: Icons.local_offer_rounded,
                  text:
                  'Đổi voucher giảm giá / freeship trong trang Ưu đãi hoặc khi thanh toán.',
                ),
                const _GuideBullet(
                  icon: Icons.payments_rounded,
                  text:
                  'Sử dụng Xu để trừ vào giá trị đơn hàng (tuỳ chương trình khuyến mãi).',
                ),
                const _GuideBullet(
                  icon: Icons.star_rounded,
                  text:
                  'Một số sự kiện flash sale / game chỉ cho phép tham gia bằng Xu.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Lưu ý: quy tắc kiếm & sử dụng Xu có thể thay đổi theo từng chương trình '
                        'khuyến mãi. Bạn hãy theo dõi thông báo mới nhất trên CSES.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Đã hiểu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final xu = context.watch<XuController>();

    final uid = auth.user?.uid;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isLight = theme.brightness == Brightness.light;
    final Color pageBg = isLight ? _kPageBg : cs.surface;

    // Nếu chưa đăng nhập
    if (uid == null) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Ưu đãi CSES Xu',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _kBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: _kBlue),
        ),
        body: Center(
          child: Text(
            'Vui lòng đăng nhập để sử dụng CSES Xu.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final isLoading = xu.isLoading;
    final balance = xu.balance;
    final reward = xu.dailyReward;
    final checkedInToday = xu.checkedInToday;
    final streak = xu.streak;
    final spunToday = xu.spunToday;

    // ====== LEVEL + XP THẬT TỪ XuController ======
    final int xp = xu.xp;
    final int level = xu.level;
    const int xpPerLevel = XuController.xpPerLevel;
    final int xpInLevel = xp % xpPerLevel;
    final missionDoneMap = xu.dailyMissionDone;

    void _openReviewXuScreen() {
      Navigator.of(context).pushNamed(
        AppRoutes.orders,
        arguments: {'initialTabIndex': 3},
      );
    }

    void _openLuckyWheel() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const XuLuckyWheelScreen()),
      );
    }

    void _openFarm() {
      Navigator.of(context).pushNamed(AppRoutes.xuFarm);
    }

    void _openSlotMachine() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const XuSlotMachineScreen()),
      );
    }

    void _openLottery() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const XuLotteryScreen()),
      );
      // Hoặc dùng route name nếu anh có:
      // Navigator.of(context).pushNamed(AppRoutes.xuLotteryHome);
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Ưu đãi CSES Xu',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _kBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: _kBlue),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withOpacity(0.35),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn sử dụng Xu',
            onPressed: () => _showXuGuide(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => xu.reload(uid),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= HEADER XANH DƯƠNG + SỐ XU =================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _XuHeaderCard(
                  balance: balance,
                  reward: reward,
                  streak: streak,
                ),
              ),
              // caption nhỏ dưới header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Tích lũy Xu để đổi voucher và ưu đãi thanh toán cho đơn hàng CSES.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),

              // ================== KHỐI ĐIỂM DANH ==================
              // ================== KHỐI ĐIỂM DANH ==================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ------- HEADER: icon + tiêu đề + chip -------
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _kBlueSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: _kBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Điểm danh nhận Xu',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  streak > 0
                                      ? 'Chuỗi hiện tại: $streak ngày · Điểm danh đều để nhận nhiều Xu hơn'
                                      : 'Điểm danh mỗi ngày để nhận Xu & duy trì chuỗi streak.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _kBlue.withOpacity(0.06),
                            ),
                            child: Text(
                              '+$reward / ngày',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kBlue,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ------- 7 ngày điểm danh -------
                      _DailyCheckinRow(
                        streak: streak,
                        rewardPerDay: reward,
                      ),

                      const SizedBox(height: 14),

                      // ------- NÚT ĐIỂM DANH -------
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: checkedInToday
                              ? null
                              : const LinearGradient(
                            colors: [_kBlueLight, _kBlue],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          color: checkedInToday ? cs.surfaceVariant : null,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: checkedInToday
                                  ? cs.onSurfaceVariant
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: (checkedInToday || isLoading)
                                ? null
                                : () async {
                              await xu.dailyCheckin(uid);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Bạn đã nhận +$reward xu hôm nay!',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  checkedInToday
                                      ? Icons.check_circle_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  checkedInToday
                                      ? 'Đã điểm danh hôm nay'
                                      : 'Điểm danh để nhận $reward Xu',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =============== NHIỆM VỤ HẰNG NGÀY + LEVEL ===============
              _MissionSection(
                level: level,
                xpInLevel: xpInLevel,
                xpForNextLevel: xpPerLevel,
                checkedInToday: checkedInToday,
                spunToday: spunToday,
                missionDoneMap: missionDoneMap,
              ),

              const SizedBox(height: 12),

              // =============== SOCIAL: TICKER & LEADERBOARD ===============
              _RecentWinTicker(currentUid: uid),
              const SizedBox(height: 8),
              _WeeklyLeaderboardSection(currentUid: uid),

              const SizedBox(height: 16),

              // ================== CÁC ƯU ĐÃI / GAME KIẾM XU ==================
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Săn thêm Xu dưới đây',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('✨', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _PromoGrid(
                onReviewTap: _openReviewXuScreen,
                onSpinTap: _openLuckyWheel,
                onFarmTap: _openFarm,
                onSlotTap: _openSlotMachine,
                onLotteryTap: _openLottery, // 👈 XỔ SỐ CSES
                spunToday: spunToday,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isFuture;

  const _GuideBullet({
    required this.icon,
    required this.text,
    this.isFuture = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isFuture ? cs.outline : _kBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= HEADER CARD – RESPONSIVE =================

class _XuHeaderCard extends StatelessWidget {
  final int balance;
  final int reward;
  final int streak;

  const _XuHeaderCard({
    required this.balance,
    required this.reward,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final padding = isCompact ? 16.0 : 20.0;
        final iconOuter = isCompact ? 50.0 : 56.0;
        final iconInner = isCompact ? 36.0 : 40.0;
        final titleSize = isCompact ? 15.0 : 16.0;
        final balanceSize = isCompact ? 20.0 : 22.0;

        final mainRow = Row(
          crossAxisAlignment:
          isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            // Icon Xu
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: iconOuter,
                  height: iconOuter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.22),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: iconInner,
                      height: iconInner,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        size: 22,
                        color: _kBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Text bên trái
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CSES Xu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: titleSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$balance xu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: balanceSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+$reward xu mỗi lần điểm danh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isCompact) _HeaderChips(streak: streak),
          ],
        );

        return Container(
          padding: EdgeInsets.fromLTRB(padding, padding - 2, padding, padding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlueLight, _kBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _kBlue.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
            ),
          ),
          child: isCompact
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mainRow,
              const SizedBox(height: 10),
              _HeaderChips(streak: streak),
            ],
          )
              : mainRow,
        );
      },
    );
  }
}

class _HeaderChips extends StatelessWidget {
  final int streak;

  const _HeaderChips({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Xu hiện có',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Chuỗi $streak ngày 🔥',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hàng 7 ngày điểm danh – tông xanh dương, auto fit theo chiều rộng
class _DailyCheckinRow extends StatelessWidget {
  final int streak; // số ngày đã điểm danh liên tiếp
  final int rewardPerDay;

  const _DailyCheckinRow({
    required this.streak,
    required this.rewardPerDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        const double spacing = 8.0;

        // chia đều cho 7 ô, nhưng giữ trong range 60–80
        final double rawWidth = (totalWidth - spacing * 6) / 7;
        final double cardWidth = rawWidth.clamp(60.0, 80.0);

        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: spacing),
            itemBuilder: (_, index) {
              final day = index + 1;
              final done = day <= streak;
              final isToday = day == (streak + 1);

              final BoxDecoration decoration;
              if (done) {
                decoration = BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kBlueLight, _kBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kBlue.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                );
              } else if (isToday) {
                decoration = BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: cs.primary.withOpacity(0.06),
                  border: Border.all(color: _kBlue, width: 1.4),
                );
              } else {
                decoration = BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: cs.surfaceVariant,
                );
              }

              final Color textColor = done ? Colors.white : cs.onSurface;
              final Color subTextColor =
              done ? Colors.white.withOpacity(0.85) : cs.onSurfaceVariant;

              return SizedBox(
                width: cardWidth,
                child: Container(
                  decoration: decoration,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+$rewardPerDay',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: done
                              ? Colors.white.withOpacity(0.22)
                              : _kBlue.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: done ? Colors.white : _kBlue,
                        ),
                      ),
                      Text(
                        'Ngày $day',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subTextColor,
                          fontSize: 11,
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
  }
}

// =================== NHIỆM VỤ + LEVEL (PHẦN 2) ===================

class _Mission {
  final String id;
  final String title;
  final String desc;
  final bool done;
  final int xp;
  final IconData icon;

  const _Mission({
    required this.id,
    required this.title,
    required this.desc,
    required this.done,
    required this.xp,
    required this.icon,
  });
}

class _MissionSection extends StatelessWidget {
  final int level;
  final int xpInLevel;
  final int xpForNextLevel;
  final bool checkedInToday;
  final bool spunToday;
  final Map<String, bool> missionDoneMap;

  const _MissionSection({
    required this.level,
    required this.xpInLevel,
    required this.xpForNextLevel,
    required this.checkedInToday,
    required this.spunToday,
    required this.missionDoneMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final double progress = xpForNextLevel == 0
        ? 0
        : (xpInLevel / xpForNextLevel).clamp(0.0, 1.0);

    // Mission list – dùng trạng thái thực từ missionDoneMap
    final missions = <_Mission>[
      _Mission(
        id: 'checkin',
        title: 'Điểm danh hôm nay',
        desc: checkedInToday
            ? 'Bạn đã nhận Xu điểm danh.'
            : 'Điểm danh mỗi ngày để nhận Xu & XP.',
        done: missionDoneMap['checkin'] ?? checkedInToday,
        xp: 20,
        icon: Icons.calendar_month_rounded,
      ),
      _Mission(
        id: 'wheel',
        title: 'Quay vòng may mắn',
        desc: spunToday
            ? 'Bạn đã quay vòng quay hôm nay.'
            : 'Quay 1 lần để nhận Xu & XP.',
        done: missionDoneMap['wheel'] ?? spunToday,
        xp: 30,
        icon: Icons.casino_rounded,
      ),
      _Mission(
        id: 'slot',
        title: 'Trải nghiệm Máy xèng',
        desc: 'Vào chơi Máy xèng CSES để thử vận may (1 lần/ngày nhận XP).',
        done: missionDoneMap['slot'] ?? false,
        xp: 25,
        icon: Icons.sports_esports_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề + chip level
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 16,
                    color: _kBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nhiệm vụ hằng ngày',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _kBlue.withOpacity(0.06),
                  ),
                  child: Text(
                    'Lv.$level',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Thanh XP
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: cs.surfaceVariant,
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(_kBlueLight),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$xpInLevel / $xpForNextLevel XP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Mỗi $xpForNextLevel XP ~ 1 cấp',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // Danh sách nhiệm vụ
            ...missions.map(
                  (m) => _MissionCard(
                mission: m,
                colorScheme: cs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final _Mission mission;
  final ColorScheme colorScheme;

  const _MissionCard({
    required this.mission,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = mission.done;

    final Color statusBg = done
        ? const Color(0xFFE5F9ED)
        : colorScheme.surfaceVariant.withOpacity(0.9);
    final Color statusText =
    done ? const Color(0xFF16A34A) : colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              mission.icon,
              size: 18,
              color: _kBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mission.desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  done ? 'Hoàn thành' : 'Chưa xong',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusText,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+${mission.xp} XP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _kBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ----------- SOCIAL: TICKER "vừa trúng Xu" -----------

class _RecentWinTicker extends StatelessWidget {
  final String currentUid;

  const _RecentWinTicker({required this.currentUid});

  String _maskName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      if (name.length <= 3) return name;
      return '${name.substring(0, 1)}***${name.substring(name.length - 1)}';
    }
    final first = parts.first;
    final last = parts.last;
    return '$first ${last.substring(0, 1)}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Collection gợi ý: xu_recent_wins (userName, shortName, amount, game, createdAt)
    final stream = FirebaseFirestore.instance
        .collection('xu_recent_wins')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Container(); // không hiển thị nếu chưa có win nào
          }

          final doc = snapshot.data!.docs.first.data();
          final rawName =
          (doc['shortName'] ?? doc['userName'] ?? 'Người chơi').toString();
          final name = _maskName(rawName);
          final amount = (doc['amount'] as num?)?.toInt() ?? 0;
          final game = (doc['game'] ?? 'mini-game').toString();

          final text = 'Bạn $name vừa trúng $amount Xu ở $game 🎉';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: Color(0xFFFACC15),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ----------- BẢNG XẾP HẠNG TUẦN -----------
class _WeeklyLeaderboardSection extends StatelessWidget {
  final String currentUid;

  const _WeeklyLeaderboardSection({required this.currentUid});

  // giống logic trong XuController
  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Key tuần: lấy ngày thứ 2 (Monday) của tuần hiện tại
  String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return _dateKey(monday);
  }

  String _shortNameFromData(Map<String, dynamic> data) {
    final displayName = (data['displayName'] ?? data['name'] ?? '') as String;
    if (displayName.trim().isEmpty) return 'Người dùng ẩn';

    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return displayName.length > 14
          ? '${displayName.substring(0, 12)}…'
          : displayName;
    }
    final first = parts.first;
    final last = parts.last;
    return '$first $last';
  }

  String _weekRangeLabel(DateTime now) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(monday)} – ${fmt(sunday)}';
  }

  void _showFullLeaderboard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final now = DateTime.now();
    final currentWeekKey = _weekKey(now);
    final weekLabel = _weekRangeLabel(now);

    final query = FirebaseFirestore.instance
        .collection('users')
        .where('xuWeeklyGameWeekKey', isEqualTo: currentWeekKey)
        .orderBy('xuWeeklyGameXu', descending: true)
        .limit(100);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final double height = size.height * 0.75; // auto hợp các màn hình

        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // handle kéo
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _kBlue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.leaderboard_rounded,
                        size: 18,
                        color: _kBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bảng xếp hạng ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            weekLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Đóng',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _kBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Text(
                          'Chưa có dữ liệu xếp hạng cho tuần này.\nHãy chơi mini game để trở thành người đầu tiên lên bảng.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final rank = index + 1;
                        final uid = (data['uid'] ?? doc.id).toString();
                        final isMe = uid == currentUid;

                        final name = _shortNameFromData(data);
                        final avatarUrl = data['photoURL'] as String?;
                        final weeklyXu =
                            (data['xuWeeklyGameXu'] as num?)?.toInt() ?? 0;

                        Color rankColor;
                        Widget rankWidget;

                        if (rank == 1) {
                          rankColor = const Color(0xFFFACC15);
                          rankWidget = const Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                            color: Color(0xFFFACC15),
                          );
                        } else if (rank == 2) {
                          rankColor = const Color(0xFF9CA3AF);
                          rankWidget = const Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                            color: Color(0xFF9CA3AF),
                          );
                        } else if (rank == 3) {
                          rankColor = const Color(0xFFF97316);
                          rankWidget = const Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                            color: Color(0xFFF97316),
                          );
                        } else {
                          rankColor = cs.onSurfaceVariant;
                          rankWidget = Text(
                            '$rank',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: rankColor,
                            ),
                          );
                        }

                        final Color? rowBg =
                        isMe ? _kBlue.withOpacity(0.06) : null;
                        final BorderSide? rowBorder = isMe
                            ? BorderSide(
                          color: _kBlue.withOpacity(0.4),
                          width: 0.8,
                        )
                            : null;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: rowBg ?? cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: rowBorder != null
                                ? Border.fromBorderSide(rowBorder)
                                : Border.all(
                              color:
                              cs.outlineVariant.withOpacity(0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Center(child: rankWidget),
                              ),
                              const SizedBox(width: 8),
                              _AvatarCircle(
                                  url: avatarUrl, name: name),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isMe ? '$name (Bạn)' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                  theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isMe
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _kBlue.withOpacity(0.06),
                                  borderRadius:
                                  BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.monetization_on_rounded,
                                      size: 15,
                                      color: _kBlue,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '+$weeklyXu',
                                      style: theme
                                          .textTheme.bodySmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _kBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final now = DateTime.now();
    final currentWeekKey = _weekKey(now);
    final weekLabel = _weekRangeLabel(now);

    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('xuWeeklyGameWeekKey', isEqualTo: currentWeekKey)
        .orderBy('xuWeeklyGameXu', descending: true)
        .limit(3)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.leaderboard_rounded,
                    size: 18,
                    color: _kBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bảng xếp hạng ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Top xếp hạng · $weekLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _kBlue.withOpacity(0.06),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: _kBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Realtime',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _kBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showFullLeaderboard(context),
                      child: Text(
                        'Xem tất cả',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _kBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Chưa có dữ liệu xếp hạng cho tuần này.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final top1 = docs.first;
                final others = docs.skip(1).toList();

                // ====== TOP 1 – HERO CARD ======
                final topData = top1.data();
                final topUid = (topData['uid'] ?? top1.id).toString();
                final topIsMe = topUid == currentUid;
                final topName = _shortNameFromData(topData);
                final topAvatar = topData['photoURL'] as String?;
                final topWeeklyXu =
                    (topData['xuWeeklyGameXu'] as num?)?.toInt() ?? 0;

                return Column(
                  children: [
                    // Hero card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFEEF4FF),
                            Color(0xFFE0F2FE),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Medal + rank
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFACC15), Color(0xFFF97316)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.emoji_events_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _AvatarCircle(url: topAvatar, name: topName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topIsMe ? '$topName (Bạn)' : topName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hạng 1 · Thợ săn Xu số 1 tuần này',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: _kBlue,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '+$topWeeklyXu',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _kBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withOpacity(0.35),
                    ),
                    const SizedBox(height: 6),

                    // ====== RANK 2–10 ======
                    ...others.asMap().entries.map((entry) {
                      final index = entry.key; // 0 -> rank 2
                      final doc = entry.value;
                      final data = doc.data();

                      final rank = index + 2;
                      final uid = (data['uid'] ?? doc.id).toString();
                      final isMe = uid == currentUid;

                      final name = _shortNameFromData(data);
                      final avatarUrl = data['photoURL'] as String?;
                      final weeklyXu =
                          (data['xuWeeklyGameXu'] as num?)?.toInt() ?? 0;

                      Color rankColor;
                      Widget rankWidget;

                      if (rank == 2) {
                        rankColor = const Color(0xFF9CA3AF);
                        rankWidget = const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        );
                      } else if (rank == 3) {
                        rankColor = const Color(0xFFF97316);
                        rankWidget = const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFFF97316),
                        );
                      } else {
                        rankColor = cs.onSurfaceVariant;
                        rankWidget = Text(
                          '$rank',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: rankColor,
                          ),
                        );
                      }

                      final Color? rowBg =
                      isMe ? _kBlue.withOpacity(0.05) : null;
                      final BorderSide? rowBorder = isMe
                          ? BorderSide(
                        color: _kBlue.withOpacity(0.35),
                        width: 0.8,
                      )
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: rowBg ?? Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: rowBorder != null
                              ? Border.fromBorderSide(rowBorder)
                              : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Center(child: rankWidget),
                            ),
                            const SizedBox(width: 6),
                            _AvatarCircle(url: avatarUrl, name: name),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isMe ? '$name (Bạn)' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isMe
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kBlue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    size: 15,
                                    color: _kBlue,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '+$weeklyXu',
                                    style:
                                    theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _kBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String? url;
  final String name;

  const _AvatarCircle({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((e) => e[0]).take(2).join()
        : '?';

    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _buildFallback(initials);
          },
        )
            : _buildFallback(initials),
      ),
    );
  }

  Widget _buildFallback(String initials) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE5E7EB),
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}


/// ================== MINI GAME LIST / PROMO GRID ==================

/// Lưới / danh sách các block "game / nhiệm vụ" kiếm Xu
class _PromoGrid extends StatelessWidget {
  final VoidCallback onReviewTap;
  final VoidCallback onSpinTap;
  final VoidCallback onFarmTap;
  final VoidCallback onSlotTap; // 👈 máy xèng
  final VoidCallback onLotteryTap; // 👈 xổ số
  final bool spunToday;

  const _PromoGrid({
    super.key,
    required this.onReviewTap,
    required this.onSpinTap,
    required this.onFarmTap,
    required this.onSlotTap,
    required this.onLotteryTap,
    required this.spunToday,
  });

  @override
  Widget build(BuildContext context) {
    // Danh sách tất cả mini game (sau này muốn thêm game chỉ cần add ở đây)
    final items = <_MiniGame>[
      _MiniGame(
        key: 'review',
        title: 'Đánh giá sản phẩm',
        desc: 'Hoàn thành review để nhận Xu',
        comingSoon: false,
        icon: Icons.rate_review_rounded,
        iconBg: _kBlueSoft,
        onTap: onReviewTap,
      ),
      _MiniGame(
        key: 'farm',
        title: 'Nông trại CSES',
        desc: 'Trồng cây, thu hoạch nhận Xu',
        comingSoon: false,
        icon: Icons.agriculture_rounded,
        iconBg: const Color(0xFFEAF8EC),
        onTap: onFarmTap,
      ),
      _MiniGame(
        key: 'spin',
        title: 'Vòng quay may mắn',
        desc: spunToday
            ? 'Bạn đã quay hôm nay, vẫn có thể vào để xem video nhận lượt quay thêm'
            : 'Mỗi ngày được quay 1 lần để nhận Xu',
        comingSoon: false,
        icon: Icons.casino_rounded,
        iconBg: const Color(0xFFFFF4E5),
        onTap: onSpinTap,
      ),
      _MiniGame(
        key: 'slot',
        title: 'Máy xèng may mắn',
        desc: 'Kéo cần, trúng quà Xu cực đã',
        comingSoon: false,
        icon: Icons.casino_rounded,
        iconBg: const Color(0xFFFFF4D5),
        onTap: onSlotTap,
      ),
      _MiniGame(
        key: 'lottery',
        title: 'Xổ số CSES',
        desc: 'Chọn số – tham gia kỳ quay – trúng Xu cực lớn',
        comingSoon: false,
        icon: Icons.confirmation_number_rounded,
        iconBg: const Color(0xFFE8F5FF),
        onTap: onLotteryTap,
      ),

      // 🔜 Sau này thêm game mới thì add tiếp ở đây...
      // _MiniGame(...),
    ];

    // Số item hiển thị ở màn chính
    const int maxVisible = 4;
    final visibleItems =
    items.length > maxVisible ? items.sublist(0, maxVisible) : items;
    final hasMore = items.length > maxVisible;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Các mini game nổi bật (tối đa maxVisible)
          ...visibleItems.map(
                (item) => _MiniGameTile(
              item: item,
              spunToday: spunToday,
            ),
          ),

          if (hasMore) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () => _showAllMiniGamesSheet(context, items),
                icon: const Icon(Icons.apps_rounded, size: 18),
                label: const Text('Xem tất cả mini game'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bottom sheet hiển thị toàn bộ mini game
  void _showAllMiniGamesSheet(BuildContext context, List<_MiniGame> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tất cả mini game CSES Xu',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chọn mini game bên dưới để bắt đầu săn Xu.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                      itemBuilder: (_, index) => _MiniGameTile(
                        item: items[index],
                        spunToday: spunToday,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniGame {
  final String key;
  final String title;
  final String desc;
  final bool comingSoon;
  final IconData icon;
  final Color iconBg;
  final VoidCallback? onTap;

  const _MiniGame({
    required this.key,
    required this.title,
    required this.desc,
    required this.comingSoon,
    required this.icon,
    required this.iconBg,
    required this.onTap,
  });
}

/// Tile hiển thị từng mini game – dùng chung cho màn chính + bottom sheet
class _MiniGameTile extends StatelessWidget {
  final _MiniGame item;
  final bool spunToday;

  const _MiniGameTile({
    super.key,
    required this.item,
    required this.spunToday,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ---------- trailing chip ----------
    Widget trailing;
    if (item.key == 'spin') {
      if (spunToday) {
        trailing = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Đã quay',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        trailing = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlueLight, _kBlue],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Quay ngay',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    } else if (item.key == 'slot' || item.key == 'lottery') {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kBlueLight, _kBlue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Chơi ngay',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      trailing = item.comingSoon
          ? Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Sắp ra mắt',
          style: TextStyle(
            fontSize: 11,
            color: _kBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
          : Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kBlue.withOpacity(0.5)),
        ),
        child: const Text(
          'Dùng ngay',
          style: TextStyle(
            fontSize: 11,
            color: _kBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final bool isComingSoon = item.comingSoon;

    // ---------- onTap với feedback ----------
    VoidCallback onTap;
    if (item.onTap != null && !isComingSoon) {
      onTap = () async {
        HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 90));
        item.onTap!.call();
      };
    } else {
      onTap = () {
        final msg = isComingSoon
            ? 'Tính năng này sẽ sớm ra mắt trên CSES ✨'
            : 'Tính năng đang tạm thời không khả dụng.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      };
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                size: 22,
                color: _kBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: trailing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
