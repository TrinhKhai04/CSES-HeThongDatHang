import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// ============================================================================
/// 🤖 GeminiService (v3 — an toàn & hỗ trợ streaming realtime)
/// ----------------------------------------------------------------------------
/// - Tự động kiểm tra dotenv đã load chưa (tránh crash)
/// - Model mặc định: gemini-2.5-flash
/// - Hai chế độ:
///   1️⃣ ask(prompt): trả về câu trả lời hoàn chỉnh
///   2️⃣ stream(prompt): trả về từng phần realtime (giống ChatGPT)
/// ============================================================================
class GeminiService {
  late final GenerativeModel _model;

  GeminiService({String modelName = 'gemini-2.5-flash'}) {
    // ============================================================
    // 🧩 Kiểm tra dotenv có sẵn chưa
    // ============================================================
    if (!dotenv.isInitialized) {
      debugPrint('⚠️ dotenv chưa được khởi tạo — dùng env tạm để tránh crash.');
      dotenv.testLoad(); // tạo env rỗng an toàn
    }

    // ============================================================
    // 🔑 Lấy API key an toàn (không ném lỗi nếu chưa có)
    // ============================================================
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY') ?? '';

    if (apiKey.isEmpty) {
      debugPrint('❌ GEMINI_API_KEY chưa được cấu hình. Vui lòng kiểm tra .env hoặc env.json!');
      throw Exception('Missing GEMINI_API_KEY');
    }

    // ============================================================
    // ✅ Khởi tạo model
    // ============================================================
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );
    debugPrint('🤖 GeminiService initialized with model: $modelName');
  }

  // ===========================================================================
  // 💬 1️⃣ ask(): gọi một lần, trả về toàn bộ text
  // ===========================================================================
  Future<String> ask(String prompt) async {
    try {
      if (prompt.trim().isEmpty) return "Bạn vui lòng nhập câu hỏi cụ thể hơn nhé.";

      final response = await _model.generateContent([
        Content.text("""
Bạn là Trợ lý AI của cửa hàng Apple CSES.
Hãy trả lời ngắn gọn, thân thiện, chuyên nghiệp như nhân viên Apple Store.
---
$prompt
""")
      ]);

      return response.text?.trim() ?? "Xin lỗi, tôi chưa hiểu câu hỏi này.";
    } catch (e, st) {
      debugPrint('⚠️ Gemini ask() error: $e\n$st');
      return "Lỗi khi kết nối đến AI, vui lòng thử lại sau.";
    }
  }

  // ===========================================================================
  // ⚡️ 2️⃣ stream(): phát dần nội dung realtime (giống ChatGPT)
  // ===========================================================================
  Stream<String> stream(String prompt) async* {
    if (prompt.trim().isEmpty) {
      yield "Bạn vui lòng nhập câu hỏi cụ thể hơn nhé.";
      return;
    }

    try {
      final stream = _model.generateContentStream([
        Content.text("""
Bạn là Trợ lý AI của cửa hàng Apple CSES.
Hãy trả lời thân thiện, tự nhiên, lịch sự, như nhân viên Apple Store.
---
$prompt
""")
      ]);

      String buffer = '';

      await for (final event in stream) {
        final chunk = event.text ?? '';
        if (chunk.isNotEmpty) {
          buffer += chunk;
          yield buffer; // 👈 phát dần nội dung
        }
      }

      if (buffer.isEmpty) yield "Xin lỗi, tôi chưa hiểu câu hỏi này.";
    } catch (e, st) {
      debugPrint('⚠️ Gemini stream() error: $e\n$st');
      yield "Lỗi khi kết nối tới AI, vui lòng thử lại sau.";
    }
  }
}
