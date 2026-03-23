// lib/controllers/xu_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_controller.dart';
import '../models/farm_slot.dart';

/// Cấu hình hạt giống trong nông trại
class SeedConfig {
  final String id;
  final String name;
  final int costXu; // Xu bỏ ra khi trồng
  final int rewardXu; // Xu nhận khi thu hoạch
  final int growMinutes; // thời gian lớn (phút)

  const SeedConfig({
    required this.id,
    required this.name,
    required this.costXu,
    required this.rewardXu,
    required this.growMinutes,
  });
}

// 2 loại cây đơn giản
const cheapSeed = SeedConfig(
  id: 'cheap',
  name: 'Cây thường',
  costXu: 50,
  rewardXu: 80,
  growMinutes: 120, // 2h
);

const expensiveSeed = SeedConfig(
  id: 'expensive',
  name: 'Cây hiếm',
  costXu: 200,
  rewardXu: 320,
  growMinutes: 480, // 8h
);

/// Cấu hình 1 mốc thưởng vòng quay (amount + weight)
class _WheelRewardOption {
  final int amount; // số Xu thưởng
  final int weight; // trọng số xác suất

  const _WheelRewardOption({
    required this.amount,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'weight': weight,
  };

  factory _WheelRewardOption.fromJson(Map<String, dynamic> json) {
    return _WheelRewardOption(
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cấu hình 1 mốc payout máy xèng (multiplier × bet + weight)
class _SlotPayoutTier {
  final int multiplier; // hệ số nhân trên tiền cược
  final int weight; // trọng số xác suất

  const _SlotPayoutTier({
    required this.multiplier,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'multiplier': multiplier,
    'weight': weight,
  };

  factory _SlotPayoutTier.fromJson(Map<String, dynamic> json) {
    return _SlotPayoutTier(
      multiplier: (json['multiplier'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
    );
  }
}

class XuController extends ChangeNotifier {
  /// Đang bận CHECK-IN (không dùng cho load thường)
  bool isLoading = false;

  /// Đang bận quay vòng may mắn
  bool isSpinning = false;

  /// Số Xu hiện có
  int balance = 0;

  /// Số Xu nhận mỗi lần điểm danh
  int dailyReward = 100;

  /// Đã điểm danh hôm nay chưa
  bool checkedInToday = false;

  /// Số ngày điểm danh liên tiếp (tối đa 7 cho UI)
  int streak = 0;

  /// Đã dùng lượt quay miễn phí hôm nay chưa
  bool spunToday = false;

  /// Số Xu nhận được ở lần quay gần nhất
  int spinRewardToday = 0;

  /// Số lượt quay thêm từ quảng cáo còn lại trong hôm nay
  int adSpinsLeftToday = 0;

  /// key ngày điểm danh gần nhất (yyyy-MM-dd)
  String? _lastCheckinKey;

  /// key ngày lượt quay miễn phí gần nhất (yyyy-MM-dd)
  String? _lastSpinDate;

  /// key ngày lượt quay quảng cáo gần nhất (yyyy-MM-dd)
  String? _adSpinDate;

  // ---------------- NÔNG TRẠI CSES ----------------

  /// Danh sách ô đất
  List<FarmSlot> farmSlots = [];

  /// Stream nông trại
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _farmSub;

  // ---------------- XP + NHIỆM VỤ ----------------

  /// Tổng XP tích lũy (dùng cho Level)
  int xp = 0;

  /// Level hiện tại (từ XP)
  int level = 1;

  /// Mỗi 2000 XP ~ 1 Level (có thể chỉnh)
  static const int xpPerLevel = 2000;

  /// Trạng thái nhiệm vụ hằng ngày hôm nay: missionId -> done?
  ///
  /// missionId đề xuất:
  /// - 'checkin'
  /// - 'wheel'
  /// - 'slot'
  /// - 'farm'
  Map<String, bool> dailyMissionDone = {};

  XuController();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _userCol =>
      _fs.collection('users');

  CollectionReference<Map<String, dynamic>> _farmCol(String uid) =>
      _userCol.doc(uid).collection('farmSlots');

  CollectionReference<Map<String, dynamic>> _missionsCol(String uid) =>
      _userCol.doc(uid).collection('xu_daily_missions');

  CollectionReference<Map<String, dynamic>> get _recentWinsCol =>
      _fs.collection('xu_recent_wins');

  // ======= COLLECTION LOG MINI-GAME =======

  CollectionReference<Map<String, dynamic>> get _slotPlaysCol =>
      _fs.collection('xu_slot_plays');

  CollectionReference<Map<String, dynamic>> get _wheelPlaysCol =>
      _fs.collection('xu_wheel_plays');

  CollectionReference<Map<String, dynamic>> get _farmCollectsCol =>
      _fs.collection('xu_farm_collects');

  /// Log cược cho Xổ số / game mới
  CollectionReference<Map<String, dynamic>> get _lotteryBetsCol =>
      _fs.collection('xu_lottery_bets');

  /// Cấu hình game (dùng cho vòng quay, slot, farm...)
  CollectionReference<Map<String, dynamic>> get _xuConfigCol =>
      _fs.collection('xu_game_config');

  /// Danh sách mốc thưởng + trọng số cho Vòng quay Xu.
  /// Mặc định giống logic cũ: 50 (50%), 100 (30%), 200 (15%), 500 (5%).
  List<_WheelRewardOption> _wheelOptions = const [
    _WheelRewardOption(amount: 50, weight: 50),
    _WheelRewardOption(amount: 100, weight: 30),
    _WheelRewardOption(amount: 200, weight: 15),
    _WheelRewardOption(amount: 500, weight: 5),
  ];

  /// Danh sách mốc payout máy xèng: multiplier × bet.
  /// Mặc định: thua trắng, x2, x5, x10, x50 (jackpot).
  List<_SlotPayoutTier> _slotTiers = const [
    _SlotPayoutTier(multiplier: 0, weight: 40),
    _SlotPayoutTier(multiplier: 2, weight: 30),
    _SlotPayoutTier(multiplier: 5, weight: 20),
    _SlotPayoutTier(multiplier: 10, weight: 9),
    _SlotPayoutTier(multiplier: 50, weight: 1),
  ];

  /// UI dùng: hôm nay còn lượt quay không?
  /// - Nếu chưa quay free → true
  /// - Nếu đã quay free nhưng còn lượt quảng cáo → true
  bool get canSpin => !spunToday || adSpinsLeftToday > 0;

  // ---------------- PUBLIC API ----------------

  /// Load dữ liệu Xu từ Firestore (gọi ở Profile / khi vào trang Xu)
  /// 👉 KHÔNG bật spinner, chỉ cập nhật state.
  Future<void> load(String uid) async {
    if (uid.isEmpty) return;

    try {
      final snap = await _userCol.doc(uid).get();
      final data = snap.data() ?? <String, dynamic>{};

      balance = (data['xuBalance'] as num?)?.toInt() ?? 0;
      dailyReward = (data['xuDailyReward'] as num?)?.toInt() ?? 100;
      streak = (data['xuStreak'] as num?)?.toInt() ?? 0;

      // ---------- Phần XP & Level ----------
      xp = (data['xuXp'] as num?)?.toInt() ?? 0;
      level = _levelFromXp(xp);

      // ---------- Phần điểm danh ----------
      final lastCheckinStr = data['xuLastCheckinDate'];
      if (lastCheckinStr is String) {
        _lastCheckinKey = lastCheckinStr;
      } else {
        _lastCheckinKey = null;
      }

      // ---------- Phần vòng quay miễn phí ----------
      final spinDateStr = data['xuDailySpinDate'];
      if (spinDateStr is String) {
        _lastSpinDate = spinDateStr;
      } else {
        _lastSpinDate = null;
      }

      spinRewardToday = (data['xuDailySpinReward'] as num?)?.toInt() ?? 0;

      // ---------- Phần lượt quay từ quảng cáo ----------
      final adSpinDateStr = data['xuDailyAdSpinDate'];
      if (adSpinDateStr is String) {
        _adSpinDate = adSpinDateStr;
      } else {
        _adSpinDate = null;
      }

      adSpinsLeftToday =
          (data['xuDailyAdSpinsLeft'] as num?)?.toInt() ?? 0;

      // ---------- Phần nhiệm vụ hằng ngày ----------
      final todayKey = _dateKey(DateTime.now());
      final missionsSnap = await _missionsCol(uid)
          .where('dateKey', isEqualTo: todayKey)
          .get();

      dailyMissionDone = {};
      for (final doc in missionsSnap.docs) {
        final mData = doc.data();
        if (mData['done'] == true) {
          dailyMissionDone[doc.id] = true;
        }
      }

      // 🔥 Load cấu hình mini-game (vòng quay + slot) nếu admin đã chỉnh
      await Future.wait([
        _loadWheelConfig(),
        _loadSlotConfig(),
      ]);

      _recalcTodayFlags();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController.load error: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  /// Dùng cho RefreshIndicator trong trang Xu
  Future<void> reload(String uid) => load(uid);

  /// Hàm tiện cho UI: tự lấy uid từ AuthController để CHECK-IN
  Future<void> checkInToday(BuildContext context, {String? uid}) async {
    uid ??= context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để điểm danh nhận Xu.');
    }
    await dailyCheckin(uid);
  }

  /// Hàm tiện cho UI: tự lấy uid từ AuthController để QUAY VÒNG
  Future<int> spinToday(BuildContext context, {String? uid}) async {
    uid ??= context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để quay vòng may mắn.');
    }
    return dailySpin(uid);
  }

  /// Hàm tiện cho UI: xem quảng cáo để nhận 1 lượt quay
  Future<void> grantAdSpinWithContext(BuildContext context,
      {String? uid}) async {
    uid ??= context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để nhận lượt quay thêm.');
    }
    await grantAdSpin(uid);
  }

  /// Hàm tiện cho UI: hoàn thành 1 nhiệm vụ hằng ngày (dùng BuildContext)
  Future<void> completeMissionWithContext(
      BuildContext context, {
        required String missionId,
        required int xpReward,
      }) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để nhận XP nhiệm vụ.');
    }
    await completeMission(
      uid: uid,
      missionId: missionId,
      xpReward: xpReward,
    );
  }

  // ---------------- NÔNG TRẠI: helpers tiện dùng từ UI ----------------

  /// Gắn stream nông trại theo user hiện tại
  Future<void> attachFarmWithContext(BuildContext context) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) return;
    await attachFarm(uid);
  }

  /// Trồng cây (dùng context lấy uid)
  Future<void> plantSeedWithContext(
      BuildContext context, {
        required String slotId,
        required SeedConfig seed,
      }) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để trồng cây.');
    }
    await plantSeed(uid: uid, slotId: slotId, seed: seed);
  }

