import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/order_controller.dart'; // chỗ có ShippingConfig

class ShippingConfigRepository {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('settings').doc('shippingConfig');

  Future<ShippingConfig> getConfig() async {
    final snap = await _doc.get();
    return ShippingConfig.fromMap(
        snap.data() as Map<String, dynamic>?);
  }

  Future<void> saveConfig(ShippingConfig cfg) async {
    await _doc.set(cfg.toMap(), SetOptions(merge: true));
  }
}
