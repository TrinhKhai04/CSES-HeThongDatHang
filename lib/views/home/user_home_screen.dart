import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Controllers
import '../../controllers/product_controller.dart';
import '../../controllers/notification_controller.dart';

// UI Widgets
import 'tabs/user_home_tab.dart';
import 'widgets/user_drawer.dart';
import '../search/product_search_delegate.dart';
import '../notifications/user_notifications_screen.dart';

// 💬 Bong bóng chat nổi Apple-style
import '../common/chat_floating_button.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  @override
  void initState() {
    super.initState();
    // 📢 Khi vào Home, bắt đầu lắng nghe thông báo realtime
    Future.microtask(() {
      final noti = context.read<NotificationController>();
      noti.listenToUserNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final cs     = theme.colorScheme;
    final noti   = context.watch<NotificationController>();

    return Scaffold(
      // ☰ Drawer trái (menu người dùng)
      drawer: const UserDrawer(),

      // ===================== AppBar — Apple style =====================
      // Không hard-code màu; dùng AppBarTheme từ AppTheme (Light/Dark)
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'CSES',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: theme.appBarTheme.elevation ?? 0,
        iconTheme: theme.appBarTheme.iconTheme ??
            IconThemeData(color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
        actions: [
          // 🔍 Tìm kiếm sản phẩm
          IconButton(
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            icon: Icon(Icons.search, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
            onPressed: () => showSearch(context: context, delegate: ProductSearchDelegate()),
          ),

          // 🔔 Thông báo + badge chưa đọc
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Thông báo',
                icon: Icon(Icons.notifications_none,
                    color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserNotificationsScreen()),
                  );
                },
              ),
              if (noti.unreadCount > 0)
                Positioned(
                  // đặt lệch nhẹ để không che icon
                  right: 8,
                  top: 8,
                  child: Semantics(
                    label: 'Số thông báo chưa đọc: ${noti.unreadCount}',
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
                          width: 2, // viền nhỏ để badge nổi trên nền
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${noti.unreadCount > 99 ? '99+' : noti.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),

      // ===================== Body =====================
      body: Stack(
        children: [
          // 🧱 Danh sách sản phẩm trang Home
          ChangeNotifierProvider(
            create: (_) => ProductController()..fetch(),
            child: const UserHomeTab(),
          ),

          // 💬 Bong bóng chat nổi — Apple style (giữ nguyên vị trí)
          // Truyền badge theo số tin nhắn chưa đọc (nếu bạn có)
          // Positioned.fill(
          //   child: IgnorePointer(
          //     ignoring: true, // tránh chặn scroll; nút riêng sẽ nhận pointer
          //     child: const SizedBox.expand(),
          //   ),
          // ),
          // // 👉 Bật nút chat:
          // ChatFloatingButton(
          //   unreadCount: 0, // TODO: nếu có số chưa đọc, truyền tại đây
          //   // onTap: () => Navigator.pushNamed(context, AppRoutes.chatbot),
          // ),
        ],
      ),
    );
  }
}
