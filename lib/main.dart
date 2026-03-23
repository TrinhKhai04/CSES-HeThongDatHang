 // ============================================================
// 🧠 CSES Main Entry Point — Phiên bản hoàn chỉnh (2025)
// ------------------------------------------------------------
// ✅ Fix triệt để lỗi: NotInitializedError / Missing GEMINI_API_KEY
// ✅ Dùng chung file env.json cho Web + Android/iOS
// ✅ Tự động khởi tạo Firebase, Firestore cache, SharedPreferences
// ✅ MultiProvider: Auth, Cart, Product, Chat, Xu, v.v.
// ============================================================

import 'dart:convert';                           // jsonDecode (đọc file env.json)
import 'package:flutter/foundation.dart';        // kIsWeb nếu cần
import 'package:flutter/services.dart';          // rootBundle.loadString
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 🔥 Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🖋️ Fonts, đa ngôn ngữ, và cấu hình
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 📦 Cấu hình project
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

// 👑 Controllers chính
import 'controllers/auth_controller.dart';
import 'controllers/admin_product_controller.dart';
import 'controllers/product_controller.dart';
import 'controllers/cart_controller.dart';
import 'controllers/order_controller.dart';
import 'controllers/user_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/wishlist_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/address_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/xu_controller.dart'; // 👈 XuController

// 🏭 Cấu hình kho / hub
import 'config/warehouse_config.dart';

// ============================================================
// 🚀 MAIN FUNCTION — Khởi động toàn bộ ứng dụng
// ============================================================
Future<void> main() async {
  // 1️⃣ Đảm bảo Flutter đã khởi tạo xong (rất quan trọng cho async)
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // 🔐 2️⃣ NẠP ENV (Gemini API key) từ assets/config/env.json
  // ============================================================
  try {
    final raw = await rootBundle.loadString('assets/config/env.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    dotenv.testLoad(
      fileInput: data.entries.map((e) => '${e.key}=${e.value}').join('\n'),
    );

    final masked = (dotenv.env['GEMINI_API_KEY'] ?? '')
        .replaceAll(RegExp('.(?=.{4})'), '*');
    debugPrint('🔑 Env loaded OK: GEMINI_API_KEY=$masked');
  } catch (e) {
    debugPrint('❌ Cannot load env.json. Error: $e');
  }

  // ============================================================
  // 🔥 3️⃣ KHỞI TẠO FIREBASE + FIRESTORE CACHE
  // ============================================================
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  // 🏭 3.1 Load cấu hình kho từ Firestore (nếu có)
  await WarehouseConfig.loadFromFirestoreIfAny();

  // (DEV) Nếu muốn seed dữ liệu kho mặc định lần đầu:
  // await WarehouseConfig.seedToFirestoreIfEmpty();

  // Ngăn GoogleFonts fetch runtime để tránh crash khi offline
  GoogleFonts.config.allowRuntimeFetching = false;

  final app = Firebase.app();
  debugPrint('🔥 Firebase connected: projectId=${app.options.projectId}');

  // ============================================================
  // 💾 4️⃣ SharedPreferences (cho SettingsController)
  // ============================================================
  final prefs = await SharedPreferences.getInstance();

  // ============================================================
  // 🧱 5️⃣ Run App
  // ============================================================
  runApp(MyApp(prefs: prefs));
}

// ============================================================
// 🎨 LỚP ỨNG DỤNG CHÍNH — MultiProvider + Theme + Locale
// ============================================================
class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --------------------------------------------------------
        // 🧠 Các Controllers chính
        // --------------------------------------------------------
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => AdminProductController()),
        ChangeNotifierProvider(
          create: (_) => ProductController()..fetch(keyword: ''),
        ),
        ChangeNotifierProvider(create: (_) => OrderController()),
        ChangeNotifierProvider(create: (_) => UserController()),
        ChangeNotifierProvider(create: (_) => NotificationController()),
        ChangeNotifierProvider(create: (_) => WishlistController()),
        ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
        ChangeNotifierProvider(create: (_) => AddressController()),

        // --------------------------------------------------------
        // 🪙 XuController phụ thuộc Auth → tự load Xu theo uid
        // --------------------------------------------------------
        ChangeNotifierProxyProvider<AuthController, XuController>(
          create: (_) => XuController(),
          update: (_, auth, xu) {
            xu ??= XuController();
            final uid = auth.user?.uid;
            if (uid != null && uid.isNotEmpty) {
              // fire-and-forget, XuController tự set isLoading
              xu.load(uid);
            }
            return xu;
          },
        ),

        // --------------------------------------------------------
        // 💬 Gemini-AI Chatbot Controller
        // --------------------------------------------------------
        ChangeNotifierProvider(create: (_) => ChatController()),

        // --------------------------------------------------------
        // 🛒 CartController phụ thuộc vào AuthController
        // --------------------------------------------------------
        ChangeNotifierProxyProvider<AuthController, CartController>(
          create: (_) => CartController(),
          update: (_, auth, cart) {
            cart ??= CartController();
            final uid = auth.user?.uid;
            if (uid == null) {
              // ❌ Nếu người dùng đăng xuất → tách giỏ hàng
              cart.detach();
            } else {
              // ✅ Nếu đăng nhập → gắn giỏ hàng với UID
              cart.attachToUser(uid);
            }
            return cart;
          },
        ),
      ],

      // ============================================================
      // 🎨 Theme, Ngôn ngữ, Routes
      // ============================================================
      child: Consumer<SettingsController>(
        builder: (context, s, _) {
          return MaterialApp(
            title: 'CSES',
            debugShowCheckedModeBanner: false,

            // 🎨 Chủ đề giao diện (Light / Dark)
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: s.darkMode ? ThemeMode.dark : ThemeMode.light,

            // 🌍 Đa ngôn ngữ
            locale: Locale(s.language, s.language == 'vi' ? 'VN' : 'US'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('vi', 'VN'),
            ],

            // 🚪 Điều hướng toàn ứng dụng
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
