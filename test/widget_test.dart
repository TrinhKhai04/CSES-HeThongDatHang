// test/user_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cses/controllers/settings_controller.dart';
import 'package:cses/views/profile/user_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Render & toggle dark mode on UserSettingsScreen', (tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Pump màn Cài đặt với Provider thật (không cần Firebase)
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsController(prefs),
        child: const MaterialApp(home: UserSettingsScreen()),
      ),
    );

    // Có tiêu đề
    expect(find.text('Cài đặt tài khoản'), findsOneWidget);

    // Tìm công tắc "Chế độ tối" và bật tắt
    expect(find.text('Chế độ tối'), findsOneWidget);
    await tester.tap(find.text('Chế độ tối')); // tap vào tile cũng được
    await tester.pumpAndSettle();

    // Không cần assert thêm: chỉ smoke test UI hoạt động mà không crash
  });
}
