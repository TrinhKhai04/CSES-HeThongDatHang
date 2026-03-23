import 'package:cloud_firestore/cloud_firestore.dart';
import 'gemini_service.dart';

/// ================================================================
/// 🤖 Trợ lý AI CSES
/// ------------------------------------------------
/// - Đọc dữ liệu thật từ Firestore
/// - Gửi prompt cho GeminiService.ask()
/// - Hỗ trợ dữ liệu sản phẩm & voucher
/// ================================================================
class CsesAiAssistant {
  final _firestore = FirebaseFirestore.instance;
  final GeminiService _gemini;

  CsesAiAssistant(this._gemini);

  /// 🧩 Lấy danh sách sản phẩm
  Future<String> _fetchProductsText() async {
    final snapshot = await _firestore.collection('products').limit(10).get();
    if (snapshot.docs.isEmpty) return "Không có sản phẩm nào.";

    final items = snapshot.docs.map((doc) {
      final d = doc.data();
      final name = d['name'] ?? '';
      final price = d['price'] ?? 0;
      final desc = d['description'] ?? '';
      return "- $name: $desc (Giá: ${price.toString()}₫)";
    }).join("\n");

    return "🛍️ Danh sách sản phẩm:\n$items";
  }

  /// 🎟️ Lấy danh sách voucher
  Future<String> _fetchVouchersText() async {
    final snapshot = await _firestore
        .collection('vouchers')
        .where('active', isEqualTo: true)
        .get();
    if (snapshot.docs.isEmpty) return "Không có voucher nào đang hoạt động.";

    final items = snapshot.docs.map((doc) {
      final d = doc.data();
      final code = d['code'] ?? '';
      final desc = d['description'] ?? '';
      return "- $code: $desc";
    }).join("\n");

    return "🎫 Voucher khả dụng:\n$items";
  }

  /// 💬 Trả lời dựa trên dữ liệu Firestore
  Future<String> ask(String userMessage) async {
    final products = await _fetchProductsText();
    final vouchers = await _fetchVouchersText();

    final context = """
Dữ liệu thật của cửa hàng Apple CSES:
----------------------------------------
$products

$vouchers

Câu hỏi của khách: "$userMessage"
----------------------------------------
""";

    return _gemini.ask("""
Hãy trả lời dựa trên dữ liệu trên.
Nếu có thể, gợi ý sản phẩm phù hợp và voucher đang áp dụng.
Ngôn ngữ: Tiếng Việt, giọng điệu thân thiện như nhân viên Apple Store.
$context
""");
  }
}
