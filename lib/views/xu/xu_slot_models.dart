// lib/views/xu/xu_slot_models.dart
import 'package:flutter/material.dart';

/// ================== MÀU & CONSTANT DÙNG CHUNG ==================

const kBlue = Color(0xFF007AFF);
const kBlueLight = Color(0xFF4F8BFF);
const kGold = Color(0xFFFFC857);
const kGoldDark = Color(0xFFB8860B);

const kMachineYellowTop = Color(0xFFFFF5CF);
const kMachineYellowBottom = Color(0xFFFED86A);
const kDarkNavy = Color(0xFF111827);

/// ================== BIỂU TƯỢNG CỦA MÁY XÈNG ==================

enum SlotSymbolType { seven, money, star, cherry, lemon, bell }

class SlotSymbol {
  final SlotSymbolType type;
  final String emoji;
  final int baseReward; // hệ số cơ bản (7 = 10, 💰 = 5,...)

  const SlotSymbol({
    required this.type,
    required this.emoji,
    required this.baseReward,
  });
}

/// Danh sách symbol + hệ số cơ bản
const List<SlotSymbol> kSlotSymbols = [
  SlotSymbol(type: SlotSymbolType.seven, emoji: '7', baseReward: 10),
  SlotSymbol(type: SlotSymbolType.money, emoji: '💰', baseReward: 5),
  SlotSymbol(type: SlotSymbolType.star, emoji: '⭐', baseReward: 3),
  SlotSymbol(type: SlotSymbolType.cherry, emoji: '🍒', baseReward: 2),
  SlotSymbol(type: SlotSymbolType.lemon, emoji: '🍋', baseReward: 1),
  SlotSymbol(type: SlotSymbolType.bell, emoji: '🔔', baseReward: 1),
];

/// Trọng số xuất hiện của từng loại (dùng cho random)
/// 👉 KHÔNG const để có thể update theo cấu hình admin.
Map<SlotSymbolType, int> kSlotSymbolWeights = {
  SlotSymbolType.seven: 1, // hiếm nhất
  SlotSymbolType.money: 2,
  SlotSymbolType.star: 3,
  SlotSymbolType.cherry: 4,
  SlotSymbolType.lemon: 5,
  SlotSymbolType.bell: 5,
};

/// Map string key (Firestore) -> enum
SlotSymbolType? slotSymbolTypeFromKey(String key) {
  switch (key) {
    case 'seven':
      return SlotSymbolType.seven;
    case 'money':
      return SlotSymbolType.money;
    case 'star':
      return SlotSymbolType.star;
    case 'cherry':
      return SlotSymbolType.cherry;
    case 'lemon':
      return SlotSymbolType.lemon;
    case 'bell':
      return SlotSymbolType.bell;
    default:
      return null;
  }
}

/// Hệ số nhân thêm theo số lượng symbol giống nhau
/// 3 cái: x1, 4 cái: x2, 5 cái: x3
/// 👉 KHÔNG const để có thể chỉnh runtime.
Map<int, int> kMatchCountFactor = {
  3: 1,
  4: 2,
  5: 3,
};

/// Tối thiểu bao nhiêu symbol giống nhau thì mới được tính thưởng
int kMinMatchToWin = 3;

/// Ngưỡng multiplier để coi là Jackpot (dùng cho rung & pháo hoa)
int kJackpotMultiplierThreshold = 15;

/// Hàm cho phép override cấu hình từ Firestore (admin chỉnh)
/// - `symbolWeights`: map string key -> weight, ví dụ:
///   { "seven": 1, "money": 3, ... }
void applyRuntimeSlotConfig({
  int? minMatchToWin,
  int? jackpotMultiplierThreshold,
  Map<int, int>? matchCountFactor,
  Map<String, int>? symbolWeights,
}) {
  if (minMatchToWin != null && minMatchToWin >= 2) {
    kMinMatchToWin = minMatchToWin;
  }
  if (jackpotMultiplierThreshold != null &&
      jackpotMultiplierThreshold > 0) {
    kJackpotMultiplierThreshold = jackpotMultiplierThreshold;
  }
  if (matchCountFactor != null && matchCountFactor.isNotEmpty) {
    kMatchCountFactor = Map<int, int>.from(matchCountFactor);
  }

  if (symbolWeights != null && symbolWeights.isNotEmpty) {
    final mapped = <SlotSymbolType, int>{};
    symbolWeights.forEach((key, value) {
      final type = slotSymbolTypeFromKey(key);
      if (type != null && value >= 0) {
        mapped[type] = value;
      }
    });
    if (mapped.isNotEmpty) {
      kSlotSymbolWeights = mapped;
    }
  }
}

/// ================ KẾT QUẢ PHÂN TÍCH 1 LẦN QUAY =================

class SlotResultMeta {
  final int multiplier; // hệ số nhân tổng thưởng (base * factor)
  final SlotSymbol? winningSymbol;
  final List<int> winningIndices;

  const SlotResultMeta(
      this.multiplier,
      this.winningSymbol,
      this.winningIndices,
      );

  bool get isWin => multiplier > 0;
  bool get isJackpot => multiplier >= kJackpotMultiplierThreshold;
}
