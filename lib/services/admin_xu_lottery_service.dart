// lib/services/admin_xu_lottery_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/xu_lottery_models.dart';
import 'xu_lottery_service.dart';

/// Service dành cho ADMIN để quản lý:
/// - Game config (xu_lottery_games)
/// - Kỳ quay (xu_lottery_draws)
/// - Runtime global (xu_lottery_runtime/global)
/// - Ghi log admin (admin_logs)
///
/// Lưu ý:
/// - Các thao tác "settle", "refund" nên được xử lý ở backend / Cloud Functions.
/// - Ở đây chỉ update Firestore + log action.
class AdminXuLotteryService {
  final FirebaseFirestore _db;
  final String adminId; // uid admin hiện tại
  final XuLotteryService _lotteryService;

  AdminXuLotteryService({
    FirebaseFirestore? db,
    required this.adminId,
  })  : _db = db ?? FirebaseFirestore.instance,
        _lotteryService =
        XuLotteryService(db: db ?? FirebaseFirestore.instance);

  /// ===============================================================
  /// HELPER: GHI LOG ADMIN
  /// ===============================================================

  Future<void> _logAction(
      String action, {
        Map<String, dynamic>? target,
        Map<String, dynamic>? details,
      }) async {
    final ref = _db.collection('admin_logs').doc();
    final log = AdminLogEntry(
      id: ref.id,
      adminId: adminId,
      action: action,
      target: target,
      details: details,
      createdAt: DateTime.now(),
    );
    await ref.set(log.toJson());
  }

  /// ===============================================================
  /// QUẢN LÝ GAME (xu_lottery_games)
  /// ===============================================================

