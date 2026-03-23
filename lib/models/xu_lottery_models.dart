// lib/models/xu_lottery_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// ===============================================================
/// ENUMS & HELPERS
/// ===============================================================

enum LotteryMode { interval, daily, weekly }

extension LotteryModeX on LotteryMode {
  String get code {
    switch (this) {
      case LotteryMode.interval:
        return 'interval';
      case LotteryMode.daily:
        return 'daily';
      case LotteryMode.weekly:
        return 'weekly';
    }
  }

  static LotteryMode fromString(String? s) {
    switch (s) {
      case 'interval':
        return LotteryMode.interval;
      case 'weekly':
        return LotteryMode.weekly;
      case 'daily':
      default:
        return LotteryMode.daily;
    }
  }
}

enum LotteryDrawStatus { open, locked, settled, cancelled }

extension LotteryDrawStatusX on LotteryDrawStatus {
  String get code {
    switch (this) {
      case LotteryDrawStatus.open:
        return 'open';
      case LotteryDrawStatus.locked:
        return 'locked';
      case LotteryDrawStatus.settled:
        return 'settled';
      case LotteryDrawStatus.cancelled:
        return 'cancelled';
    }
  }

  static LotteryDrawStatus fromString(String? s) {
    switch (s) {
      case 'locked':
        return LotteryDrawStatus.locked;
      case 'settled':
        return LotteryDrawStatus.settled;
      case 'cancelled':
        return LotteryDrawStatus.cancelled;
      case 'open':
      default:
        return LotteryDrawStatus.open;
    }
  }
}

/// ===============================================================
/// MODEL: GAME CONFIG  (xu_lottery_games)
/// ===============================================================

class XuLotteryGame {
  final String id; // docId: quick_5m, hourly_1h, daily_18h...
  final String title;
  final String subtitle;

  final LotteryMode mode; // interval | daily | weekly
  final int? intervalMinutes; // nếu mode=interval
  final int? drawHour; // nếu mode=daily|weekly
  final int? drawMinute; // nếu mode=daily|weekly
  final int? weekday; // nếu mode=weekly (0=CN..6=Thứ 7)

  final int ticketPrice; // Xu/vé tối thiểu
  final int maxBetPerTicket; // Xu tối đa / vé
  final int maxTicketsPerDraw; // vé tối đa/kỳ/người
  final int maxDailyBetPerUser; // tổng Xu tối đa/ngày/người

  final int payoutMultiplier; // bet * payoutMultiplier
  final double nearWin1RefundRate;
  final double nearWin2RefundRate;

  final bool allowAdminOverride; // cho setup jackpot
  final bool isActive; // bật/tắt game
  final bool isVisibleOnClient; // có show cho user không

  /// NEW: bật tự động chạy liên tục cho game interval
  final bool autoLoopEnabled;

