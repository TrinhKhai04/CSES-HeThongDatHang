import 'package:cloud_firestore/cloud_firestore.dart';

/// Khởi tạo dữ liệu mẫu ban đầu cho Firestore
class FirestoreSeeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> runInit() async {
    await _createAdminUser();
    await _createCategories();
    await _createBrands();
  }

  Future<void> _createAdminUser() async {
    final users = _db.collection('users');
    final adminRef = users.doc('admin');

    final doc = await adminRef.get();
    if (!doc.exists) {
      await adminRef.set({
        'id': 'admin',
        'email': 'admin@shop.local',
        'phone': '0000000000',
        'password': 'admin123', // ⚠️ nên mã hoá thực tế bằng Firebase Auth
        'name': 'Administrator',
        'role': 'admin',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('✅ Seeded default admin user');
    }
  }

  Future<void> _createCategories() async {
    final categories = _db.collection('categories');
    final data = [
      {'id': 'ao', 'name': 'Áo'},
      {'id': 'quan', 'name': 'Quần'},
      {'id': 'giay', 'name': 'Giày'},
    ];

    for (var c in data) {
      final doc = categories.doc(c['id']);
      if (!(await doc.get()).exists) {
        await doc.set(c);
      }
    }
    print('✅ Seeded categories');
  }

  Future<void> _createBrands() async {
    final brands = _db.collection('brands');
    final data = [
      {'id': 'tc', 'name': 'Thai Cong'},
      {'id': 'mm', 'name': 'Minimal Maison'},
    ];

    for (var b in data) {
      final doc = brands.doc(b['id']);
      if (!(await doc.get()).exists) {
        await doc.set(b);
      }
    }
    print('✅ Seeded brands');
  }
}
