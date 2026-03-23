// 📦 Import các gói Flutter cần thiết
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Cho Clipboard & ClipboardData
import 'package:provider/provider.dart';

// 📂 Import các module nội bộ của dự án
import '../../controllers/chat_controller.dart';
import '../../models/chat_message.dart';
import '../../routes/app_routes.dart';

/// ============================================================================
/// 💬 ChatbotScreen — Trợ lý AI CSES (Apple-style, hỗ trợ Dark/Light)
/// ----------------------------------------------------------------------------
/// ✅ Lịch sử chat (user + AI)
/// ✅ Card sản phẩm thật + card voucher
/// ✅ Hiệu ứng "AI đang nhập..." (… nhấp nháy)
/// ✅ Tự cuộn xuống khi có tin nhắn mới
/// ✅ Màu sắc lấy từ Theme/ColorScheme (không hard-code), đẹp trong Dark mode
/// ============================================================================
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputCtl = TextEditingController();   // Controller cho ô nhập
  final _scrollCtl = ScrollController();       // Controller cho ListView
  bool _greeted = false;                       // Tránh chào lặp khi rebuild

  @override
  void initState() {
    super.initState();
    // 🧠 Gọi lời chào của AI sau khi màn hình đã mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_greeted) {
        _greeted = true;
        Provider.of<ChatController>(context, listen: false).greetUser();
      }
    });
  }

  @override
  void dispose() {
    _inputCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  // 📜 Tự động cuộn xuống cuối mỗi khi có tin nhắn mới
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();   // Lấy ChatController
    final messages = chat.messages;

    // Mỗi lần danh sách đổi → cuộn xuống cuối
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface, // ✅ ăn theo Theme
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Trợ lý AI CSES',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // 🗨️ Danh sách tin nhắn
            Expanded(
              child: ListView.builder(
                controller: _scrollCtl,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                itemCount: messages.length + (chat.isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  // ⏳ hiệu ứng “AI đang nhập...”
                  if (index == messages.length && chat.isTyping) {
                    return const _TypingBubble();
                  }

                  final msg = messages[index];

                  // 🛍️ Nhiều sản phẩm
                  if (msg.products != null && msg.products!.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        msg.products!.length,
                            (i) => Align(
                          alignment: Alignment.centerLeft,
                          child: _ProductCard(product: msg.products![i]),
                        ),
                      ),
                    );
                  }

                  // 🎁 Nhiều voucher
                  if (msg.vouchers != null && msg.vouchers!.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        msg.vouchers!.length,
                            (i) => Align(
                          alignment: Alignment.centerLeft,
                          child: _VoucherCard(voucher: msg.vouchers![i]),
                        ),
                      ),
                    );
                  }

                  // 🧩 1 sản phẩm
                  if (msg.product != null) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: _ProductCard(product: msg.product!),
                    );
                  }

                  // 💬 Tin nhắn text
                  return _Bubble(msg: msg);
                },
              ),
            ),

            // ✍️ Thanh nhập tin nhắn
            _InputBar(
              controller: _inputCtl,
              onSend: () => _handleSend(chat),
            ),
          ],
        ),
      ),
    );
  }

  // 📩 Gửi tin nhắn người dùng
  void _handleSend(ChatController chat) {
    final text = _inputCtl.text.trim();
    if (text.isEmpty) return;
    chat.sendMessage(text);
    _inputCtl.clear();
    FocusScope.of(context).unfocus();
  }
}

/// ============================================================================
/// 💬 _Bubble — Bong bóng tin nhắn (Apple-style, Dark/Light)
/// ============================================================================
class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isUser = msg.isUser;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

    // 🎨 Màu bong bóng: user = primary; bot = màu xám nhẹ theo theme
    final bubbleColor = isUser
        ? cs.primary
        : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F2F6));
    final textColor = isUser ? cs.onPrimary : cs.onSurface;

    final maxWidth = MediaQuery.of(context).size.width * 0.8;

    final child = isUser
        ? Text(
      msg.text,
      style: TextStyle(color: textColor, fontSize: 16, height: 1.35),
    )
        : SelectableText(
      msg.text,
      style: TextStyle(color: textColor, fontSize: 16, height: 1.35),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ============================================================================
/// ✍️ _InputBar — Ô nhập + nút gửi (Material 3, theo Theme)
/// ============================================================================
class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        color: cs.surface,
        padding: EdgeInsets.fromLTRB(
          10, 8, 10, 8 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Row(
          children: [
            // 📝 Ô nhập
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn…',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest, // ✅ đẹp trong Dark
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            // 📤 Nút gửi
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              tooltip: 'Gửi',
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 💭 _TypingBubble — hiệu ứng “AI đang nhập...”
/// ============================================================================
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _AnimatedDots(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// ⚪ _AnimatedDots — tạo hiệu ứng “...” nhấp nháy
class _AnimatedDots extends StatefulWidget {
  final Color color;
  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final frame = (_ctl.value * 3).floor() + 1;
        return Text(
          '.' * frame,
          style: TextStyle(
            fontSize: 18,
            color: widget.color,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// 🛍️ _ProductCard — Hiển thị sản phẩm trong khung chat (theo Theme)
/// ============================================================================
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final name = product['name'] ?? '';
    final price = product['price'] ?? 0;
    final desc = product['description'] ?? '';
    final image = product['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        if (product['id'] != null) {
          Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product['id']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy ID sản phẩm')),
          );
        }
      },
      child: Card(
        color: cs.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼 Ảnh sản phẩm
            if (image.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  image,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.image_not_supported_outlined,
                        size: 50, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            // 📝 Thông tin sản phẩm
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$price₫",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
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
}

/// ============================================================================
/// 🎁 _VoucherCard — Hiển thị voucher (Apple-style, theo Theme)
/// ============================================================================
class _VoucherCard extends StatelessWidget {
  final Map<String, dynamic> voucher;
  const _VoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final code = voucher['code'] ?? '';
    final desc = voucher['description'] ?? '';
    final discount = voucher['discount'] ?? '';
    final minOrder = voucher['minOrder'] ?? 0;

    return Card(
      color: cs.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🎁 Icon nền primary
            Container(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.card_giftcard, color: cs.onPrimary, size: 28),
            ),
            const SizedBox(width: 12),

            // 📄 Nội dung voucher
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurface),
                  ),
                  if (discount.toString().isNotEmpty)
                    Text('Giảm $discount%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        )),
                  if (minOrder != 0)
                    Text('Áp dụng cho đơn từ ${minOrder}₫',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 📋 Sao chép mã
            IconButton(
              icon: Icon(Icons.copy, color: cs.primary),
              tooltip: 'Sao chép mã',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã sao chép mã $code'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
