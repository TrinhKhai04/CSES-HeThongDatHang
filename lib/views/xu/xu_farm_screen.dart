import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/xu_controller.dart';
import '../../models/farm_slot.dart';

const _kBlue = Color(0xFF007AFF);
const _kSkyTop = Color(0xFFE3F2FF);
const _kSkyBottom = Color(0xFFEAF8EC);
const _kField = Color(0xFFF5E4D6); // màu đất
const _kTileGrass = Color(0xFFEAF8EC);
const _kTileEmpty = Colors.white;

class XuFarmScreen extends StatefulWidget {
  const XuFarmScreen({super.key});

  @override
  State<XuFarmScreen> createState() => _XuFarmScreenState();
}

class _XuFarmScreenState extends State<XuFarmScreen> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<XuController>().attachFarmWithContext(context);
    });

    // Auto cập nhật mỗi phút để % lớn lên tự nhảy
    _timer = Timer.periodic(const Duration(minutes: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Nông trại CSES',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _kBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: _kBlue),
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      body: SafeArea(
        // giữ top = false để không đụng appBar
        top: false,
        child: Consumer<XuController>(
          builder: (context, xu, _) {
            final slots = xu.farmSlots;
            if (slots.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final now = _now;

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kSkyTop, _kSkyBottom],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER CARD
                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.agriculture_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trang trại của bạn',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Trồng cây – đợi lớn – thu hoạch Xu',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: _kBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${xu.balance} xu',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: _kBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CÁNH ĐỒNG (RESPONSIVE)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                          decoration: BoxDecoration(
                            color: _kField,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.brown.withOpacity(0.18),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.brown.withOpacity(0.28),
                            ),
                          ),
                          // 👇 LayoutBuilder để tự tính số cột theo độ rộng
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final contentWidth = constraints.maxWidth;

                              // ✔️ Mặc định 2 cột cho điện thoại
                              int crossAxisCount = 2;

                              // Tablet ngang / màn rộng hơn thì tăng cột
                              if (contentWidth >= 720) {
                                crossAxisCount = 3;
                              }
                              if (contentWidth >= 1100) {
                                crossAxisCount = 4;
                              }

                              // Chỉ khi màn siêu nhỏ (ví dụ device bé xíu) mới cho 1 cột
                              if (contentWidth <= 280) {
                                crossAxisCount = 1;
                              }

                              // Tinh chỉnh card bớt cao trên màn hẹp
                              final baseItemWidth = contentWidth / crossAxisCount;
                              final double childAspectRatio =
                              baseItemWidth < 170 ? 0.8 : 0.9;

                              final bool shouldScroll = slots.length > crossAxisCount * 2;

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.park, size: 18, color: Colors.green),
                                      SizedBox(width: 4),
                                      Icon(Icons.park, size: 18, color: Colors.green),
                                      SizedBox(width: 4),
                                      Icon(Icons.park, size: 18, color: Colors.green),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: GridView.builder(
                                      physics: shouldScroll
                                          ? const BouncingScrollPhysics()
                                          : const NeverScrollableScrollPhysics(),
                                      itemCount: slots.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                      itemBuilder: (context, index) {
                                        final slot = slots[index];
                                        return _buildPotTile(context, slot, now);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    // TIP BAR
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(16),
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
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kBlue.withOpacity(0.08),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: _kBlue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cây hiếm cho nhiều Xu hơn nhưng thời gian chờ lâu hơn.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------ Ô ruộng dạng VÁN GỖ + CHẬU 3D ------------------------
  Widget _buildPotTile(BuildContext context, FarmSlot slot, DateTime now) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    String title;
    String subtitle;
    String actionText;
    VoidCallback? onTap;

    final left = slot.remainingMinutes(now) ?? 0;
    final total = slot.growMinutes ?? 0;
    double progress = 0;

    if (slot.isEmpty) {
      title = 'Ô đất trống';
      subtitle = 'Chạm để gieo hạt mới';
      actionText = 'Trồng';
      onTap = () => _showPlantSheet(context, slot);
    } else {
      if (total > 0 && left >= 0) {
        final p = 1 - (left / total);
        progress = p.clamp(0, 1);
      }
      if (left <= 0) {
        title = 'Đã chín';
        subtitle = 'Thu hoạch để nhận Xu';
      } else {
        final hours = (left / 60).floor();
        final mins = left % 60;
        final timeText = hours > 0 ? '$hours giờ $mins phút' : '$mins phút';
        title = 'Cây đang lớn';
        subtitle = 'Còn $timeText';
      }
      actionText = 'Thu hoạch';

      // ✅ Sửa: Thu hoạch xong thì tick nhiệm vụ "farm" + cộng XP (1 lần/ngày)
      onTap = () async {
        final ctrl = context.read<XuController>();
        try {
          await ctrl.harvestSlotWithContext(context, slot: slot);
          // Hoàn thành nhiệm vụ nông trại (logic anti-trùng nằm trong XuController)
          await ctrl.completeMissionWithContext(
            context,
            missionId: 'farm',
            xpReward: 30,
          );
        } catch (e) {
          _showError(context, e.toString());
        }
      };
    }

    final growing = !slot.isEmpty && left > 0;
    final ready = !slot.isEmpty && left <= 0;
    final isRare = slot.seedType == 'expensive';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          // ván gỗ bên ngoài
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCE9C8), Color(0xFFF3D0A7)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.brown.withOpacity(0.28),
            width: 0.8,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            // tấm rơm
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF9EC), Color(0xFFFBE7C7)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ---------- BADGE TRÊN CÙNG ----------
                Row(
                  children: [
                    if (!slot.isEmpty)
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withOpacity(0.95),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRare
                                        ? Icons.local_florist
                                        : Icons.spa_rounded,
                                    size: 13,
                                    color: isRare
                                        ? Colors.orange[800]
                                        : Colors.green[700],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isRare ? 'Cây hiếm' : 'Cây thường',
                                    style:
                                    theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isRare
                                          ? Colors.orange[900]
                                          : Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 20, height: 20),
                    const Spacer(),
                    if (ready)
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFC857), Color(0xFFFF9F1C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                    Colors.orangeAccent.withOpacity(0.5),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 13, color: Colors.white),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Đã chín',
                                    style:
                                    theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // ---------- CHẬU 3D ----------
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 90,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // ánh sáng sau chậu
                          Positioned(
                            bottom: 30,
                            child: Container(
                              width: 76,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.9),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // bóng dưới chậu
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 54,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),

                          // đĩa lót
                          Positioned(
                            bottom: 9,
                            child: Container(
                              width: 66,
                              height: 13,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.brown.shade300,
                                    Colors.brown.shade500,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // thân chậu
                          Positioned(
                            bottom: 14,
                            child: Container(
                              width: 64,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                  bottom: Radius.circular(14),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.brown.shade200,
                                    Colors.brown.shade500,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.brown.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // mép chậu (viền + lòng chậu tối)
                          Positioned(
                            bottom: 31,
                            child: Container(
                              width: 74,
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.brown.shade500,
                                    Colors.brown.shade700,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.brown.shade800,
                                        Colors.brown.shade900,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // lớp đất
                          Positioned(
                            bottom: 35,
                            child: Container(
                              width: 60,
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.brown.shade500,
                                    Colors.brown.shade600,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // mầm cây
                          Positioned(
                            bottom: slot.isEmpty ? 37 : 40,
                            child: Icon(
                              slot.isEmpty
                                  ? Icons.terrain_rounded
                                  : Icons.eco_rounded,
                              size: ready ? 34 : 30,
                              color: slot.isEmpty
                                  ? Colors.brown.shade200
                                  : (ready
                                  ? Colors.green.shade700
                                  : Colors.green.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---------- TEXT + PROGRESS ----------
                Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    if (growing) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.75),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đã lớn ${(progress * 100).round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ],
                ),

                // ---------- BUTTON ----------
                SizedBox(
                  height: 30,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                      slot.isEmpty ? _kBlue : Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: onTap,
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

  // ------------------- Chọn loại cây -------------------
  Future<void> _showPlantSheet(
      BuildContext context,
      FarmSlot slot,
      ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  'Chọn loại cây muốn trồng',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.spa, color: Colors.green),
                  title: const Text('Cây thường'),
                  subtitle: const Text('50 xu → 80 xu sau 2 giờ'),
                  onTap: () => Navigator.pop(ctx, 'cheap'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_florist, color: Colors.teal),
                  title: const Text('Cây hiếm'),
                  subtitle: const Text('200 xu → 320 xu sau 8 giờ'),
                  onTap: () => Navigator.pop(ctx, 'expensive'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    final ctrl = context.read<XuController>();

    try {
      if (result == 'cheap') {
        await ctrl.plantSeedWithContext(
          context,
          slotId: slot.id,
          seed: cheapSeed,
        );
      } else if (result == 'expensive') {
        await ctrl.plantSeedWithContext(
          context,
          slotId: slot.id,
          seed: expensiveSeed,
        );
      }

      // ✅ Sau khi trồng thành công, tick nhiệm vụ "farm" + cộng XP (1 lần/ngày)
      await ctrl.completeMissionWithContext(
        context,
        missionId: 'farm',
        xpReward: 30,
      );
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
