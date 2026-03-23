// // lib/dev/seed_xu_lottery.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// /// Chạy 1 lần để tạo dữ liệu mẫu cho Xổ số Xu
// class XuLotterySeeder {
//   static Future<void> seed() async {
//     final db = FirebaseFirestore.instance;
//     final batch = db.batch();
//     final now = DateTime.now();
//
//     // ==========================================================
//     // 1️⃣ Game 1: Xổ số nhanh 5 phút (interval)
//     // ==========================================================
//     final quick5mRef = db.collection('xu_lottery_games').doc('quick_5m');
//
//     batch.set(quick5mRef, {
//       'title': 'Xổ số nhanh 5 phút',
//       'subtitle': 'Mỗi 5 phút một kỳ quay',
//       'mode': 'interval',          // LotteryMode.interval
//       'intervalMinutes': 5,        // 🔹 5 phút / kỳ
//       'drawHour': null,
//       'drawMinute': null,
//       'weekday': null,
//
//       'ticketPrice': 100,          // 100 Xu / vé
//       'maxBetPerTicket': 10000,
//       'maxTicketsPerDraw': 50,
//       'maxDailyBetPerUser': 200000,
//
//       'payoutMultiplier': 90,
//       'nearWin1RefundRate': 0.5,
//       'nearWin2RefundRate': 0.2,
//
//       'allowAdminOverride': true,
//       'isActive': true,
//       'isVisibleOnClient': true,
//
//       'createdAt': Timestamp.fromDate(now),
//       'updatedAt': Timestamp.fromDate(now),
//       'updatedBy': 'admin:init',
//     });
//
//     // ==========================================================
//     // 2️⃣ Game 2: Xổ số mỗi giờ (interval 60 phút)
//     // ==========================================================
//     final hourlyRef = db.collection('xu_lottery_games').doc('hourly_1h');
//
//     batch.set(hourlyRef, {
//       'title': 'Xổ số mỗi giờ',
//       'subtitle': 'Mỗi 60 phút một kỳ quay',
//       'mode': 'interval',          // vẫn là interval
//       'intervalMinutes': 60,        // 🔹 60 phút / kỳ
//       'drawHour': null,
//       'drawMinute': null,
//       'weekday': null,
//
//       'ticketPrice': 150,          // 150 Xu / vé
//       'maxBetPerTicket': 15000,
//       'maxTicketsPerDraw': 40,
//       'maxDailyBetPerUser': 200000,
//
//       'payoutMultiplier': 92,
//       'nearWin1RefundRate': 0.55,
//       'nearWin2RefundRate': 0.22,
//
//       'allowAdminOverride': true,
//       'isActive': true,
//       'isVisibleOnClient': true,
//
//       'createdAt': Timestamp.fromDate(now),
//       'updatedAt': Timestamp.fromDate(now),
//       'updatedBy': 'admin:init',
//     });
//
//     // ==========================================================
//     // 3️⃣ Game 3: Xổ số mỗi ngày 21:00 (daily)
//     // ==========================================================
//     final daily21hRef = db.collection('xu_lottery_games').doc('daily_21h');
//
//     batch.set(daily21hRef, {
//       'title': 'Xổ số mỗi ngày 21:00',
//       'subtitle': 'Một kỳ quay mỗi ngày lúc 21:00',
//       'mode': 'daily',             // LotteryMode.daily
//       'intervalMinutes': null,
//       'drawHour': 21,              // 🔹 21:00 mỗi ngày
//       'drawMinute': 0,
//       'weekday': null,
//
//       'ticketPrice': 200,          // 200 Xu / vé
//       'maxBetPerTicket': 20000,
//       'maxTicketsPerDraw': 30,
//       'maxDailyBetPerUser': 200000,
//
//       'payoutMultiplier': 95,
//       'nearWin1RefundRate': 0.6,
//       'nearWin2RefundRate': 0.25,
//
//       'allowAdminOverride': true,
//       'isActive': true,
//       'isVisibleOnClient': true,
//
//       'createdAt': Timestamp.fromDate(now),
//       'updatedAt': Timestamp.fromDate(now),
//       'updatedBy': 'admin:init',
//     });
//
//     // ==========================================================
//     // 4️⃣ Runtime global (xu_lottery_runtime/global)
//     // ==========================================================
//     final runtimeRef =
//     db.collection('xu_lottery_runtime').doc('global');
//
//     batch.set(runtimeRef, {
//       'isAllLotteryPaused': false,
//       'maintenanceMessage': '',
//       'forceRandomMode': false,
//       'createdAt': Timestamp.fromDate(now),
//       'updatedAt': Timestamp.fromDate(now),
//       'updatedBy': 'admin:init',
//     }, SetOptions(merge: true));
//
//     await batch.commit();
//   }
// }
