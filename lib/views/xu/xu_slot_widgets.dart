// lib/views/xu/xu_slot_widgets.dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'xu_slot_models.dart';

/// ================== PHẦN XU HIỆN CÓ + CHỌN MỨC CƯỢC ==================

class BalanceBetSection extends StatelessWidget {
  final int balance;
  final int selectedBet;
  final List<int> betOptions;
  final ValueChanged<int> onBetChanged;

  const BalanceBetSection({
    super.key,
    required this.balance,
    required this.selectedBet,
    required this.betOptions,
    required this.onBetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill Xu hiện có
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE5F0FF),
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    size: 16,
                    color: kBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Xu hiện có: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$balance Xu',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Chọn mức cược',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: betOptions.map((bet) {
              final bool selected = bet == selectedBet;
              final bool disabled = balance < bet;
              return ChoiceChip(
                label: Text('$bet Xu'),
                selected: selected,
                onSelected: disabled
                    ? null
                    : (v) {
                  if (!v) return;
                  onBetChanged(bet);
                },
                selectedColor: kBlue,
                backgroundColor:
                disabled ? cs.surfaceVariant : Colors.white,
                labelStyle: TextStyle(
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : (disabled
                      ? cs.onSurfaceVariant
                      : const Color(0xFF111827)),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: selected
                        ? Colors.transparent
                        : cs.outlineVariant
                        .withOpacity(disabled ? 0.4 : 0.7),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// ================== CARD MÁY XÈNG CHÍNH ==================

class SlotMachineCard extends StatefulWidget {
  final int reelCount;
  final List<SlotSymbol> current;

  final bool canSpin;
  final bool spinning;
  final bool jackpotShake;
  final bool justHitJackpot;

  final String? lastResultMessage;
  final bool lastResultIsWin;
  final List<int> lastMultipliers;
  final bool showPaytable;
  final int selectedBet;
  final List<int> winningIndices;

  final DateTime? lastJackpotTime;
  final int? lastJackpotProfit;

  final VoidCallback? onSpin;
  final VoidCallback onTogglePaytable;

  const SlotMachineCard({
    super.key,
    required this.reelCount,
    required this.current,
    required this.canSpin,
    required this.spinning,
    required this.jackpotShake,
    required this.justHitJackpot,
    required this.lastResultMessage,
    required this.lastResultIsWin,
    required this.lastMultipliers,
    required this.showPaytable,
    required this.selectedBet,
    required this.winningIndices,
    required this.lastJackpotTime,
    required this.lastJackpotProfit,
    required this.onSpin,
    required this.onTogglePaytable,
  });

  @override
  State<SlotMachineCard> createState() => _SlotMachineCardState();
}

class _SlotMachineCardState extends State<SlotMachineCard> {
  late ConfettiController _confettiTop;
  late ConfettiController _confettiCenter;

  @override
  void initState() {
    super.initState();
    _confettiTop =
        ConfettiController(duration: const Duration(seconds: 1));
    _confettiCenter =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void didUpdateWidget(covariant SlotMachineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khi vừa trúng Jackpot -> bắn pháo hoa
    if (widget.justHitJackpot && !oldWidget.justHitJackpot) {
      _confettiTop.play();
      _confettiCenter.play();
    }
  }

  @override
  void dispose() {
    _confettiTop.dispose();
    _confettiCenter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth =
        constraints.maxWidth.clamp(260.0, 420.0);
        final double reelHeight =
        (cardWidth * 0.18).clamp(56.0, 80.0);
        final double leverHeight = reelHeight + 22;
        final double symbolFontSize =
        (reelHeight * 0.48).clamp(22.0, 30.0);
        final double highlightHeight =
        (reelHeight * 0.36).clamp(18.0, 26.0);

        final Widget card = AnimatedScale(
          scale: widget.jackpotShake ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [kMachineYellowTop, kMachineYellowBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.65),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                // Header CSES SLOT
                Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF020617), kDarkNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.bolt_rounded,
                        color: kGold,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'CSES SLOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge Jackpot gần nhất
                if (widget.lastJackpotTime != null &&
                    (widget.lastJackpotProfit ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Jackpot gần nhất: +${widget.lastJackpotProfit} Xu',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Hàng đèn
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    10,
                        (i) => Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i.isEven
                              ? Colors.white
                              : const Color(0xFFFFF4D0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Cụm 5 ô + cần gạt
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 5 ô
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(22),
                            color: kDarkNavy,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF8FBFF),
                                  Color(0xFFE3ECF8),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: highlightHeight,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                      BorderRadius.circular(
                                          16),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white
                                              .withOpacity(0.40),
                                          Colors.white
                                              .withOpacity(0.0),
                                        ],
                                        begin:
                                        Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      vertical: 10,
                                      horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceEvenly,
                                    children: List.generate(
                                      widget.reelCount,
                                          (index) {
                                        final symbol =
                                        widget.current[index];
                                        final isWinning = widget
                                            .winningIndices
                                            .contains(index);

                                        return Expanded(
                                          child: Padding(
                                            padding:
                                            const EdgeInsets
                                                .symmetric(
                                              horizontal: 3,
                                            ),
                                            child:
                                            AnimatedContainer(
                                              duration:
                                              const Duration(
                                                  milliseconds:
                                                  200),
                                              curve: Curves.easeOut,
                                              height: reelHeight,
                                              decoration:
                                              BoxDecoration(
                                                borderRadius:
                                                BorderRadius
                                                    .circular(
                                                    14),
                                                color: Colors.white,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isWinning
                                                        ? kGold
                                                        .withOpacity(
                                                        0.6)
                                                        : Colors
                                                        .black
                                                        .withOpacity(
                                                        0.06),
                                                    blurRadius:
                                                    isWinning
                                                        ? 14
                                                        : 8,
                                                    offset:
                                                    const Offset(
                                                        0, 3),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: isWinning
                                                      ? kGoldDark
                                                      : const Color(
                                                      0xFFCBD5F5)
                                                      .withOpacity(
                                                      0.9),
                                                  width:
                                                  isWinning
                                                      ? 1.6
                                                      : 0.9,
                                                ),
                                              ),
                                              child: AnimatedScale(
                                                scale: isWinning
                                                    ? 1.08
                                                    : 1.0,
                                                duration:
                                                const Duration(
                                                    milliseconds:
                                                    180),
                                                curve:
                                                Curves.easeOut,
                                                child: Center(
                                                  child:
                                                  AnimatedSwitcher(
                                                    duration:
                                                    const Duration(
                                                      milliseconds:
                                                      80,
                                                    ),
                                                    transitionBuilder:
                                                        (child,
                                                        animation) {
                                                      return ScaleTransition(
                                                        scale:
                                                        animation,
                                                        child:
                                                        child,
                                                      );
                                                    },
                                                    child: Text(
                                                      symbol.emoji,
                                                      key: ValueKey<
                                                          String>(
                                                        '${symbol.emoji}-$index',
                                                      ),
                                                      style:
                                                      TextStyle(
                                                        fontSize:
                                                        symbolFontSize,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // CẦN GẠT — phiên bản đẹp hơn
                      GestureDetector(
                        onTap: widget.canSpin ? widget.onSpin : null,
                        behavior:
                        HitTestBehavior.translucent,
                        child: SizedBox(
                          width: 70,
                          height: leverHeight,
                          child: Stack(
                            alignment: Alignment.centerRight,
                            clipBehavior: Clip.none,
                            children: [
                              // Đế tròn gắn vào thân máy
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient:
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFFF0C2),
                                        Color(0xFFFBBF24),
                                      ],
                                      begin:
                                      Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.22),
                                        blurRadius: 8,
                                        offset:
                                        const Offset(-2, 3),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.9),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),

                              // Plate vàng phía trong
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 32,
                                  height: leverHeight * 0.9,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(
                                        18),
                                    gradient:
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFFE9B0),
                                        Color(0xFFFCCB73),
                                      ],
                                      begin:
                                      Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.18),
                                        blurRadius: 8,
                                        offset:
                                        const Offset(-2, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Thanh kim loại
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 7,
                                  height: leverHeight,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(
                                        999),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade200,
                                        Colors.grey.shade500,
                                      ],
                                      begin:
                                      Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.25),
                                        blurRadius: 6,
                                        offset:
                                        const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Núm đỏ — di chuyển + xoay khi đang quay
                              AnimatedAlign(
                                duration:
                                const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                alignment: widget.spinning
                                    ? const Alignment(1.0, 0.7)
                                    : const Alignment(1.0, -0.7),
                                child: Transform.translate(
                                  offset: const Offset(6, 0),
                                  child: Transform.rotate(
                                    angle:
                                    widget.spinning ? 0.28 : -0.18,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: widget.canSpin &&
                                            !widget.spinning
                                            ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFF4B4B),
                                            Color(0xFFE11D48),
                                          ],
                                          begin:
                                          Alignment.topLeft,
                                          end: Alignment
                                              .bottomRight,
                                        )
                                            : const LinearGradient(
                                          colors: [
                                            Color(0xFF9CA3AF),
                                            Color(0xFF9CA3AF),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.35),
                                            blurRadius: 10,
                                            offset:
                                            const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.95),
                                          width: 1.6,
                                        ),
                                      ),
                                      child: Container(
                                        margin:
                                        const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient:
                                          LinearGradient(
                                            colors: [
                                              Colors.white
                                                  .withOpacity(0.65),
                                              Colors.white
                                                  .withOpacity(0.05),
                                            ],
                                            begin:
                                            Alignment.topLeft,
                                            end: Alignment
                                                .bottomRight,
                                          ),
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
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Dòng kết quả + lịch sử
                if (widget.lastResultMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.lastResultIsWin
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                            ),
                            child: Icon(
                              widget.lastResultIsWin
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: widget.lastResultIsWin
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.lastResultMessage!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.lastMultipliers.isNotEmpty)
                            const SizedBox(width: 8),
                          if (widget.lastMultipliers.isNotEmpty)
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE)
                                    .withOpacity(0.9),
                                borderRadius:
                                BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Lịch sử:',
                                    style: theme
                                        .textTheme.bodySmall
                                        ?.copyWith(
                                      color:
                                      const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ...widget.lastMultipliers
                                      .map(
                                        (m) => Padding(
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Container(
                                        padding:
                                        const EdgeInsets
                                            .symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration:
                                        BoxDecoration(
                                          color: m > 0
                                              ? const Color(
                                              0xFF22C55E)
                                              .withOpacity(
                                              0.12)
                                              : const Color(
                                              0xFF9CA3AF)
                                              .withOpacity(
                                              0.12),
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                              999),
                                        ),
                                        child: Text(
                                          'x$m',
                                          style: theme
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            color: m > 0
                                                ? const Color(
                                                0xFF15803D)
                                                : const Color(
                                                0xFF4B5563),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                      .toList(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                if (widget.lastResultMessage != null)
                  const SizedBox(height: 8),

                // Header bảng thưởng + nút Thu gọn
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFF7D6),
                            ),
                            child: const Icon(
                              Icons.card_giftcard_rounded,
                              size: 14,
                              color: kGoldDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Bảng thưởng',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onTogglePaytable,
                        child: Row(
                          children: [
                            Text(
                              widget.showPaytable
                                  ? 'Thu gọn'
                                  : 'Chi tiết',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: kBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              widget.showPaytable
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 18,
                              color: kBlue,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                if (widget.showPaytable)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                          12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6D8),
                        borderRadius:
                        BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFACC15)
                              .withOpacity(0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: const [
                          Padding(
                            padding:
                            EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Kết hợp biểu tượng · Nhân thưởng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                          _RewardRow(
                            icon: '7 7 7',
                            title: '7 (Jackpot)',
                            detail:
                            '3: x10   ·   4: x20   ·   5: x30',
                            highlight: true,
                          ),
                          SizedBox(height: 4),
                          _RewardRow(
                            icon: '💰 💰 💰',
                            title: 'Túi tiền',
                            detail:
                            '3: x5    ·   4: x10   ·   5: x15',
                          ),
                          SizedBox(height: 4),
                          _RewardRow(
                            icon: '⭐ ⭐ ⭐',
                            title: 'Ngôi sao',
                            detail:
                            '3: x3    ·   4: x6    ·   5: x9',
                          ),
                          SizedBox(height: 4),
                          _RewardRow(
                            icon: '🍒 🍒 🍒',
                            title: 'Cherry',
                            detail:
                            '3: x2    ·   4: x4    ·   5: x6',
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Đang cược
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.canSpin
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đang cược: ${widget.selectedBet} Xu/ván',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Nút Kéo cần
                Padding(
                  padding: const EdgeInsets.only(
                      left: 18, right: 18, bottom: 14),
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: widget.canSpin
                            ? const LinearGradient(
                          colors: [kBlueLight, kBlue],
                        )
                            : const LinearGradient(
                          colors: [
                            Color(0xFFCBD5E1),
                            Color(0xFFCBD5E1),
                          ],
                        ),
                        boxShadow: widget.canSpin
                            ? [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.16),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                            : [],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(24),
                          ),
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                        widget.canSpin ? widget.onSpin : null,
                        child: widget.spinning
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.casino_rounded,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Kéo cần',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w600,
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
          ),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            card,
            // Pháo hoa overlay
            IgnorePointer(
              child: SizedBox(
                width: cardWidth,
                height: reelHeight * 3,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiTop,
                        blastDirectionality:
                        BlastDirectionality.explosive,
                        shouldLoop: false,
                        emissionFrequency: 0.15,
                        numberOfParticles: 18,
                        maxBlastForce: 25,
                        minBlastForce: 8,
                        gravity: 0.35,
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: ConfettiWidget(
                        confettiController: _confettiCenter,
                        blastDirectionality:
                        BlastDirectionality.explosive,
                        shouldLoop: false,
                        emissionFrequency: 0.2,
                        numberOfParticles: 22,
                        maxBlastForce: 30,
                        minBlastForce: 10,
                        gravity: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ================== DÒNG BẢNG THƯỞNG ==================

class _RewardRow extends StatelessWidget {
  final String icon;
  final String title;
  final String detail;
  final bool highlight;

  const _RewardRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color chipBg =
    highlight ? const Color(0xFFFFF3C4) : Colors.white.withOpacity(0.95);
    final Color mainTextColor =
    highlight ? const Color(0xFF92400E) : const Color(0xFF111827);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // pill icon 3 hình
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.9),
              width: highlight ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            icon,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mainTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4B5563),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