  /// NEW: nếu khác null → auto dừng sau thời điểm này
  final DateTime? autoLoopStopAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  const XuLotteryGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.mode,
    this.intervalMinutes,
    this.drawHour,
    this.drawMinute,
    this.weekday,
    required this.ticketPrice,
    required this.maxBetPerTicket,
    required this.maxTicketsPerDraw,
    required this.maxDailyBetPerUser,
    required this.payoutMultiplier,
    required this.nearWin1RefundRate,
    required this.nearWin2RefundRate,
    required this.allowAdminOverride,
    required this.isActive,
    required this.isVisibleOnClient,
    this.autoLoopEnabled = false,
    this.autoLoopStopAt,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  factory XuLotteryGame.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return XuLotteryGame.fromDoc(snap.id, data);
  }

  factory XuLotteryGame.fromDoc(String id, Map<String, dynamic> json) {
    return XuLotteryGame(
      id: id,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      mode: LotteryModeX.fromString(json['mode'] as String?),
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt(),
      drawHour: (json['drawHour'] as num?)?.toInt(),
      drawMinute: (json['drawMinute'] as num?)?.toInt(),
      weekday: (json['weekday'] as num?)?.toInt(),
      ticketPrice: (json['ticketPrice'] as num?)?.toInt() ?? 0,
      maxBetPerTicket: (json['maxBetPerTicket'] as num?)?.toInt() ?? 0,
      maxTicketsPerDraw:
      (json['maxTicketsPerDraw'] as num?)?.toInt() ?? 0,
      maxDailyBetPerUser:
      (json['maxDailyBetPerUser'] as num?)?.toInt() ?? 0,
      payoutMultiplier:
      (json['payoutMultiplier'] as num?)?.toInt() ?? 0,
      nearWin1RefundRate:
      (json['nearWin1RefundRate'] as num?)?.toDouble() ?? 0,
      nearWin2RefundRate:
      (json['nearWin2RefundRate'] as num?)?.toDouble() ?? 0,
      allowAdminOverride:
      json['allowAdminOverride'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      isVisibleOnClient:
      json['isVisibleOnClient'] as bool? ?? false,
      autoLoopEnabled: json['autoLoopEnabled'] as bool? ?? false,
      autoLoopStopAt:
      (json['autoLoopStopAt'] as Timestamp?)?.toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'mode': mode.code,
      'intervalMinutes': intervalMinutes,
      'drawHour': drawHour,
      'drawMinute': drawMinute,
      'weekday': weekday,
      'ticketPrice': ticketPrice,
      'maxBetPerTicket': maxBetPerTicket,
      'maxTicketsPerDraw': maxTicketsPerDraw,
      'maxDailyBetPerUser': maxDailyBetPerUser,
      'payoutMultiplier': payoutMultiplier,
      'nearWin1RefundRate': nearWin1RefundRate,
      'nearWin2RefundRate': nearWin2RefundRate,
      'allowAdminOverride': allowAdminOverride,
      'isActive': isActive,
      'isVisibleOnClient': isVisibleOnClient,
      'autoLoopEnabled': autoLoopEnabled,
      'autoLoopStopAt': autoLoopStopAt != null
          ? Timestamp.fromDate(autoLoopStopAt!)
          : null,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }
}

/// ===============================================================
/// MODEL: DRAW (KỲ QUAY)  (xu_lottery_draws)
/// ===============================================================

class XuLotteryDraw {
  final String id; // docId
  final String gameId; // quick_5m, hourly_1h...
  final String drawCode; // ví dụ: 2025-12-07-18:00
  final DateTime scheduledAt; // giờ quay dự kiến

  final LotteryDrawStatus status; // open | locked | settled | cancelled
  final int lockBeforeSeconds; // khóa vé trước X giây

  final int? jackpotNumber; // 0–99 sau khi quay
  final String? jackpotSource; // random | admin
  final int? adminPresetNumber; // số admin set trước

  final int totalTickets; // tổng số vé
  final int totalBetXu; // tổng Xu cược
  final int totalPrizeXu; // tổng Xu trả thưởng

  final DateTime? createdAt;
  final String? createdBy; // system | admin:<uid>
  final DateTime? lockedAt;
  final DateTime? settledAt;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  const XuLotteryDraw({
    required this.id,
    required this.gameId,
    required this.drawCode,
    required this.scheduledAt,
    required this.status,
    required this.lockBeforeSeconds,
    this.jackpotNumber,
    this.jackpotSource,
    this.adminPresetNumber,
    required this.totalTickets,
    required this.totalBetXu,
    required this.totalPrizeXu,
    this.createdAt,
    this.createdBy,
    this.lockedAt,
    this.settledAt,
    this.cancelledAt,
    this.updatedAt,
    this.updatedBy,
  });

  factory XuLotteryDraw.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return XuLotteryDraw.fromDoc(snap.id, data);
  }

  factory XuLotteryDraw.fromDoc(String id, Map<String, dynamic> json) {
    return XuLotteryDraw(
      id: id,
      gameId: json['gameId'] as String? ?? '',
      drawCode: json['drawCode'] as String? ?? '',
      scheduledAt: (json['scheduledAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      status:
      LotteryDrawStatusX.fromString(json['status'] as String?),
      lockBeforeSeconds:
      (json['lockBeforeSeconds'] as num?)?.toInt() ?? 0,
      jackpotNumber: (json['jackpotNumber'] as num?)?.toInt(),
      jackpotSource: json['jackpotSource'] as String?,
      adminPresetNumber:
      (json['adminPresetNumber'] as num?)?.toInt(),
      totalTickets: (json['totalTickets'] as num?)?.toInt() ?? 0,
      totalBetXu: (json['totalBetXu'] as num?)?.toInt() ?? 0,
      totalPrizeXu:
      (json['totalPrizeXu'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      createdBy: json['createdBy'] as String?,
      lockedAt: (json['lockedAt'] as Timestamp?)?.toDate(),
      settledAt: (json['settledAt'] as Timestamp?)?.toDate(),
      cancelledAt:
      (json['cancelledAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'drawCode': drawCode,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status.code,
      'lockBeforeSeconds': lockBeforeSeconds,
      'jackpotNumber': jackpotNumber,
      'jackpotSource': jackpotSource,
      'adminPresetNumber': adminPresetNumber,
      'totalTickets': totalTickets,
      'totalBetXu': totalBetXu,
      'totalPrizeXu': totalPrizeXu,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'createdBy': createdBy,
      if (lockedAt != null) 'lockedAt': Timestamp.fromDate(lockedAt!),
      if (settledAt != null) 'settledAt': Timestamp.fromDate(settledAt!),
      if (cancelledAt != null)
        'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }

  bool get isOpen => status == LotteryDrawStatus.open;
  bool get isLocked => status == LotteryDrawStatus.locked;
  bool get isSettled => status == LotteryDrawStatus.settled;
  bool get isCancelled => status == LotteryDrawStatus.cancelled;
}

/// ===============================================================
/// MODEL: TICKET (VÉ NGƯỜI CHƠI)  (xu_lottery_tickets)
/// ===============================================================

class XuLotteryTicket {
  final String id; // docId
  final String userId;
  final String gameId;
  final String drawId; // ref tới xu_lottery_draws

  final int pickedNumber; // 0–99
  final int betXu; // Xu cược
  final int prizeXu; // Xu thắng (0 nếu thua)

  final bool isWin; // true/false sau khi settle

  final DateTime createdAt;
  final DateTime? settledAt;

  const XuLotteryTicket({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.drawId,
    required this.pickedNumber,
    required this.betXu,
    required this.prizeXu,
    required this.isWin,
    required this.createdAt,
    this.settledAt,
  });

  factory XuLotteryTicket.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return XuLotteryTicket.fromDoc(snap.id, data);
  }

  factory XuLotteryTicket.fromDoc(String id, Map<String, dynamic> json) {
    return XuLotteryTicket(
      id: id,
      userId: json['userId'] as String? ?? '',
      gameId: json['gameId'] as String? ?? '',
      drawId: json['drawId'] as String? ?? '',
      pickedNumber:
      (json['pickedNumber'] as num?)?.toInt() ?? 0,
      betXu: (json['betXu'] as num?)?.toInt() ?? 0,
      prizeXu: (json['prizeXu'] as num?)?.toInt() ?? 0,
      isWin: json['isWin'] as bool? ?? false,
      createdAt:
      (json['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      settledAt: (json['settledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'gameId': gameId,
      'drawId': drawId,
      'pickedNumber': pickedNumber,
      'betXu': betXu,
      'prizeXu': prizeXu,
      'isWin': isWin,
      'createdAt': Timestamp.fromDate(createdAt),
      if (settledAt != null)
        'settledAt': Timestamp.fromDate(settledAt!),
    };
  }
}

/// ===============================================================
/// MODEL: RUNTIME CONFIG (xu_lottery_runtime/global)
/// ===============================================================

class XuLotteryRuntime {
  final bool isAllLotteryPaused;
  final String maintenanceMessage;
  final bool forceRandomMode;

  /// NEW: bật/tắt engine auto của toàn bộ hệ thống xổ số
  final bool autoEngineEnabled;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  const XuLotteryRuntime({
    required this.isAllLotteryPaused,
    required this.maintenanceMessage,
    required this.forceRandomMode,
    this.autoEngineEnabled = true,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  factory XuLotteryRuntime.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return XuLotteryRuntime.fromJson(data);
  }

  factory XuLotteryRuntime.fromJson(Map<String, dynamic> json) {
    return XuLotteryRuntime(
      isAllLotteryPaused:
      json['isAllLotteryPaused'] as bool? ?? false,
      maintenanceMessage:
      json['maintenanceMessage'] as String? ?? '',
      forceRandomMode: json['forceRandomMode'] as bool? ?? false,
      autoEngineEnabled: json['autoEngineEnabled'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAllLotteryPaused': isAllLotteryPaused,
      'maintenanceMessage': maintenanceMessage,
      'forceRandomMode': forceRandomMode,
      'autoEngineEnabled': autoEngineEnabled,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }
}

/// ===============================================================
/// MODEL: ADMIN LOG (admin_logs)
/// ===============================================================

class AdminLogEntry {
  final String id; // docId
  final String adminId;
  final String action; // CREATE_DRAW, UPDATE_GAME, ...
  final Map<String, dynamic>? target;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  const AdminLogEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.target,
    required this.details,
    required this.createdAt,
  });

  factory AdminLogEntry.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return AdminLogEntry.fromDoc(snap.id, data);
  }

  factory AdminLogEntry.fromDoc(String id, Map<String, dynamic> json) {
    return AdminLogEntry(
      id: id,
      adminId: json['adminId'] as String? ?? '',
      action: json['action'] as String? ?? '',
      target: (json['target'] as Map<String, dynamic>?),
      details: (json['details'] as Map<String, dynamic>?),
      createdAt:
      (json['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId,
      'action': action,
      'target': target,
      'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
