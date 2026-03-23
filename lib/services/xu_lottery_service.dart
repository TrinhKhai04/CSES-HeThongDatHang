// lib/services/xu_lottery_service.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/xu_lottery_models.dart';

/// Hàm callback trừ Xu (được inject từ XuController trên UI)
typedef SpendXuFn = Future<bool> Function(
    int amount, {
    String reason,
    });

/// Service chính cho phía USER (app CSES)
/// - Đọc game config, runtime
/// - Lấy kỳ quay kế tiếp
/// - Stream vé / draw
/// - Mua vé (create ticket + update draw)
class XuLotteryService {
  final FirebaseFirestore _db;

  XuLotteryService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// ===============================================================
  /// RUNTIME (xu_lottery_runtime/global)
  /// ===============================================================

  /// Stream runtime config (để biết hệ thống có đang pause không)
  Stream<XuLotteryRuntime?> runtimeStream() {
    final docRef = _db.collection('xu_lottery_runtime').doc('global');
    return docRef.snapshots().map((snap) {
      if (!snap.exists) return null;
      return XuLotteryRuntime.fromSnapshot(snap);
    });
  }

  /// Load runtime 1 lần
  Future<XuLotteryRuntime?> loadRuntimeOnce() async {
    final docRef = _db.collection('xu_lottery_runtime').doc('global');
    final snap = await docRef.get();
    if (!snap.exists) return null;
    return XuLotteryRuntime.fromSnapshot(snap);
  }

  /// ===============================================================
  /// GAMES (xu_lottery_games)
  /// ===============================================================

  /// Lấy tất cả game đang active + hiển thị trên client
  Future<List<XuLotteryGame>> fetchActiveGames() async {
    final q = await _db
        .collection('xu_lottery_games')
        .where('isActive', isEqualTo: true)
        .where('isVisibleOnClient', isEqualTo: true)
        .get();

    return q.docs.map((d) => XuLotteryGame.fromSnapshot(d)).toList();
  }

  /// Lấy 1 game theo id (quick_5m, hourly_1h,...)
  Future<XuLotteryGame?> getGameById(String gameId) async {
    final snap =
    await _db.collection('xu_lottery_games').doc(gameId).get();
    if (!snap.exists) return null;
    return XuLotteryGame.fromSnapshot(snap);
  }

  /// Stream 1 game để UI admin hoặc user theo dõi thay đổi realtime
  Stream<XuLotteryGame?> gameStream(String gameId) {
    final docRef = _db.collection('xu_lottery_games').doc(gameId);
    return docRef.snapshots().map((snap) {
      if (!snap.exists) return null;
      return XuLotteryGame.fromSnapshot(snap);
    });
  }

  /// ===============================================================
  /// DRAWS (xu_lottery_draws)
  /// ===============================================================

  /// Lấy kỳ quay OPEN gần nhất cho 1 game.
  ///
  /// - chỉ lấy draw có status = 'open'
  /// - orderBy scheduledAt tăng dần, limit 1
  /// - không ép scheduledAt > now (check khoá vé làm ở client & buyTicket)
  Future<XuLotteryDraw?> getNextOpenDraw(
      String gameId, {
        DateTime? now,
      }) async {
    final q = await _db
        .collection('xu_lottery_draws')
        .where('gameId', isEqualTo: gameId)
        .where('status', isEqualTo: 'open')
        .orderBy('scheduledAt', descending: false)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    final draw = XuLotteryDraw.fromSnapshot(q.docs.first);

    // Nếu muốn loại bỏ những draw quá cũ có thể bật đoạn dưới:
    // final current = now ?? DateTime.now();
    // final tooOld = draw.scheduledAt.isBefore(
    //   current.subtract(const Duration(hours: 1)),
    // );
    // if (tooOld) return null;

    return draw;
  }

  /// Stream danh sách draw cho 1 game (dùng cho màn lịch / admin)
  ///
  /// - orderBy scheduledAt DESC
  /// - limit cấu hình được
  Stream<List<XuLotteryDraw>> drawsStreamForGame(
      String gameId, {
        int limit = 50,
      }) {
    final query = _db
        .collection('xu_lottery_draws')
        .where('gameId', isEqualTo: gameId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit);

    return query.snapshots().map((snap) {
      return snap.docs
          .map((d) => XuLotteryDraw.fromSnapshot(d))
          .toList();
    });
  }

