import 'package:cses/views/video/admin/admin_video_manager_screen.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 📦 AppRoutes.dart
/// ----------------------------------------------------------------------------
/// Gom toàn bộ routing của app về một nơi.
/// ============================================================================

// 🧱 Model
import '../models/app_order.dart'; // 🆕 dùng cho orderRoute

// 🌐 Common & Authentication
import '../views/common/app_nav_scaffold.dart';
import '../views/auth/splash_screen.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/register_screen.dart';
import '../views/auth/forgot_password_screen.dart';
import '../views/profile/change_password_screen.dart';

// 🛍️ User / Shop
import '../views/home/user_home_screen.dart';
import '../views/product/product_list_screen.dart';
import '../views/product/product_detail_screen.dart';
import '../views/cart/cart_screen.dart';
import '../views/checkout/checkout_screen.dart';

// ✅ Danh sách đơn theo tab (Shopee-style)
import '../views/orders/my_orders_page.dart';

// ✅ Màn chi tiết đơn (dùng chung cho user & admin)
import '../views/orders/order_detail_screen.dart';

// 🗺️ Bản đồ lộ trình đơn hàng
import '../views/orders/order_route_page.dart'; // 🆕

/// 🆕 Tra cứu đơn hàng (User)
import '../views/orders/user_order_lookup_screen.dart'; // 🆕

import '../views/profile/profile_screen.dart';
import '../views/profile/edit_profile_screen.dart';
import '../views/wishlist/wishlist_screen.dart';
import '../views/profile/active_vouchers_screen.dart';

// 🧭 Address Management
import '../views/profile/address_list_screen.dart';
import '../views/profile/address_form_screen.dart';

// 🆕 Phương thức thanh toán (User)
import '../views/profile/payment_methods_screen.dart'; // 🆕

// 🆕 Màn thanh toán chi tiết
import '../views/payment/payment_bank_transfer_screen.dart'; // 🆕
import '../views/payment/payment_momo_screen.dart'; // 🆕

// 🧩 Help / Support
import '../views/help/help_center_screen.dart';
import '../views/help/my_tickets_screen.dart';
import '../views/help/user_ticket_detail_screen.dart';

// ⚙️ Profile / Settings
import '../views/profile/user_settings_screen.dart';
import '../views/profile/policy_terms_screen.dart';

// 💬 Chatbot AI (Gemini)
import '../views/chatbot/chatbot_screen.dart';

// 🛠 Admin Views
import '../views/admin/admin_home_screen.dart';
import '../views/admin/products/admin_product_list_screen.dart';
import '../views/admin/products/admin_product_form_screen.dart';
import '../views/admin/brands/admin_brand_screen.dart';
import '../views/admin/categories/admin_category_screen.dart';
import '../views/admin/users/admin_users_screen.dart';
import '../views/admin/users/admin_user_detail_screen.dart';
import '../views/admin/orders/admin_orders_screen.dart';
import '../views/admin/vouchers/admin_voucher_screen.dart';
import '../views/admin/reports/admin_report_screen.dart';
import '../views/admin/banners/admin_banner_screen.dart';
import '../views/admin/support/admin_ticket_list_screen.dart';
import '../views/admin/support/admin_ticket_detail_screen.dart';
import '../views/admin/policies/admin_policy_screen.dart';

// 🆕 Màn cấu hình phí vận chuyển (Admin)
import '../views/admin/shipping/admin_shipping_config_screen.dart';

// 🆕 Màn quản lý Kho & Hub (Admin)
import '../views/admin/warehouse/warehouse_admin_page.dart';

// 🆕 Màn ưu đãi / điểm danh CSES Xu
import '../views/xu/xu_rewards_screen.dart';

// 🆕 Nông trại CSES Xu
import '../views/xu/xu_farm_screen.dart';

// 🆕 Thống kê mini-game Xu (Admin)
import '../views/admin/xu/admin_xu_minigame_stats_screen.dart';

// 🆕 Tra cứu đơn hàng (Admin)
import '../views/admin/support/admin_order_lookup_screen.dart';

// 🆕 Quản lý Xổ số Xu CSES (Admin)
import '../views/admin/xu/admin_xu_lottery_screen.dart'; // <= THÊM

// ✅✅✅ NEW: Video (Shopee-style)
import '../views/video/video_feed_screen.dart';
import '../views/video/admin/admin_upload_video_screen.dart';

