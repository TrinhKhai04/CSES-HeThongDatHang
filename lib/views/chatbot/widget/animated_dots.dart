import 'package:flutter/material.dart';

/// ============================================================================
/// ⚪ AnimatedDots
/// ----------------------------------------------------------------------------
/// Hiệu ứng "..." nhấp nháy giống Apple iMessage.
/// - Sử dụng AnimationController để thay đổi số lượng chấm theo thời gian.
/// ============================================================================
class AnimatedDots extends StatefulWidget {
  final Color color;
  const AnimatedDots({super.key, this.color = Colors.white});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 🔁 Chu kỳ 1 giây lặp lại
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        // frame = 1 → ".", 2 → "..", 3 → "..."
        final frame = (_controller.value * 3).floor() + 1;
        return Text(
          '.' * frame,
          style: TextStyle(
            fontSize: 20,
            color: widget.color,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        );
      },
    );
  }
}
