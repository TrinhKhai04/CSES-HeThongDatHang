import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

/// ============================================================================
/// 💬 ChatFloatingButton — Apple Store style (giữ nguyên vị trí)
/// - Kích thước 60x60, tròn.
/// - Gradient Apple Blue + viền mảnh sáng.
/// - Bóng đổ mềm, có ripple khi chạm.
/// - Hover/press scale mượt (web/desktop).
/// - Backdrop blur nhẹ (glass-look).
/// - Tuỳ chọn badge số tin chưa đọc.
/// ============================================================================
class ChatFloatingButton extends StatefulWidget {
  final Color color;            // màu chủ đạo (mặc định Apple Blue)
  final int unreadCount;        // badge chưa đọc (0 = ẩn)
  final VoidCallback? onTap;    // nếu null -> điều hướng đến chatbot

  const ChatFloatingButton({
    super.key,
    this.color = const Color(0xFF007AFF),
    this.unreadCount = 0,
    this.onTap,
  });

  @override
  State<ChatFloatingButton> createState() => _ChatFloatingButtonState();
}

class _ChatFloatingButtonState extends State<ChatFloatingButton> {
  bool _hovering = false;
  bool _pressing = false;

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.pushNamed(context, AppRoutes.chatbot);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Giữ NGUYÊN vị trí như yêu cầu
    return Positioned(
      bottom: 260,
      right: 20,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          label: 'Mở trợ lý AI CSES',
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressing = true),
            onTapUp: (_) => setState(() => _pressing = false),
            onTapCancel: () => setState(() => _pressing = false),
            onTap: _handleTap,
            child: AnimatedScale(
              scale: _pressing
                  ? 0.94
                  : (_hovering ? 1.03 : 1.0), // scale nhẹ kiểu iOS
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Lớp blur nhẹ phía sau để tạo cảm giác “glass”
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Gradient Apple Blue nhã
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0A84FF),         // iOS systemBlue tint
                              widget.color,                    // #007AFF mặc định
                            ],
                          ),
                          // Viền mảnh sáng + bóng mềm
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000), // đổ bóng mềm
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.chat_bubble_text_fill,
                            color: Colors.white,
                            size: 26, // hơi nhỏ hơn 28 cho tinh tế
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Badge chưa đọc (tùy chọn)
                  if (widget.unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: _Badge(count: widget.unreadCount),
                    ),

                  // Ink ripple chuẩn Material (đặt đè, vẫn giữ gradient bên dưới)
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.15),
                        highlightColor: Colors.white.withOpacity(0.05),
                        onTap: _handleTap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge tròn đỏ nhỏ kiểu iOS (SFSymbol style)
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = (count > 99) ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30), // iOS systemRed
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