class AppRoutes {
  // ========================================================================
  // 1️⃣ Common & Authentication
  // ========================================================================
  static const splash = '/splash';
  static const root = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot';
  static const userSettings = '/settings';

  // ========================================================================
  // 2️⃣ User / Shop
  // ========================================================================
  static const home = '/home';
  static const userHome = '/user/home';
  static const products = '/products';
  static const productDetail = '/product_detail';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders'; // MyOrdersPage (tabs)
  static const orderDetail = '/order_detail'; // OrderDetailScreen (user)

  // 🗺️ Lộ trình đơn hàng (map)
  static const orderRoute = '/order_route'; // 🆕

  // 🆕 Tra cứu đơn hàng (User)
  static const userOrderLookup = '/orders/lookup'; // 🆕

  static const profile = '/profile';
  static const editProfile = '/editProfile';
  static const wishlist = '/wishlist';
  static const userVouchers = '/vouchers';
  static const changePassword = '/change-password';

  // ⚡ CSES Xu
  static const xuRewards = '/xu/rewards';
  static const xuFarm = '/xu/farm';

  // ========================================================================
  // 3️⃣ Help Center / Support
  // ========================================================================
  static const helpCenter = '/help-center';
  static const myTickets = '/support/tickets';
  static const userTicketDetail = '/support/tickets/detail';

  // ========================================================================
  // 4️⃣ Address Management
  // ========================================================================
  static const addresses = '/settings/addresses';
  static const addressForm = '/settings/address_form';
  static const addressList = '/addresses';

  // 🆕 Payment Methods (User)
  static const paymentMethods = '/settings/payment-methods'; // list chọn
  static const paymentBankTransfer =
      '/payment/bank-transfer'; // màn QR ngân hàng
  static const paymentMomo = '/payment/momo'; // màn QR MoMo

  // ========================================================================
  // 5️⃣ Policy & Terms
  // ========================================================================
  static const policyTerms = '/policy-terms';
  static const adminPolicies = '/admin/policies';

  // ========================================================================
  // 6️⃣ Chatbot AI (Gemini)
  // ========================================================================
  static const chatbot = '/chatbot';

  // ========================================================================
  // 7️⃣ Admin
  // ========================================================================
  static const adminRoot = '/admin';
  static const adminProducts = '/admin/products';
  static const adminProductForm = '/admin/product_form';
  static const adminBrands = '/admin/brands';
  static const adminCategories = '/admin/categories';
  static const adminUsers = '/admin/users';
  static const adminUserDetail = '/admin/users/detail';
  static const adminOrders = '/admin/orders';
  static const adminVouchers = '/admin/vouchers';
  static const adminReports = '/admin/reports';
  static const adminBanners = '/admin/banners';
  static const adminTickets = '/admin/support';
  static const adminTicketDetail = '/admin/support/detail';

  /// 🔗 Alias để tương thích code cũ của Admin:
  /// nhiều nơi đang `pushNamed('/admin/order_detail', ...)`
  static const adminOrderDetail = '/admin/order_detail';

  /// 🆕 Route cấu hình phí vận chuyển
  static const adminShippingConfig = '/admin/shipping-config';

  /// 🆕 Route quản lý Kho & Hub
  static const adminWarehouses = '/admin/warehouses';

  /// 🆕 Route thống kê Mini-game Xu
  static const adminXuMiniGameStats = '/admin/xu-minigame-stats';

  /// 🆕 Route tra cứu đơn hàng (Admin)
  static const adminOrderLookup = '/admin/order_lookup';

  /// 🆕 Route quản lý Xổ số Xu CSES
  static const adminXuLottery = '/admin/xu-lottery'; // <= THÊM