  /// ===============================================================
  /// TICKETS (xu_lottery_tickets)
  /// ===============================================================

  /// Stream các vé gần đây của 1 user (có thể filter theo game)
  Stream<List<XuLotteryTicket>> userTicketsStream({
    required String userId,
    String? gameId,
    int limit = 50,
  }) {
    Query q = _db
        .collection('xu_lottery_tickets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (gameId != null) {
      q = q.where('gameId', isEqualTo: gameId);
    }

    return q.snapshots().map((snap) {
      return snap.docs
          .map((d) => XuLotteryTicket.fromSnapshot(d))
          .toList();
    });
  }

  /// Lấy tổng Xu user đã cược trong NGÀY hiện tại cho 1 game (để check limit).
  ///
  /// - Tính theo timezone máy (thường là Asia/Ho_Chi_Minh)
  Future<int> _sumUserBetToday({
    required String userId,
    required String gameId,
  }) async {
    final now = DateTime.now();
    final startOfDay =
    DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay =
    DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final q = await _db
        .collection('xu_lottery_tickets')
        .where('userId', isEqualTo: userId)
        .where('gameId', isEqualTo: gameId)
        .where(
      'createdAt',
      isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
    )
        .where(
      'createdAt',
      isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
    )
        .get();

    int sum = 0;
    for (final d in q.docs) {
      final data = d.data();
      final bet = (data['betXu'] as num?)?.toInt() ?? 0;
      sum += bet;
    }
    return sum;
  }

  /// Đếm số vé của user trong 1 kỳ (để check maxTicketsPerDraw)
  Future<int> _countUserTicketsInDraw({
    required String userId,
    required String drawId,
  }) async {
    final q = await _db
        .collection('xu_lottery_tickets')
        .where('userId', isEqualTo: userId)
        .where('drawId', isEqualTo: drawId)
        .get();
    return q.size;
  }

  /// ===============================================================
  /// MUA VÉ (USER)
  /// ===============================================================