  /// Cập nhật 1 game config.
  ///
  /// - game.id là docId hiện có (quick_5m, hourly_1h,...)
  /// - Chỉ dùng cho admin UI (cấu hình lại giá vé, payout, limit, v.v.)
  Future<void> updateGameConfig(XuLotteryGame game) async {
    final ref = _db.collection('xu_lottery_games').doc(game.id);
    final now = DateTime.now();

    final data = {
      ...game.toJson(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    };

    await ref.update(data);

    await _logAction(
      'UPDATE_GAME_CONFIG',
      target: {
        'gameId': game.id,
      },
      details: {
        'changedFields': data,
      },
    );
  }

  /// Tạo mới 1 game (nếu sau này bạn muốn cho admin thêm loại game).
  ///
  /// Lưu ý: hiện tại 4 game base (quick_5m, hourly_1h, daily_18h, weekly_jackpot)
  /// bạn thường tạo trực tiếp trong console. Hàm này để mở rộng về sau.
  Future<void> createNewGame(XuLotteryGame game) async {
    final ref = _db.collection('xu_lottery_games').doc(game.id);
    final now = DateTime.now();

    final data = {
      ...game.toJson(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    };

    await ref.set(data);

    await _logAction(
      'CREATE_GAME',
      target: {
        'gameId': game.id,
      },
      details: {
        'config': data,
      },
    );
  }

  /// Bật / tắt game nhanh (isActive / isVisibleOnClient)
  Future<void> toggleGameActive({
    required String gameId,
    required bool isActive,
    bool? isVisibleOnClient,
  }) async {
    final ref = _db.collection('xu_lottery_games').doc(gameId);
    final now = DateTime.now();

    final updateData = <String, dynamic>{
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    };
    if (isVisibleOnClient != null) {
      updateData['isVisibleOnClient'] = isVisibleOnClient;
    }

    await ref.update(updateData);

    await _logAction(
      'TOGGLE_GAME_ACTIVE',
      target: {
        'gameId': gameId,
      },
      details: {
        'isActive': isActive,
        if (isVisibleOnClient != null)
          'isVisibleOnClient': isVisibleOnClient,
      },
    );
  }

  /// NEW: Bật / tắt auto loop cho 1 game interval.
  ///
  /// - [enabled] = true  => app client được phép auto settle + tạo kỳ tiếp.
  /// - [stopAt]  != null => auto dừng sau thời điểm này (theo giờ server).
  Future<void> toggleGameAutoLoop({
    required String gameId,
    required bool enabled,
    DateTime? stopAt,
  }) async {
    final ref = _db.collection('xu_lottery_games').doc(gameId);
    final now = DateTime.now();

    final updateData = <String, dynamic>{
      'autoLoopEnabled': enabled,
      'autoLoopStopAt':
      stopAt != null ? Timestamp.fromDate(stopAt) : null,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    };

    await ref.update(updateData);

    await _logAction(
      'TOGGLE_GAME_AUTO_LOOP',
      target: {
        'gameId': gameId,
      },
      details: {
        'autoLoopEnabled': enabled,
        'autoLoopStopAt': stopAt?.toIso8601String(),
      },
    );
  }

  /// ===============================================================
  /// QUẢN LÝ KỲ QUAY (xu_lottery_draws)
  /// ===============================================================

  /// ADMIN tự tạo 1 kỳ quay mới (kỳ đặc biệt hoặc bù).
  ///
  /// [gameId]   : id game (quick_5m, hourly_1h, daily_18h,...)
  /// [drawCode] : mã hiển thị (ví dụ "2025-12-07-20:00-special")
  /// [scheduledAt] : thời điểm quay
  /// [lockBeforeSeconds] : khoá vé trước X giây (thường lấy từ config chung)
  /// [adminPresetNumber] : nếu muốn set sẵn số trúng (0–99, optional)
  ///
  /// Trả về model XuLotteryDraw vừa tạo.
  Future<XuLotteryDraw> createDraw({
    required String gameId,
    required String drawCode,
    required DateTime scheduledAt,
    required int lockBeforeSeconds,
    int? adminPresetNumber,
  }) async {
    final ref = _db.collection('xu_lottery_draws').doc();
    final now = DateTime.now();

    final draw = XuLotteryDraw(
      id: ref.id,
      gameId: gameId,
      drawCode: drawCode,
      scheduledAt: scheduledAt,
      status: LotteryDrawStatus.open,
      lockBeforeSeconds: lockBeforeSeconds,
      jackpotNumber: null,
      jackpotSource: null,
      adminPresetNumber: adminPresetNumber,
      totalTickets: 0,
      totalBetXu: 0,
      totalPrizeXu: 0,
      createdAt: now,
      createdBy: 'admin:$adminId',
      lockedAt: null,
      settledAt: null,
      cancelledAt: null,
      updatedAt: now,
      updatedBy: adminId,
    );

    await ref.set(draw.toJson());

    await _logAction(
      'CREATE_DRAW',
      target: {
        'gameId': gameId,
        'drawId': ref.id,
      },
      details: {
        'drawCode': drawCode,
        'scheduledAt': scheduledAt.toIso8601String(),
        'lockBeforeSeconds': lockBeforeSeconds,
        'adminPresetNumber': adminPresetNumber,
      },
    );

    return draw;
  }

  /// ADMIN chỉnh sửa số trúng preset cho 1 draw.
  ///
  /// Lưu ý:
  /// - Đây là số "ghi trước" (adminPresetNumber).
  /// - Khi backend settle, nếu forceRandomMode=false thì sẽ dùng số này
  ///   làm jackpotNumber, jackpotSource="admin_preset".
  Future<void> setAdminPresetNumber({
    required String drawId,
    required int? adminPresetNumber,
  }) async {
    if (adminPresetNumber != null) {
      if (adminPresetNumber < 0 || adminPresetNumber > 99) {
        throw Exception('Số preset phải trong khoảng 00–99.');
      }
    }

    final ref = _db.collection('xu_lottery_draws').doc(drawId);
    final now = DateTime.now();

    await ref.update({
      'adminPresetNumber': adminPresetNumber,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    });

    await _logAction(
      'SET_PRESET_NUMBER',
      target: {
        'drawId': drawId,
      },
      details: {
        'adminPresetNumber': adminPresetNumber,
      },
    );
  }

  /// ADMIN lock ngay draw (ngưng nhận vé ngay lập tức).
  ///
  /// Lưu ý:
  /// - Backend settle vẫn chạy theo scheduledAt / cron như bình thường.
  Future<void> lockDrawNow(String drawId) async {
    final ref = _db.collection('xu_lottery_draws').doc(drawId);
    final now = DateTime.now();

    await ref.update({
      'status': 'locked',
      'lockedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    });

    await _logAction(
      'LOCK_DRAW',
      target: {
        'drawId': drawId,
      },
      details: {
        'lockedAt': now.toIso8601String(),
      },
    );
  }

  /// ADMIN đánh dấu huỷ draw.
  ///
  /// Lưu ý quan trọng:
  /// - Chỉ đánh dấu status=cancelled ở đây.
  /// - Việc **refund** cho toàn bộ vé phải được 1 backend/Cloud Function riêng xử lý.
  Future<void> cancelDraw({
    required String drawId,
    String? reason,
  }) async {
    final ref = _db.collection('xu_lottery_draws').doc(drawId);
    final now = DateTime.now();

    await ref.update({
      'status': 'cancelled',
      'cancelledAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': adminId,
    });

    await _logAction(
      'CANCEL_DRAW',
      target: {
        'drawId': drawId,
      },
      details: {
        'reason': reason,
        'cancelledAt': now.toIso8601String(),
      },
    );
  }

  /// ADMIN "settle ngay" 1 draw từ UI:
  /// - Gọi trực tiếp logic settle ở XuLotteryService
  /// - Ghi log admin
  Future<void> requestSettleDrawNow(String drawId) async {
    // Chốt kết quả: tính thưởng, update tickets + draw, tạo kỳ tiếp theo (nếu interval)
    await _lotteryService.settleDrawOnceForAdmin(drawId);

    // Ghi log
    await _logAction(
      'SETTLE_DRAW',
      target: {
        'drawId': drawId,
      },
      details: {
        'source': 'admin_ui',
      },
    );
  }

  /// ===============================================================
  /// RUNTIME GLOBAL (xu_lottery_runtime/global)
  /// ===============================================================

  /// Cập nhật runtime global:
  /// - isAllLotteryPaused
  /// - maintenanceMessage
  /// - forceRandomMode
  /// - autoEngineEnabled (mới)
  Future<void> updateRuntime({
    bool? isAllLotteryPaused,
    String? maintenanceMessage,
    bool? forceRandomMode,
    bool? autoEngineEnabled,
  }) async {
    final ref = _db.collection('xu_lottery_runtime').doc('global');
    final now = DateTime.now();

    final snap = await ref.get();
    Map<String, dynamic> data = {};
    if (snap.exists) {
      data = snap.data() as Map<String, dynamic>;
    }

    final current = XuLotteryRuntime.fromJson(data);

    final newRuntime = XuLotteryRuntime(
      isAllLotteryPaused:
      isAllLotteryPaused ?? current.isAllLotteryPaused,
      maintenanceMessage:
      maintenanceMessage ?? current.maintenanceMessage,
      forceRandomMode:
      forceRandomMode ?? current.forceRandomMode,
      autoEngineEnabled:
      autoEngineEnabled ?? current.autoEngineEnabled,
      createdAt: current.createdAt ?? now,
      updatedAt: now,
      updatedBy: adminId,
    );

    await ref.set(newRuntime.toJson(), SetOptions(merge: true));

    await _logAction(
      'UPDATE_RUNTIME',
      target: {
        'docId': 'global',
      },
      details: {
        'isAllLotteryPaused': newRuntime.isAllLotteryPaused,
        'maintenanceMessage': newRuntime.maintenanceMessage,
        'forceRandomMode': newRuntime.forceRandomMode,
        'autoEngineEnabled': newRuntime.autoEngineEnabled,
      },
    );
  }

  /// Shortcut: bật / tắt toàn bộ hệ thống xổ số
  Future<void> togglePauseAllLottery(bool pause) {
    return updateRuntime(isAllLotteryPaused: pause);
  }

  /// Shortcut: bật / tắt forceRandomMode
  Future<void> toggleForceRandomMode(bool enabled) {
    return updateRuntime(forceRandomMode: enabled);
  }

  /// NEW: bật / tắt engine auto (client sẽ dựa vào flag này để auto settle).
  Future<void> toggleAutoEngine(bool enabled) {
    return updateRuntime(autoEngineEnabled: enabled);
  }
}
