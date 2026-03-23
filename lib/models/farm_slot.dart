import 'package:cloud_firestore/cloud_firestore.dart';

class FarmSlot {
  final String id;          // slot_0, slot_1...
  final int index;          // để sort
  final String status;      // 'empty' | 'growing' | 'ready'
  final String? seedType;   // 'cheap' | 'expensive'
  final DateTime? plantedAt;
  final int? growMinutes;
  final int? rewardXu;

  FarmSlot({
    required this.id,
    required this.index,
    required this.status,
    this.seedType,
    this.plantedAt,
    this.growMinutes,
    this.rewardXu,
  });

  bool get isEmpty => status == 'empty';
  bool get isGrowing => status == 'growing';
  bool get isReady => status == 'ready';

  Duration? get growDuration =>
      growMinutes != null ? Duration(minutes: growMinutes!) : null;

  /// Dùng để hiển thị còn bao nhiêu phút nữa chín
  int? remainingMinutes(DateTime now) {
    if (plantedAt == null || growMinutes == null || !isGrowing) return null;
    final diff = now.difference(plantedAt!);
    final left = growMinutes! - diff.inMinutes;
    return left < 0 ? 0 : left;
  }

  factory FarmSlot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmSlot(
      id: doc.id,
      index: data['index'] ?? 0,
      status: data['status'] ?? 'empty',
      seedType: data['seedType'],
      plantedAt: (data['plantedAt'] as Timestamp?)?.toDate(),
      growMinutes: data['growMinutes'],
      rewardXu: data['rewardXu'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'status': status,
      'seedType': seedType,
      'plantedAt': plantedAt,
      'growMinutes': growMinutes,
      'rewardXu': rewardXu,
    };
  }
}