  // ========================================================================
  // ✅✅✅ 8️⃣ Video (Shopee-style)
  // ========================================================================
  static const videoFeed = '/video';
  // static const adminUploadVideo = '/admin/video-upload';
  static const adminVideoManager = '/admin/video-manager';
  // ========================================================================
  // 🗺️ Map<String, WidgetBuilder>
  // ========================================================================
  static Map<String, WidgetBuilder> get routes => {
    // Common & Auth
    splash: (_) => const SplashScreen(),
    root: (_) => const AppNavScaffold(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),

    // User screens
    home: (_) => const UserHomeScreen(),
    userHome: (_) => const UserHomeScreen(),
    products: (_) => const ProductListScreen(),
    productDetail: (_) => const ProductDetailScreen(),
    cart: (_) => const CartScreen(),
    checkout: (_) => const CheckoutScreen(),
    orders: (_) => const MyOrdersPage(), // danh sách theo tab
    orderDetail: (_) => const OrderDetailScreen(), // chi tiết đơn (user)

    // 🗺️ Lộ trình đơn hàng (map)
    orderRoute: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      AppOrder? order;

      if (args is AppOrder) {
        order = args;
      } else if (args is Map) {
        final map = args as Map;
        if (map['order'] is AppOrder) {
          order = map['order'] as AppOrder;
        }
      }

      if (order == null) {
        return const Scaffold(
          body: Center(child: Text('Không tìm thấy đơn hàng')),
        );
      }

      return OrderRoutePage(order: order);
    },

    // 🆕 Tra cứu đơn hàng (User)
    userOrderLookup: (_) => const UserOrderLookupScreen(), // 🆕

    profile: (_) => const ProfileScreen(),
    editProfile: (_) => const EditProfileScreen(),
    userSettings: (_) => const UserSettingsScreen(),
    wishlist: (_) => const WishlistScreen(),
    userVouchers: (_) => const ActiveVouchersScreen(),
    changePassword: (_) => const ChangePasswordScreen(),

    // ⚡ CSES Xu
    xuRewards: (_) => const XuRewardsScreen(),
    xuFarm: (_) => const XuFarmScreen(),

    // Help Center
    helpCenter: (_) => const HelpCenterScreen(),
    myTickets: (_) => const MyTicketsScreen(),
    userTicketDetail: (_) => const UserTicketDetailScreen(),

    // Address
    addresses: (_) => const AddressListScreen(),
    addressForm: (_) => const AddressFormScreen(),
    addressList: (_) => const AddressListScreen(),

    // 🆕 Payment Methods & payment detail
    paymentMethods: (_) => const PaymentMethodsScreen(),
    paymentBankTransfer: (_) => const PaymentBankTransferScreen(),
    paymentMomo: (_) => const PaymentMomoScreen(),

    // Policy & Terms
    policyTerms: (_) => const PolicyTermsScreen(),
    adminPolicies: (_) => const AdminPolicyScreen(),

    // Chatbot
    chatbot: (_) => const ChatbotScreen(),

    // Admin
    adminRoot: (_) => const AdminHomeScreen(),
    adminProducts: (_) => const AdminProductListScreen(),
    adminProductForm: (_) => const AdminProductFormScreen(),
    adminBrands: (_) => const AdminBrandScreen(),
    adminCategories: (_) => const AdminCategoryScreen(),
    adminUsers: (_) => const AdminUsersScreen(),
    adminUserDetail: (_) => const AdminUserDetailScreen(),
    adminOrders: (_) => const AdminOrdersScreen(),
    adminVouchers: (_) => const AdminVoucherScreen(),
    adminReports: (_) => const AdminReportScreen(),
    adminBanners: (_) => const AdminBannerScreen(),
    adminTickets: (_) => const AdminTicketListScreen(),
    adminTicketDetail: (_) => const AdminTicketDetailScreen(),

    // 🔗 Admin alias -> dùng chung màn chi tiết đơn
    adminOrderDetail: (_) => const OrderDetailScreen(),

    // 🆕 Cấu hình phí vận chuyển
    adminShippingConfig: (_) => const AdminShippingConfigScreen(),

    // 🆕 Quản lý Kho & Hub
    adminWarehouses: (_) => const WarehouseAdminPage(),

    // 🆕 Thống kê mini-game Xu
    adminXuMiniGameStats: (_) => const AdminXuMiniGameStatsScreen(),

    // 🆕 Tra cứu đơn hàng (Admin)
    adminOrderLookup: (_) => const AdminOrderLookupScreen(),

    // 🆕 Quản lý Xổ số Xu CSES (Admin)
    adminXuLottery: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String adminId = '';

      if (args is Map && args['adminId'] is String) {
        adminId = args['adminId'] as String;
      }

      return AdminXuLotteryScreen(adminId: adminId);
    },

    // ✅✅✅ Video (Shopee-style)
    videoFeed: (_) => const VideoFeedScreen(),
    // adminUploadVideo: (_) => const AdminUploadVideoScreen(),
    adminVideoManager: (_) => const AdminVideoManagerScreen(),
  };
}
