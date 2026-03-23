import 'package:flutter/material.dart';

// 📱 Tabs / Screens chính của người dùng
import '../home/user_home_screen.dart';
import '../product/product_list_screen.dart';
import '../cart/cart_screen.dart';
// ⬇️ DÙNG MÀN MỚI LỌC THEO TRẠNG THÁI
import '../orders/my_orders_page.dart';
import '../profile/profile_screen.dart';
import '../wishlist/wishlist_screen.dart';

// ✅ NEW: Video Feed (Shopee-style)
import '../video/video_feed_screen.dart';

// 🧭 Drawer (menu bên trái)
import '../home/widgets/user_drawer.dart';

// 💬 Bong bóng chat nổi toàn cục (Apple-style)
import '../common/chat_floating_button.dart';

/// ============================================================================
/// 🍏 AppNavScaffold — Khung điều hướng chính (Apple-style, chuẩn Dark/Light)
/// ----------------------------------------------------------------------------
/// - Quản lý 7 tab: Home, Products, Favorites, Cart, Orders, Account, Video
/// - Giữ state bằng IndexedStack (chuyển tab mượt, không reload UI)
/// - Dùng ColorScheme → auto thích ứng Dark/Light (không bị thanh dưới màu trắng)
/// - extendBody: true để nền nội dung “tràn” dưới BottomBar (tránh gờ/viền lạ)
/// - Có helper goToTab / goToCart để điều hướng nhanh.
/// ============================================================================
/// ✅ Thêm Video ở CUỐI để KHÔNG đổi index tab cũ:
/// 0 Home | 1 Products | 2 Favorites | 3 Cart | 4 Orders | 5 Account | 6 Video
/// ============================================================================

class AppNavScaffold extends StatefulWidget {
  final int? initialTab;
  const AppNavScaffold({super.key, this.initialTab});

  // 🧭 Helper: Chuyển đến tab chỉ định và loại bỏ stack cũ
  static void goToTab(BuildContext context, int tab) {
    final safeTab = (tab < 0 || tab > 6) ? 0 : tab; // ✅ max tab = 6
    _AppNavScaffoldState._lastTabIndex = safeTab;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppNavScaffold(initialTab: safeTab)),
          (r) => false,
    );
  }

  // 🛒 Helper: đi thẳng đến tab Giỏ hàng (Cart) — GIỮ NGUYÊN index = 3
  static void goToCart(BuildContext context) => goToTab(context, 3);

  @override
  State<AppNavScaffold> createState() => _AppNavScaffoldState();
}

class _AppNavScaffoldState extends State<AppNavScaffold> {
  // 🔢 Lưu lại tab cuối cùng khi quay lại từ màn khác
  static int _lastTabIndex = 0;
  int idx = 0;
  bool _handledInitialArgs = false;

  // 0 Home | 1 Products | 2 Favorites | 3 Cart | 4 Orders | 5 Account | 6 Video
  final pages = const [
    UserHomeScreen(),
    ProductListScreen(),
    WishlistScreen(),
    CartScreen(),
    MyOrdersPage(), // ⬅️ ĐÃ ĐỔI TỪ OrdersScreen SANG MyOrdersPage
    ProfileScreen(),
    VideoFeedScreen(), // ✅ NEW (thêm cuối)
  ];

  @override
  void initState() {
    super.initState();
    // Nếu truyền initialTab thì ưu tiên, không thì dùng tab đã lưu
    final init = widget.initialTab ?? _lastTabIndex;
    idx = (init < 0 || init >= pages.length) ? 0 : init;
    _lastTabIndex = idx;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hỗ trợ chuyển tab qua route arguments: Navigator.pushNamed(..., arguments: {'tab': 4})
    if (_handledInitialArgs || widget.initialTab != null) return;
    _handledInitialArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab'] is int) {
      final newIdx = args['tab'] as int;
      if (newIdx >= 0 && newIdx < pages.length) {
        setState(() {
          idx = newIdx;
          _lastTabIndex = newIdx;
        });
      }
    }
  }

  void _onTap(int i) {
    setState(() {
      idx = i;
      _lastTabIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme; // 🎨 Màu theo Theme (Dark/Light)

    // Các màu dùng cho BottomNavigationBar (không hard-code)
    final barBg = cs.surface; // nền thanh
    final barBorder = cs.outlineVariant; // viền mảnh trên cùng
    final selectedColor = cs.primary; // màu chọn
    final unselectedColor = cs.onSurfaceVariant;

    return Stack(
      children: [
        Scaffold(
          // 🔑 RẤT QUAN TRỌNG: tránh “viền trắng” khi bật Dark Mode
          extendBody: true,

          drawer: const UserDrawer(),

          // IndexedStack giúp giữ state từng tab (scroll position, form state...)
          body: IndexedStack(index: idx, children: pages),

          // 🍏 Bottom Navigation (Apple-ish)
          bottomNavigationBar: DecoratedBox(
            // Không dùng Colors.white; lấy từ ColorScheme để đồng bộ Dark/Light
            decoration: BoxDecoration(
              color: barBg,
              border: Border(
                top: BorderSide(color: barBorder, width: 0.5),
              ),
            ),
            child: Padding(
              // Giữ khoảng an toàn trên iOS (Dynamic Island / Home Indicator)
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                // Đừng set backgroundColor = Colors.white → dùng Theme
                backgroundColor: barBg,
                elevation: 0,
                currentIndex: idx,
                onTap: _onTap,

                // 🎨 Màu chữ/icone Tab
                selectedItemColor: selectedColor,
                unselectedItemColor: unselectedColor,

                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                showUnselectedLabels: true,

                // 🔹 Bộ icon/tab theo bố cục Apple Store
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list_alt_outlined),
                    activeIcon: Icon(Icons.list_alt),
                    label: 'Products',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite_border),
                    activeIcon: Icon(Icons.favorite),
                    label: 'Favorites',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_cart_outlined),
                    activeIcon: Icon(Icons.shopping_cart),
                    label: 'Cart',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'Orders',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Account',
                  ),

                  // ✅ NEW: Video (thêm cuối, không phá index cũ)
                  BottomNavigationBarItem(
                    icon: Icon(Icons.video_library_outlined),
                    activeIcon: Icon(Icons.video_library),
                    label: 'Video',
                  ),
                ],
              ),
            ),
          ),
        ),

        // 💬 Bong bóng chat nổi toàn app
        const ChatFloatingButton(),
      ],
    );
  }
}