  /// Thu hoạch (dùng context lấy uid)
  Future<void> harvestSlotWithContext(
      BuildContext context, {
        required FarmSlot slot,
      }) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để thu hoạch.');
    }
    await harvestSlot(uid: uid, slot: slot);
  }

  // ---------------- NÔNG TRẠI: core logic ----------------

  /// Gắn stream nông trại, auto tạo 6 ô nếu chưa có
  Future<void> attachFarm(String uid) async {
    if (uid.isEmpty) return;

    await _initFarmIfNeeded(uid);

    await _farmSub?.cancel();
    _farmSub =
        _farmCol(uid).orderBy('index').snapshots().listen((snap) {
          farmSlots =
              snap.docs.map((d) => FarmSlot.fromDoc(d)).toList();
          notifyListeners();
        });
  }

  /// Tạo 6 ô đất trống cho user nếu chưa có
  Future<void> _initFarmIfNeeded(String uid) async {
    final col = _farmCol(uid);
    final snap = await col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _fs.batch();
    for (int i = 0; i < 6; i++) {
      final doc = col.doc('slot_$i');
      batch.set(doc, {
        'index': i,
        'status': 'empty',
        'seedType': null,
        'plantedAt': null,
        'growMinutes': null,
        'rewardXu': null,
      });
    }
    await batch.commit();
  }

  /// Trồng cây vào 1 ô
  Future<void> plantSeed({
    required String uid,
    required String slotId,
    required SeedConfig seed,
  }) async {
    if (uid.isEmpty) return;

    int? newBalance;

    try {
      await _fs.runTransaction((tx) async {
        final userRef = _userCol.doc(uid);
        final slotRef = _farmCol(uid).doc(slotId);

        final userSnap = await tx.get(userRef);
        final slotSnap = await tx.get(slotRef);

        final dataUser = userSnap.data() ?? {};
        final int xu =
            (dataUser['xuBalance'] as num?)?.toInt() ?? 0;

        if (xu < seed.costXu) {
          throw Exception('not_enough_xu');
        }

        final slotData = slotSnap.data() ?? {};
        final String status = slotData['status'] ?? 'empty';
        if (status != 'empty') {
          throw Exception('slot_not_empty');
        }

        final updatedXu = xu - seed.costXu;
        newBalance = updatedXu;

        // Trừ Xu
        tx.set(
          userRef,
          {
            'xuBalance': updatedXu,
          },
          SetOptions(merge: true),
        );

        // Trồng cây
        tx.set(
          slotRef,
          {
            'status': 'growing',
            'seedType': seed.id,
            'plantedAt': FieldValue.serverTimestamp(),
            'growMinutes': seed.growMinutes,
            'rewardXu': seed.rewardXu,
          },
          SetOptions(merge: true),
        );
      });

      // ✅ Cập nhật local state ngay lập tức
      if (newBalance != null) {
        balance = newBalance!;
      }

      final idx = farmSlots.indexWhere((s) => s.id == slotId);
      if (idx != -1) {
        final old = farmSlots[idx];
        farmSlots[idx] = FarmSlot(
          id: old.id,
          index: old.index,
          status: 'growing',
          seedType: seed.id,
          plantedAt: DateTime.now(), // tạm thời, Firestore sẽ sync lại
          growMinutes: seed.growMinutes,
          rewardXu: seed.rewardXu,
        );
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('❌ XuController.plantSeed error: $e\n$st');
      rethrow;
    }
  }

  /// Thu hoạch 1 ô (server check đã đủ thời gian chưa)
  Future<void> harvestSlot({
    required String uid,
    required FarmSlot slot,
  }) async {
    if (uid.isEmpty) return;

    int? newBalance;
    int? rewardEarned; // để cộng vào bảng xếp hạng & ticker

    try {
      await _fs.runTransaction((tx) async {
        final userRef = _userCol.doc(uid);
        final slotRef = _farmCol(uid).doc(slot.id);

        final slotSnap = await tx.get(slotRef);
        final data = slotSnap.data() ?? {};

        final String status = data['status'] ?? 'empty';
        final Timestamp? plantedAtTs = data['plantedAt'];
        final int growMinutes =
            (data['growMinutes'] as num?)?.toInt() ?? 0;
        final int rewardXu =
            (data['rewardXu'] as num?)?.toInt() ?? 0;

        if (status == 'empty') {
          throw Exception('slot_empty');
        }

        if (plantedAtTs == null) {
          throw Exception('no_planted_time');
        }

        final plantedAt = plantedAtTs.toDate();
        final diffMinutes =
            DateTime.now().difference(plantedAt).inMinutes;

        if (diffMinutes < growMinutes) {
          throw Exception('not_ready_yet');
        }

        final userSnap = await tx.get(userRef);
        final dataUser = userSnap.data() ?? {};
        final int xu =
            (dataUser['xuBalance'] as num?)?.toInt() ?? 0;

        final updatedXu = xu + rewardXu;
        newBalance = updatedXu;
        rewardEarned = rewardXu;

        // Cộng xu
        tx.set(
          userRef,
          {
            'xuBalance': updatedXu,
          },
          SetOptions(merge: true),
        );

        // Reset ô
        tx.set(
          slotRef,
          {
            'status': 'empty',
            'seedType': null,
            'plantedAt': null,
            'growMinutes': null,
            'rewardXu': null,
          },
          SetOptions(merge: true),
        );
      });

      // ✅ Cập nhật local state ngay lập tức
      if (newBalance != null) {
        balance = newBalance!;
      }

      final idx = farmSlots.indexWhere((s) => s.id == slot.id);
      if (idx != -1) {
        farmSlots[idx] = FarmSlot(
          id: farmSlots[idx].id,
          index: farmSlots[idx].index,
          status: 'empty',
          seedType: null,
          plantedAt: null,
          growMinutes: null,
          rewardXu: null,
        );
      }

      notifyListeners();

      // ✅ Mini-game: cộng vào bảng xếp hạng tuần + ticker + log collect
      if (rewardEarned != null && rewardEarned! > 0) {
        await _addWeeklyGameXu(uid, rewardEarned!);
        await _logRecentWin(
          uid: uid,
          amount: rewardEarned!,
          game: 'Nông trại CSES',
        );

        // Ước lượng chi phí trồng (bet) theo loại cây
        int bet = 0;
        if (rewardEarned == cheapSeed.rewardXu) {
          bet = cheapSeed.costXu;
        } else if (rewardEarned == expensiveSeed.rewardXu) {
          bet = expensiveSeed.costXu;
        }

        await _logFarmCollect(
          uid: uid,
          bet: bet,
          payout: rewardEarned!,
          seedType: slot.seedType,
        );
      }
    } catch (e, st) {
      debugPrint('❌ XuController.harvestSlot error: $e\n$st');
      rethrow;
    }
  }

  // ---------------- DAILY CHECKIN ----------------

  /// Điểm danh – 1 lần mỗi ngày, cộng Xu và update streak
  Future<void> dailyCheckin(String uid) async {
    if (uid.isEmpty || isLoading) return;

    isLoading = true;
    notifyListeners();

    final userRef = _userCol.doc(uid);

    try {
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final yesterdayKey =
      _dateKey(now.subtract(const Duration(days: 1)));

      String? lastKey = data['xuLastCheckinDate'] as String?;
      final currentBalance =
          (data['xuBalance'] as num?)?.toInt() ?? 0;
      final currentReward =
          (data['xuDailyReward'] as num?)?.toInt() ?? dailyReward;
      final currentStreak =
          (data['xuStreak'] as num?)?.toInt() ?? 0;

      // đã điểm danh hôm nay rồi → bỏ qua
      if (lastKey == todayKey) {
        _lastCheckinKey = todayKey;
        _recalcTodayFlags();
        return;
      }

      // tính streak mới
      int newStreak;
      if (lastKey == yesterdayKey) {
        newStreak = currentStreak + 1;
      } else {
        newStreak = 1;
      }
      if (newStreak > 7) newStreak = 7;

      final newBalance = currentBalance + currentReward;

      // Cập nhật Firestore — chỉ field đơn giản, không Timestamp
      await userRef.set({
        'xuBalance': newBalance,
        'xuDailyReward': currentReward,
        'xuStreak': newStreak,
        'xuLastCheckinDate': todayKey,
      }, SetOptions(merge: true));

      // cập nhật local state
      balance = newBalance;
      dailyReward = currentReward;
      streak = newStreak;
      _lastCheckinKey = todayKey;

      _recalcTodayFlags();

      // ✅ Nhiệm vụ: điểm danh hôm nay
      await completeMission(
        uid: uid,
        missionId: 'checkin',
        xpReward: 20,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController.dailyCheckin error: $e');
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Vòng quay may mắn
  /// - Mỗi ngày: 1 lượt quay miễn phí.
  /// - Có thể nhận thêm lượt quay bằng cách xem quảng cáo.
  ///
  /// Trả về số Xu nhận được (0 nếu hôm nay đã hết lượt quay hoặc lỗi).
  Future<int> dailySpin(String uid) async {
    if (uid.isEmpty) return 0;
    if (isSpinning) return 0;

    isSpinning = true;
    notifyListeners();

    final userRef = _userCol.doc(uid);
    int reward = 0;

    try {
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final now = DateTime.now();
      final todayKey = _dateKey(now);

      final lastSpinDateStr = data['xuDailySpinDate'] as String?;
      final adSpinDateStr =
      data['xuDailyAdSpinDate'] as String?;
      final currentBalance =
          (data['xuBalance'] as num?)?.toInt() ?? 0;

      int currentAdSpinsLeft =
          (data['xuDailyAdSpinsLeft'] as num?)?.toInt() ?? 0;

      // Chuẩn hoá lượt quảng cáo theo ngày
      if (adSpinDateStr != todayKey) {
        currentAdSpinsLeft = 0;
      }

      final bool freeUsedToday = lastSpinDateStr == todayKey;

      // Nếu đã dùng lượt free & hết lượt quảng cáo -> hết quay
      if (freeUsedToday && currentAdSpinsLeft <= 0) {
        _lastSpinDate = lastSpinDateStr;
        _adSpinDate = adSpinDateStr;
        spunToday = freeUsedToday;
        adSpinsLeftToday = currentAdSpinsLeft;
        reward = 0;
      } else {
        // random phần thưởng (theo cấu hình mới)
        reward = _randomSpinReward();
        final newBalance = currentBalance + reward;

        if (!freeUsedToday) {
          // Dùng lượt miễn phí
          await userRef.set({
            'xuBalance': newBalance,
            'xuDailySpinDate': todayKey,
            'xuDailySpinReward': reward,
          }, SetOptions(merge: true));

          _lastSpinDate = todayKey;
          spunToday = true;
        } else {
          // Dùng lượt quảng cáo
          final newAdSpinsLeft = currentAdSpinsLeft - 1;

          await userRef.set({
            'xuBalance': newBalance,
            'xuDailySpinReward': reward,
            'xuDailyAdSpinDate': todayKey,
            'xuDailyAdSpinsLeft': newAdSpinsLeft,
          }, SetOptions(merge: true));

          _adSpinDate = todayKey;
          adSpinsLeftToday = newAdSpinsLeft;
          spunToday = true; // lượt free đã dùng từ trước
        }

        balance = newBalance;
        spinRewardToday = reward;

        // ✅ Nhiệm vụ: quay vòng may mắn
        await completeMission(
          uid: uid,
          missionId: 'wheel',
          xpReward: 30,
        );

        // ✅ Mini-game: cộng bảng xếp hạng + ticker + log play
        if (reward > 0) {
          await _addWeeklyGameXu(uid, reward);
          await _logRecentWin(
            uid: uid,
            amount: reward,
            game: 'Vòng quay may mắn',
          );

          await _logWheelPlay(
            uid: uid,
            bet: 0, // free / quảng cáo
            payout: reward,
            outcome: reward.toString(),
            isJackpot: reward >= 500,
          );
        }
      }

      _recalcTodayFlags();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController.dailySpin error: $e');
      }
      reward = 0;
    } finally {
      isSpinning = false;
      notifyListeners();
    }

    return reward;
  }

  /// Cộng thêm 1 lượt quay từ quảng cáo cho hôm nay
  Future<void> grantAdSpin(String uid) async {
    if (uid.isEmpty) return;

    final userRef = _userCol.doc(uid);

    try {
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final now = DateTime.now();
      final todayKey = _dateKey(now);

      final adSpinDateStr = data['xuDailyAdSpinDate'] as String?;
      int currentAdSpins =
          (data['xuDailyAdSpinsLeft'] as num?)?.toInt() ?? 0;

      int newAdSpins;
      if (adSpinDateStr == todayKey) {
        newAdSpins = currentAdSpins + 1;
      } else {
        newAdSpins = 1;
      }

      await userRef.set({
        'xuDailyAdSpinDate': todayKey,
        'xuDailyAdSpinsLeft': newAdSpins,
      }, SetOptions(merge: true));

      _adSpinDate = todayKey;
      adSpinsLeftToday = newAdSpins;

      _recalcTodayFlags();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController.grantAdSpin error: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  // ---------------- SLOT MACHINE: cộng / trừ Xu theo cược ----------------

  /// [delta] > 0: cộng Xu (thắng); < 0: trừ Xu (thua); = 0: không đổi.
  ///
  /// [bet]  : số Xu cược ván đó (nếu có, dùng để log).
  /// [symbols]: danh sách symbol kết quả (ví dụ: ['7','⭐','🍒',...]).
  /// [isJackpot]: đánh dấu có phải jackpot hay không để thống kê.
  Future<void> applySlotResult({
    required String uid,
    required int delta,
    int? bet,
    List<String>? symbols,
    bool isJackpot = false,
  }) async {
    if (uid.isEmpty || delta == 0) return;

    int? newBalance;

    try {
      await _fs.runTransaction((tx) async {
        final userRef = _userCol.doc(uid);
        final userSnap = await tx.get(userRef);
        final dataUser = userSnap.data() ?? <String, dynamic>{};

        final int currentXu =
            (dataUser['xuBalance'] as num?)?.toInt() ?? 0;

        int updatedXu = currentXu + delta;
        if (updatedXu < 0) updatedXu = 0;

        tx.set(
          userRef,
          {'xuBalance': updatedXu},
          SetOptions(merge: true),
        );

        newBalance = updatedXu;
      });

      if (newBalance != null) {
        balance = newBalance!;
        notifyListeners();
      }

      // ✅ Nếu thắng (delta > 0) thì tính vào mini-game tuần + ticker
      if (delta > 0) {
        await _addWeeklyGameXu(uid, delta);
        await _logRecentWin(
          uid: uid,
          amount: delta,
          game: 'Máy xèng CSES',
        );
      }

      // ✅ Log ván chơi slot vào xu_slot_plays
      int loggedBet;
      int loggedPayout;

      if (bet != null) {
        loggedBet = bet;
        final p = bet + delta;
        loggedPayout = p < 0 ? 0 : p;
      } else {
        // Fallback ước lượng nếu UI không truyền bet
        if (delta > 0) {
          loggedBet = delta;
          loggedPayout = delta * 2;
        } else {
          loggedBet = -delta;
          loggedPayout = 0;
        }
      }

      await _logSlotPlay(
        uid: uid,
        bet: loggedBet,
        payout: loggedPayout,
        symbols: symbols,
        isJackpot: isJackpot,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ XuController.applySlotResult error: $e\n$st');
      }
      rethrow;
    }
  }

  /// Hàm tiện cho UI Máy xèng (phiên bản mới theo đúng luật symbol):
  /// - [bet]: số Xu cược
  /// - [symbols]: danh sách emoji kết quả (['7', '🍒', ...]) để log
  /// - [multiplierHint]: hệ số nhân đã tính ở UI dựa trên symbol (0 nếu thua)
  ///
  /// Trả về [delta] = payout - bet (có thể âm nếu thua).
  Future<int> playSlotWithConfig({
    required String uid,
    required int bet,
    List<String>? symbols,
    int? multiplierHint,
  }) async {
    if (uid.isEmpty || bet <= 0) return 0;

    int multiplier;

    if (multiplierHint != null && multiplierHint >= 0) {
      // ✅ Dùng luôn multiplier đã tính từ symbol ở UI
      multiplier = multiplierHint;
    } else {
      // ⛑ Fallback: vẫn cho phép random theo _slotTiers nếu UI không truyền
      if (_slotTiers.isEmpty) {
        await _loadSlotConfig();
      }
      if (_slotTiers.isEmpty) return 0;

      int totalWeight = 0;
      for (final t in _slotTiers) {
        if (t.weight > 0) totalWeight += t.weight;
      }
      if (totalWeight <= 0) return 0;

      final roll = Random().nextInt(totalWeight);
      int acc = 0;
      _SlotPayoutTier chosen = _slotTiers.last;

      for (final t in _slotTiers) {
        if (t.weight <= 0) continue;
        acc += t.weight;
        if (roll < acc) {
          chosen = t;
          break;
        }
      }

      multiplier = chosen.multiplier;
    }

    // Tiền thưởng thực tế
    final int payout = bet * multiplier;
    final int delta = payout - bet; // âm nếu thua

    // Jackpot: theo multiplier thực tế (vd >= 15)
    final bool isJackpot = multiplier >= 15;

    await applySlotResult(
      uid: uid,
      delta: delta,
      bet: bet,
      symbols: symbols,
      isJackpot: isJackpot,
    );

    // ✅ Nhiệm vụ: chơi máy xèng
    await completeMission(
      uid: uid,
      missionId: 'slot',
      xpReward: 30,
    );

    return delta;
  }

  // ---------------- GENERIC GAME: trừ Xu cho Xổ số / game mới ----------------

  /// Trừ Xu cho các game mới (ví dụ: Xổ số Xu, event...)
  ///
  /// - [uid]: user id
  /// - [amount]: số Xu cần trừ (>0)
  /// - [game]: mã game, ví dụ 'lottery_quick_5m'
  /// - [reason]: mô tả dùng cho log / debug
  ///
  /// Trả về:
  /// - true  nếu trừ Xu thành công
  /// - false nếu không đủ Xu hoặc gặp lỗi
  Future<bool> spendXuForGame({
    required String uid,
    required int amount,
    String game = 'lottery',
    String reason = '',
  }) async {
    if (uid.isEmpty || amount <= 0) return false;

    int? newBalance;

    try {
      await _fs.runTransaction((tx) async {
        final userRef = _userCol.doc(uid);
        final userSnap = await tx.get(userRef);
        final dataUser = userSnap.data() ?? <String, dynamic>{};

        final int currentXu =
            (dataUser['xuBalance'] as num?)?.toInt() ?? 0;

        if (currentXu < amount) {
          // Không đủ Xu -> ném lỗi để catch ở dưới và trả về false
          throw Exception('not_enough_xu');
        }

        final updatedXu = currentXu - amount;

        tx.set(
          userRef,
          {
            'xuBalance': updatedXu,
          },
          SetOptions(merge: true),
        );

        newBalance = updatedXu;
      });

      // cập nhật local state
      if (newBalance != null) {
        balance = newBalance!;
        notifyListeners();
      }

      // (tuỳ chọn) Log lần cược vào xu_lottery_bets
      try {
        await _lotteryBetsCol.add({
          'userId': uid,
          'game': game,
          'amount': amount,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // log lỗi nếu cần, nhưng không ảnh hưởng đến kết quả hàm
      }

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            '❌ XuController.spendXuForGame error: $e\n$st');
      }
      // Với mọi lỗi (kể cả không đủ Xu) đều trả false
      return false;
    }
  }

  // ---------------- XP + MISSION HELPERS ----------------

  /// Đánh dấu 1 mission trong ngày là hoàn thành + cộng XP (1 lần/ngày)
  Future<void> completeMission({
    required String uid,
    required String missionId,
    required int xpReward,
  }) async {
    if (uid.isEmpty) return;

    final todayKey = _dateKey(DateTime.now());
    final missionRef = _missionsCol(uid).doc(missionId);

    try {
      final snap = await missionRef.get();

      if (snap.exists) {
        final data = snap.data();
        if (data != null &&
            data['dateKey'] == todayKey &&
            data['done'] == true) {
          // Đã hoàn thành hôm nay rồi → chỉ cập nhật local
          dailyMissionDone[missionId] = true;
          notifyListeners();
          return;
        }
      }

      // Lưu trạng thái nhiệm vụ hôm nay
      await missionRef.set(
        {
          'dateKey': todayKey,
          'done': true,
          'doneAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      dailyMissionDone[missionId] = true;

      // Cộng XP
      await _addXp(uid, xpReward);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController.completeMission error: $e');
      }
    }
  }

  Future<void> _addXp(String uid, int amount) async {
    if (amount <= 0 || uid.isEmpty) return;

    xp += amount;
    level = _levelFromXp(xp);

    try {
      await _userCol.doc(uid).set(
        {
          'xuXp': xp,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController._addXp error: $e');
      }
    }

    notifyListeners();
  }

  int _levelFromXp(int xp) => (xp ~/ xpPerLevel) + 1;

  // ---------------- MINI-GAME LEADERBOARD HELPERS ----------------

  /// Key tuần: lấy ngày thứ 2 (Monday) của tuần hiện tại rồi dùng _dateKey.
  String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return _dateKey(monday);
  }

  /// Cộng Xu kiếm từ mini-game vào tổng tuần của user
  Future<void> _addWeeklyGameXu(String uid, int amount) async {
    if (uid.isEmpty || amount <= 0) return;

    final now = DateTime.now();
    final weekKey = _weekKey(now);
    final userRef = _userCol.doc(uid);

    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? <String, dynamic>{};

        final currentWeekKey =
        data['xuWeeklyGameWeekKey'] as String?;
        final currentWeekXu =
            (data['xuWeeklyGameXu'] as num?)?.toInt() ?? 0;

        int newXu;
        String newKey;

        if (currentWeekKey == weekKey) {
          newXu = currentWeekXu + amount;
          newKey = currentWeekKey!;
        } else {
          // Tuần mới -> reset về amount hiện tại
          newXu = amount;
          newKey = weekKey;
        }

        tx.set(
          userRef,
          {
            'xuWeeklyGameXu': newXu,
            'xuWeeklyGameWeekKey': newKey,
          },
          SetOptions(merge: true),
        );
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            '❌ XuController._addWeeklyGameXu error: $e\n$st');
      }
    }
  }

  String _shortDisplayName(Map<String, dynamic> data) {
    final raw =
    (data['displayName'] ?? data['name'] ?? '') as String;
    final name = raw.trim();
    if (name.isEmpty) return 'Người chơi';

    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return name;

    final first = parts.first;
    final last = parts.last;
    return '$first $last';
  }

  /// Log 1 lượt thắng mini-game vào collection xu_recent_wins
  Future<void> _logRecentWin({
    required String uid,
    required int amount,
    required String game,
  }) async {
    if (uid.isEmpty || amount <= 0) return;

    try {
      final userSnap = await _userCol.doc(uid).get();
      final data = userSnap.data() ?? <String, dynamic>{};

      final displayName =
      (data['displayName'] ?? data['name'] ?? '') as String;
      final shortName = _shortDisplayName(data);
      final photoURL =
      (data['photoURL'] ?? data['avatar'] ?? '') as String;

      await _recentWinsCol.add({
        'uid': uid,
        'userName': displayName,
        'shortName': shortName,
        'photoURL': photoURL,
        'amount': amount,
        'game': game,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ XuController._logRecentWin error: $e\n$st');
      }
    }
  }

  // =============== LOG MINI-GAME (BACKEND / RISK CONTROL) ===============

  Future<void> _logSlotPlay({
    required String uid,
    required int bet,
    required int payout,
    List<String>? symbols,
    bool isJackpot = false,
  }) async {
    if (bet <= 0 && payout <= 0) return;
    try {
      await _slotPlaysCol.add({
        'userId': uid,
        'bet': bet,
        'payout': payout,
        'net': payout - bet,
        'symbols': symbols ?? [],
        'isJackpot': isJackpot,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ _logSlotPlay error: $e\n$st');
      }
    }
  }

  Future<void> _logWheelPlay({
    required String uid,
    required int bet,
    required int payout,
    String? outcome,
    bool isJackpot = false,
  }) async {
    try {
      await _wheelPlaysCol.add({
        'userId': uid,
        'bet': bet,
        'payout': payout,
        'net': payout - bet,
        'symbols': [outcome ?? payout.toString()],
        'isJackpot': isJackpot,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ _logWheelPlay error: $e\n$st');
      }
    }
  }

  Future<void> _logFarmCollect({
    required String uid,
    required int bet,
    required int payout,
    String? seedType,
  }) async {
    try {
      await _farmCollectsCol.add({
        'userId': uid,
        'bet': bet,
        'payout': payout,
        'net': payout - bet,
        'symbols': [seedType ?? 'unknown'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ _logFarmCollect error: $e\n$st');
      }
    }
  }

  // ---------------- INTERNAL HELPERS ----------------

  void _recalcTodayFlags() {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final yesterdayKey =
    _dateKey(now.subtract(const Duration(days: 1)));

    // ----- CHECK-IN -----
    if (_lastCheckinKey == null) {
      checkedInToday = false;
      streak = 0;
    } else {
      checkedInToday = _lastCheckinKey == todayKey;

      // nếu lần cuối không phải hôm qua hoặc hôm nay thì reset streak về 0
      if (!checkedInToday && _lastCheckinKey != yesterdayKey) {
        streak = 0;
      }
    }

    // ----- VÒNG QUAY MIỄN PHÍ -----
    if (_lastSpinDate == null) {
      spunToday = false;
    } else {
      spunToday = _lastSpinDate == todayKey;
    }

    // ----- LƯỢT QUAY QUẢNG CÁO -----
    if (_adSpinDate == null || _adSpinDate != todayKey) {
      adSpinsLeftToday = 0;
    }
  }

  /// Sinh key ngày dạng yyyy-MM-dd
  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Load cấu hình vòng quay từ Firestore (nếu có)
  Future<void> _loadWheelConfig() async {
    try {
      final doc = await _xuConfigCol.doc('wheel').get();
      final data = doc.data();
      if (data == null) return;

      final rewards = data['rewards'];
      if (rewards is List) {
        final List<_WheelRewardOption> parsed = [];
        for (final item in rewards) {
          if (item is Map<String, dynamic>) {
            parsed.add(_WheelRewardOption.fromJson(item));
          } else if (item is Map) {
            parsed.add(
              _WheelRewardOption.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
        if (parsed.isNotEmpty) {
          _wheelOptions = parsed;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController._loadWheelConfig error: $e');
      }
    }
  }

  /// Load cấu hình payout máy xèng từ Firestore (nếu có).
  ///
  /// Ưu tiên doc:
  ///   xu_game_config / slot   với field: tiers: [ {multiplier, weight}, ... ]
  /// Nếu không có, thử doc:
  ///   xu_game_config / slot_payout với field: options: [ {multiplier, weight}, ... ]
  Future<void> _loadSlotConfig() async {
    try {
      Map<String, dynamic>? data;

      // Thử doc 'slot' trước
      final doc1 = await _xuConfigCol.doc('slot').get();
      data = doc1.data();

      // Nếu chưa có hoặc không có field tiers/options thì thử doc 'slot_payout'
      if (data == null ||
          (data['tiers'] == null && data['options'] == null)) {
        final doc2 = await _xuConfigCol.doc('slot_payout').get();
        data = doc2.data();
      }

      if (data == null) return;

      // Payout tiers
      final rawList = (data['tiers'] ?? data['options']);
      if (rawList is! List) return;

      final List<_SlotPayoutTier> parsed = [];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          parsed.add(_SlotPayoutTier.fromJson(item));
        } else if (item is Map) {
          parsed.add(
            _SlotPayoutTier.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }

      if (parsed.isNotEmpty) {
        _slotTiers = parsed;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ XuController._loadSlotConfig error: $e');
      }
    }
  }

  /// Logic random phần thưởng cho vòng quay may mắn dựa trên cấu hình Firestore.
  ///
  /// Mỗi option có:
  /// - amount: số Xu thưởng
  /// - weight: trọng số xác suất (càng lớn càng dễ trúng).
  int _randomSpinReward() {
    if (_wheelOptions.isEmpty) return 0;

    int totalWeight = 0;
    for (final opt in _wheelOptions) {
      if (opt.weight > 0) {
        totalWeight += opt.weight;
      }
    }
    if (totalWeight <= 0) return 0;

    final random = Random();
    final roll = random.nextInt(totalWeight); // 0..totalWeight-1

    int acc = 0;
    for (final opt in _wheelOptions) {
      if (opt.weight <= 0) continue;
      acc += opt.weight;
      if (roll < acc) {
        return opt.amount;
      }
    }

    // phòng hờ
    return _wheelOptions.last.amount;
  }

  @override
  void dispose() {
    _farmSub?.cancel();
    super.dispose();
  }
}
