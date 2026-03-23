class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt;

  // 🔹 Nếu chỉ 1 sản phẩm
  final Map<String, dynamic>? product;

  // 🔹 Nếu nhiều sản phẩm
  final List<Map<String, dynamic>>? products;

  final List<Map<String, dynamic>>? vouchers; // ✅ Danh sách voucher (mới thêm)

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.product,
    this.products,
    this.vouchers,
  });
}