  /// Hàm mua vé:
  /// - Kiểm tra runtime (pause? toàn hệ thống)
  /// - Kiểm tra game active / visible
  /// - Lấy kỳ quay OPEN gần nhất
  /// - Kiểm tra lockBeforeSeconds, số chọn, limit vé & Xu
  /// - Trừ Xu (callback spendXu – được truyền từ XuController)
  /// - Tạo ticket + update draw.totalTickets / totalBetXu (transaction)
  ///
  /// [spendXu] là hàm trừ Xu của bạn (từ XuController):
  ///   Future<bool> spendXuForGame({required uid, required amount, ...})
  ///   => gói lại thành SpendXuFn khi gọi buyTicket.
  Future<XuLotteryTicket> buyTicket({
    required String userId,
    required String gameId,
    required int pickedNumber,
    required int betXu,
    required SpendXuFn spendXu,
  }) async {
    // 1. Check runtime (pause hay không)
    final runtime = await loadRuntimeOnce();
    if (runtime != null && runtime.isAllLotteryPaused) {
      throw Exception(
        'Hệ thống xổ số đang tạm dừng, vui lòng quay lại sau.',
      );
    }

    // 2. Load game config
    final game = await getGameById(gameId);
    if (game == null) {
      throw Exception('Game xổ số không tồn tại.');
    }
    if (!game.isActive || !game.isVisibleOnClient) {
      throw Exception(
        'Game này đang tạm ẩn, vui lòng chọn game khác.',
      );
    }

    // 3. Kiểm tra input cơ bản
    if (pickedNumber < 0 || pickedNumber > 99) {
      throw Exception('Số phải nằm trong khoảng 00–99.');
    }
    if (betXu < game.ticketPrice) {
      throw Exception(
        'Tiền cược tối thiểu là ${game.ticketPrice} Xu/vé.',
      );
    }
    if (betXu > game.maxBetPerTicket) {
      throw Exception(
        'Tiền cược tối đa cho 1 vé là ${game.maxBetPerTicket} Xu.',
      );
    }

    // 4. Lấy kỳ quay kế tiếp
    final now = DateTime.now();
    final draw = await getNextOpenDraw(gameId, now: now);
    if (draw == null) {
      throw Exception(
        'Hiện chưa có kỳ quay nào đang mở, vui lòng quay lại sau.',
      );
    }

    // 5. Check time lock (dùng cùng timezone với client: local)
    final scheduledLocal = draw.scheduledAt.toLocal();
    final lockTime = scheduledLocal
        .subtract(Duration(seconds: draw.lockBeforeSeconds));

    if (now.isAfter(lockTime)) {
      throw Exception(
        'Đã qua thời điểm khoá vé cho kỳ này, vui lòng đợi kỳ tiếp theo.',
      );
    }

    // 6. Check max tickets / draw
    final currentTicketsInDraw = await _countUserTicketsInDraw(
      userId: userId,
      drawId: draw.id,
    );
    if (currentTicketsInDraw >= game.maxTicketsPerDraw) {
      throw Exception(
        'Bạn đã đạt số vé tối đa (${game.maxTicketsPerDraw}) cho kỳ quay này.',
      );
    }

    // 7. Check tổng Xu/ngày cho game này
    final totalBetToday = await _sumUserBetToday(
      userId: userId,
      gameId: gameId,
    );
    final afterBet = totalBetToday + betXu;
    if (afterBet > game.maxDailyBetPerUser) {
      throw Exception(
        'Vượt giới hạn Xu cược tối đa trong ngày '
            '(${game.maxDailyBetPerUser} Xu) cho game này.',
      );
    }

    // 8. Trừ Xu (qua XuController, inject từ bên ngoài)
    final ok = await spendXu(
      betXu,
      reason: 'Mua vé Xổ số: ${game.title}',
    );
    if (!ok) {
      throw Exception('Không đủ Xu để mua vé.');
    }

    // 9. Tạo ticket + update draw trong transaction cho an toàn
    final ticketRef = _db.collection('xu_lottery_tickets').doc();

    late XuLotteryTicket ticketResult;

    await _db.runTransaction((tx) async {
      final drawRef =
      _db.collection('xu_lottery_draws').doc(draw.id);
      final latestDrawSnap = await tx.get(drawRef);

      if (!latestDrawSnap.exists) {
        throw Exception(
          'Kỳ quay đã bị huỷ, giao dịch dừng lại.',
        );
      }

      final latestDraw = XuLotteryDraw.fromSnapshot(latestDrawSnap);

      if (!latestDraw.isOpen) {
        throw Exception(
          'Kỳ quay đã khoá hoặc kết thúc, vui lòng đợi kỳ mới.',
        );
      }

      // Check khoá vé lần nữa trong transaction (local time)
      final now2 = DateTime.now();
      final scheduledLocal2 = latestDraw.scheduledAt.toLocal();
      final lockTime2 = scheduledLocal2
          .subtract(Duration(seconds: latestDraw.lockBeforeSeconds));

      if (now2.isAfter(lockTime2)) {
        throw Exception(
          'Đã qua thời điểm khoá vé cho kỳ này, vui lòng đợi kỳ tiếp theo.',
        );
      }

      // Tăng counters
      final newTotalTickets = latestDraw.totalTickets + 1;
      final newTotalBetXu = latestDraw.totalBetXu + betXu;

      tx.update(drawRef, {
        'totalTickets': newTotalTickets,
        'totalBetXu': newTotalBetXu,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Tạo ticket
      final createdAt = DateTime.now();
      final ticket = XuLotteryTicket(
        id: ticketRef.id,
        userId: userId,
        gameId: gameId,
        drawId: latestDraw.id,
        pickedNumber: pickedNumber,
        betXu: betXu,
        prizeXu: 0, // sẽ được cập nhật khi settle
        isWin: false,
        createdAt: createdAt,
        settledAt: null,
      );

      tx.set(ticketRef, ticket.toJson());
      ticketResult = ticket;
    });

    return ticketResult;
  }

  /// ===============================================================
  /// ADMIN: CHỐT KẾT QUẢ 1 KỲ QUAY + TỰ TẠO KỲ TIẾP (INTERVAL)
  /// ===============================================================

  /// Chốt kết quả cho 1 draw:
  /// - Lấy game + draw + runtime
  /// - Chọn số trúng
  /// - Tính thưởng cho từng vé
  /// - Cập nhật ticket + draw
  /// - Nếu game.mode = interval => tự tạo kỳ tiếp theo
  Future<void> settleDrawOnceForAdmin(String drawId) async {
    // 1. Load draw
    final drawRef = _db.collection('xu_lottery_draws').doc(drawId);
    final drawSnap = await drawRef.get();
    if (!drawSnap.exists) {
      throw Exception('Kỳ quay không tồn tại.');
    }
    final draw = XuLotteryDraw.fromSnapshot(drawSnap);

    if (draw.isSettled || draw.isCancelled) {
      throw Exception('Kỳ quay này đã được chốt kết quả.');
    }

    // Option: đảm bảo đã tới giờ quay (dùng local cho đồng bộ UI)
    final now = DateTime.now();
    final scheduledLocal = draw.scheduledAt.toLocal();
    if (scheduledLocal.isAfter(now)) {
      // Cho phép test nên không throw, chỉ ghi chú nếu cần.
      // throw Exception('Chưa đến giờ quay, không thể chốt kết quả.');
    }

    // 2. Load game
    final game = await getGameById(draw.gameId);
    if (game == null) {
      throw Exception('Game của kỳ quay không tồn tại.');
    }

    // 3. Load runtime để biết có forceRandom hay không
    final runtime = await loadRuntimeOnce();
    final forceRandom = runtime?.forceRandomMode ?? false;

    // 4. Chọn số trúng
    int jackpotNumber;
    String jackpotSource;

    if (!forceRandom &&
        game.allowAdminOverride &&
        draw.adminPresetNumber != null) {
      jackpotNumber = draw.adminPresetNumber!.clamp(0, 99);
      jackpotSource = 'admin_preset';
    } else {
      jackpotNumber = Random().nextInt(100); // 0–99
      jackpotSource = 'random';
    }

    // 5. Lấy tất cả vé của kỳ quay này
    final ticketsSnap = await _db
        .collection('xu_lottery_tickets')
        .where('drawId', isEqualTo: draw.id)
        .get();

    final batch = _db.batch();
    int totalPrizeXu = 0;

    for (final doc in ticketsSnap.docs) {
      final data = doc.data();
      final int picked =
          (data['pickedNumber'] as num?)?.toInt() ?? 0;
      final int bet = (data['betXu'] as num?)?.toInt() ?? 0;

      int prize = 0;
      final diff = (picked - jackpotNumber).abs();

      if (picked == jackpotNumber) {
        // Trúng tuyệt đối
        prize = bet * game.payoutMultiplier;
      } else if (diff == 1) {
        prize = (bet * game.nearWin1RefundRate).round();
      } else if (diff == 2) {
        prize = (bet * game.nearWin2RefundRate).round();
      } else {
        prize = 0;
      }

      final bool isWin = prize > 0;
      totalPrizeXu += prize;

      batch.update(doc.reference, {
        'prizeXu': prize,
        'isWin': isWin,
        'settledAt': FieldValue.serverTimestamp(),
      });
    }

    // 6. Cập nhật draw
    batch.update(drawRef, {
      'status': LotteryDrawStatus.settled.code,
      'jackpotNumber': jackpotNumber,
      'jackpotSource': jackpotSource,
      'totalPrizeXu': totalPrizeXu,
      'settledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 7. Nếu là game interval => tự tạo kỳ tiếp theo
    if (game.mode == LotteryMode.interval &&
        (game.intervalMinutes ?? 0) > 0) {
      final nextTime = scheduledLocal
          .add(Duration(minutes: game.intervalMinutes!));

      final newDrawRef = _db.collection('xu_lottery_draws').doc();

      final nextDraw = XuLotteryDraw(
        id: newDrawRef.id,
        gameId: game.id,
        drawCode: nextTime.toIso8601String(),
        scheduledAt: nextTime,
        status: LotteryDrawStatus.open,
        lockBeforeSeconds: draw.lockBeforeSeconds,
        jackpotNumber: null,
        jackpotSource: null,
        adminPresetNumber: null,
        totalTickets: 0,
        totalBetXu: 0,
        totalPrizeXu: 0,
        createdAt: DateTime.now(),
        createdBy: 'system_auto_next',
        lockedAt: null,
        settledAt: null,
        cancelledAt: null,
        updatedAt: null,
        updatedBy: null,
      );

      await newDrawRef.set(nextDraw.toJson());
    }
  }
}
