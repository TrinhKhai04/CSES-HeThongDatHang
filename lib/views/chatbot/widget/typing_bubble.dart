import 'package:flutter/material.dart';
import 'animated_dots.dart';

/// ============================================================================
/// 💭 TypingBubble
/// ----------------------------------------------------------------------------
/// Bong bóng "AI đang nhập..." hiển thị khi ChatController.isTyping = true.
/// ============================================================================
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft, // AI nhắn bên trái
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const AnimatedDots(color: Colors.black54),
      ),
    );
  }
}
