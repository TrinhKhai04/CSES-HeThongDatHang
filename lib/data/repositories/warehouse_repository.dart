import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/warehouse_config.dart'; // để dùng Warehouse, Geo

class WarehouseRepository {
  final _col = FirebaseFirestore.instance.collection('warehouses');

  Future<List<Warehouse>> getAll() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => Warehouse.fromMap(d.data()))
        .toList();
  }

  Future<void> add(Warehouse w) async {
    await _col.add(w.toMap());
  }

  Future<void> update(String docId, Warehouse w) async {
    await _col.doc(docId).update(w.toMap());
  }

  Future<void> delete(String docId) async {
    await _col.doc(docId).delete();
  }

  /// 🌱 Seed 1 lần từ danh sách tĩnh trong WarehouseConfig
  Future<void> seedFromStaticIfEmpty() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final all = WarehouseConfig.kWarehouses;
    final batch = FirebaseFirestore.instance.batch();
    for (final w in all) {
      batch.set(_col.doc(), w.toMap());
    }
    await batch.commit();
  }
}
