// lib/services/xu_lottery_seeder.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Seeder tạo sẵn 3 game Xổ số Xu + runtime global
class XuLotterySeeder {
  XuLotterySeeder._();

  static Future<void> seed() async {
    final db = FirebaseFirestore.instance;

    // Nếu đã có game rồi thì thôi, tránh tạo trùng
    final existing = await db.collection('xu_lottery_games').limit(1).get();
    if (existing.docs.isNotEmpty) {
      // đã seed trước đó
      return;
    }

    final batch = db.batch();
    final now = DateTime.now();

    // 3 game mẫu: 5 phút, 60 phút, Daily 20:00
    final games = <Map<String, dynamic>>[
      {
        'id': 'interval_5m',
        'title': 'Xổ số nhanh 5 phút',
        'subtitle': 'Quay mỗi 5 phút, cược nhỏ – vui là chính',
        'mode': 'interval',          // LotteryMode.interval
        'intervalMinutes': 5,
        'drawHour': null,
        'drawMinute': null,
        'weekday': null,
        'ticketPrice': 50,
        'maxBetPerTicket': 500,      // tối đa 500 Xu / vé
        'maxTicketsPerDraw': 50,     // tối đa 50 vé / kỳ
        'maxDailyBetPerUser': 2000,  // tối đa 2k Xu / ngày / user
        'payoutMultiplier': 50,      // trúng jackpot x50
        'nearWin1RefundRate': 0,     // có thể chỉnh sau
        'nearWin2RefundRate': 0,
        'allowAdminOverride': true,
        'isActive': true,
        'isVisibleOnClient': false,  // ban đầu ẩn client, chỉ test admin
        'createdAt': now,
        'updatedAt': now,
        'updatedBy': null,
      },
      {
        'id': 'interval_60m',
        'title': 'Xổ số giờ vàng 60 phút',
        'subtitle': 'Quay mỗi 60 phút, thưởng cao hơn',
        'mode': 'interval',          // LotteryMode.interval
        'intervalMinutes': 60,
        'drawHour': null,
        'drawMinute': null,
        'weekday': null,
        'ticketPrice': 100,
        'maxBetPerTicket': 1000,
        'maxTicketsPerDraw': 100,
        'maxDailyBetPerUser': 5000,
        'payoutMultiplier': 80,
        'nearWin1RefundRate': 0,
        'nearWin2RefundRate': 0,
        'allowAdminOverride': true,
        'isActive': true,
        'isVisibleOnClient': false,
        'createdAt': now,
        'updatedAt': now,
        'updatedBy': null,
      },
      {
        'id': 'daily_20h',
        'title': 'Xổ số Daily 20:00',
        'subtitle': '1 kỳ mỗi ngày lúc 20:00',
        'mode': 'daily',             // LotteryMode.daily
        'intervalMinutes': null,
        'drawHour': 20,
        'drawMinute': 0,
        'weekday': null,             // dùng cho weekly sau này
        'ticketPrice': 200,
        'maxBetPerTicket': 2000,
        'maxTicketsPerDraw': 200,
        'maxDailyBetPerUser': 10000,
        'payoutMultiplier': 100,
        'nearWin1RefundRate': 0,
        'nearWin2RefundRate': 0,
        'allowAdminOverride': true,
        'isActive': true,
        'isVisibleOnClient': false,
        'createdAt': now,
        'updatedAt': now,
        'updatedBy': null,
      },
    ];

    for (final g in games) {
      final docRef =
      db.collection('xu_lottery_games').doc(g['id'] as String);
      batch.set(docRef, {
        ...g,
        // dùng serverTimestamp cho createdAt/updatedAt khi ghi
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    }

    // Runtime global mặc định
    final runtimeRef =
    db.collection('xu_lottery_runtime').doc('global');
    batch.set(runtimeRef, {
      'isAllLotteryPaused': false,
      'forceRandomMode': true,          // mặc định random, bỏ mọi preset
      'maintenanceMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
