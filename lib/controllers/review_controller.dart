// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/product_review.dart';
//
// class ReviewController {
//   final _db = FirebaseFirestore.instance;
//
//   Stream<List<ProductReview>> getReviews(String productId) {
//     return _db
//         .collection('products/$productId/reviews')
//         .orderBy('createdAt', descending: true)
//         .snapshots()
//         .map((s) => s.docs
//         .map((d) => ProductReview.fromMap(d.id, d.data()))
//         .toList());
//   }
//
//   Future<void> addReview(String productId, Map<String, dynamic> data) async {
//     await _db.collection('products/$productId/reviews').add(data);
//   }
// }
