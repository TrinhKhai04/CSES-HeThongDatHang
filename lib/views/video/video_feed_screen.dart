import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/video_item.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('videos')
        .where('active', isEqualTo: true)
        .orderBy('order');

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Firestore error:\n${snap.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData) {
            return const Center(
              child: Text(
                'Không có dữ liệu',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có video trong Firestore (videos)',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // ✅ Hiệu ứng chuyển video: scale + fade nhẹ theo khoảng cách page
          return ScrollConfiguration(
            behavior: const _NoGlowScrollBehavior(),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;

                final item = VideoItem(
                  videoId: docs[i].id,
                  videoUrl: (d['videoUrl'] ?? '') as String,
                  productId: (d['productId'] ?? '') as String,
                  voucherText: (d['voucherText'] ?? '') as String,
                  voucherCode: (d['voucherCode'] ?? '') as String,
                );

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    // page hiện tại
                    double page = 0;
                    if (_pageController.hasClients) {
                      page = (_pageController.page ?? _pageController.initialPage.toDouble());
                    }

                    final delta = (i - page).abs();

                    // delta=0: page hiện tại
                    // delta≈1: page kế bên
                    final scale = (1 - (delta * 0.06)).clamp(0.94, 1.0);
                    final opacity = (1 - (delta * 0.25)).clamp(0.75, 1.0);

                    // Dịch nhẹ tạo cảm giác “depth”
                    final translateY = (delta * 18).clamp(0.0, 18.0);

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: item,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child; // bỏ glow
  }
}
