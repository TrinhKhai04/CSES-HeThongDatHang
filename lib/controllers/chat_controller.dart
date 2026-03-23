import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';

/// ============================================================================
/// 🤖 CSES SmartChatController v3.6 — Phiên bản mở rộng & chủ động
/// ----------------------------------------------------------------------------
/// ✅ AI chào người dùng khi mở chat
/// ✅ Gợi ý voucher khi nhắc đến khuyến mãi / giảm giá
/// ✅ Hỗ trợ nhiều sản phẩm trong 1 phản hồi
/// ✅ Fuzzy match thông minh (so khớp gần đúng, bỏ dấu)
/// ✅ Dữ liệu thật từ Firestore (products + vouchers)
/// ============================================================================
class ChatController extends ChangeNotifier {
  // 💬 Danh sách tin nhắn (lịch sử chat)
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // ⚙️ Dịch vụ AI + trạng thái
  GeminiService? _gemini;
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _hasGreeted = false; // ✅ Để AI chỉ chào 1 lần khi mở app

  // ==========================================================================
  // 🚀 GỬI TIN NHẮN NGƯỜI DÙNG
  // ==========================================================================
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 🧩 1️⃣ Thêm tin nhắn người dùng vào danh sách
    _messages.add(ChatMessage(
      text: text.trim(),
      isUser: true,
      createdAt: DateTime.now(),
    ));
    notifyListeners();

    // 🧠 2️⃣ Gọi AI phản hồi
    await _reply(userInput: text.trim());
  }

  // ==========================================================================
  // 🤖 PHẢN HỒI TỪ GEMINI (STREAM)
  // ==========================================================================
  Future<void> _reply({required String userInput}) async {
    _isTyping = true;
    notifyListeners();

    // Thêm tin nhắn trống để stream nội dung vào
    _messages.add(ChatMessage(text: "", isUser: false, createdAt: DateTime.now()));
    final int aiIndex = _messages.length - 1;

    try {
      _gemini ??= _initGemini();

      // 🔹 Lấy dữ liệu thật từ Firestore
      final products = await _fetchProducts(limit: 30);
      final vouchers = await _fetchVouchers();

      // 🔹 Tạo prompt gửi cho Gemini
      final productText = products
          .map((p) => "- ${p['name']}: ${p['description']} (Giá: ${p['price']}₫)")
          .join("\n");

      final voucherText = vouchers
          .map((v) => "- ${v['code']}: ${v['description']}")
          .join("\n");

      final prompt = """
Bạn là Trợ lý AI của cửa hàng CSES.
Hãy trả lời thân thiện, chuyên nghiệp, tự nhiên, ngắn gọn.

Dưới đây là dữ liệu thật của cửa hàng:

🛍️ Sản phẩm:
$productText

🎫 Voucher:
$voucherText

Người dùng hỏi: "$userInput"
""";

      final stream = _gemini!.stream(prompt);
      String finalText = "";

      await for (final chunk in stream) {
        finalText = chunk;
        _messages[aiIndex] = ChatMessage(
          text: chunk,
          isUser: false,
          createdAt: DateTime.now(),
        );
        notifyListeners();
      }

      // 🔍 Phân tích phản hồi để tìm sản phẩm hoặc voucher
      await _detectAndAttachCards(finalText, products, vouchers);
    } catch (e, st) {
      debugPrint("⚠️ ChatController error: $e\n$st");
      _messages[aiIndex] = ChatMessage(
        text: "⚠️ Lỗi khi kết nối AI: $e",
        isUser: false,
        createdAt: DateTime.now(),
      );
      notifyListeners();
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // 🧩 DÒ SẢN PHẨM & VOUCHER TRONG PHẢN HỒI AI
  // ==========================================================================
  Future<void> _detectAndAttachCards(
      String finalText,
      List<Map<String, dynamic>> products,
      List<Map<String, dynamic>> vouchers,
      ) async {
    final normalizedReply = removeDiacritics(finalText.toLowerCase());

    // 🛍️ 1️⃣ Dò sản phẩm nhắc tới
    final List<Map<String, dynamic>> detectedProducts = [];
    for (final p in products) {
      final rawName = (p['name'] ?? '').toString();
      if (rawName.isEmpty) continue;

      final normalizedName = removeDiacritics(rawName.toLowerCase());
      final keywords = normalizedName
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .toList();

      int matchCount = 0;
      for (final k in keywords) {
        if (normalizedReply.contains(k)) matchCount++;
      }

      if (matchCount / keywords.length > 0.5) {
        detectedProducts.add(p);
      }
    }

    // 🧾 2️⃣ Dò voucher nhắc tới
    final List<Map<String, dynamic>> detectedVouchers = [];
    if (normalizedReply.contains("voucher") ||
        normalizedReply.contains("giam gia") ||
        normalizedReply.contains("khuyen mai")) {
      detectedVouchers.addAll(vouchers.take(3)); // Giới hạn 3 voucher hiển thị
    }

    // 🪄 3️⃣ Hiển thị các card sản phẩm hoặc voucher
    if (detectedProducts.isNotEmpty) {
      _messages.add(ChatMessage(
        text: "Sản phẩm liên quan:",
        isUser: false,
        createdAt: DateTime.now(),
        products: detectedProducts,
      ));
      notifyListeners();
    }

    if (detectedVouchers.isNotEmpty) {
      _messages.add(ChatMessage(
        text: "Các voucher hiện có:",
        isUser: false,
        createdAt: DateTime.now(),
        vouchers: detectedVouchers,
      ));
      notifyListeners();
    }
  }

  // ==========================================================================
  // 🧠 KHỞI TẠO GEMINI SERVICE
  // ==========================================================================
  GeminiService _initGemini() {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception("❌ Missing GEMINI_API_KEY — chưa load từ .env hoặc env.json");
    }
    debugPrint('🤖 GeminiService initialized');
    return GeminiService();
  }

  // ==========================================================================
  // 🧩 AI CHÀO CHỦ ĐỘNG KHI MỞ APP
  // ==========================================================================
  Future<void> greetUser() async {
    if (_hasGreeted) return; // chỉ chào 1 lần
    _hasGreeted = true;

    _messages.add(ChatMessage(
      text:
      "Chào bạn! 👋 Rất vui được hỗ trợ bạn hôm nay. Bạn muốn xem sản phẩm nổi bật hay voucher giảm giá ạ?",
      isUser: false,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // ==========================================================================
  // 🔹 LẤY DANH SÁCH SẢN PHẨM TỪ FIRESTORE
  // ==========================================================================
  Future<List<Map<String, dynamic>>> _fetchProducts({int limit = 40}) async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .limit(limit)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': data['name'] ?? '',
        'description': data['description'] ?? '',
        'price': data['price'] ?? 0,
        'sku': data['sku'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
      };
    }).toList();
  }

  // ==========================================================================
  // 🔹 LẤY DANH SÁCH VOUCHER TỪ FIRESTORE
  // ==========================================================================
  Future<List<Map<String, dynamic>>> _fetchVouchers() async {
    final snap = await FirebaseFirestore.instance
        .collection('vouchers')
        .where('active', isEqualTo: true)
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ==========================================================================
  // 🧹 XÓA LỊCH SỬ CHAT
  // ==========================================================================
  void clear() {
    _messages.clear();
    notifyListeners();
  }
}
