// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class ProductReview {
//   final String id;
//   final String userName;
//   final String comment;
//   final int rating;
//   final DateTime createdAt;
//
//   ProductReview({
//     required this.id,
//     required this.userName,
//     required this.comment,
//     required this.rating,
//     required this.createdAt,
//   });
//
//   factory ProductReview.fromMap(String id, Map<String, dynamic> data) {
//     return ProductReview(
//       id: id,
//       userName: data['userName'] ?? 'Ẩn danh',
//       comment: data['comment'] ?? '',
//       rating: data['rating'] ?? 0,
//       createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//     );
//   }
// }
