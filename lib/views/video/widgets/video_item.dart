import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/video_cache.dart';
import 'product_overlay.dart';

class VideoItem extends StatefulWidget {
  final String videoId;
  final String videoUrl;

  final String productId;
  final String voucherText;
  final String voucherCode;

  const VideoItem({
    super.key,
    required this.videoId,
    required this.videoUrl,
    required this.productId,
    required this.voucherText,
    required this.voucherCode,
  });

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  VideoPlayerController? _ctl;
  bool _ready = false;
  bool _viewLogged = false;

  bool _initFailed = false;
  String _errText = '';

  bool _muted = true;

  double _overlayHeight = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _initFailed = true;
        _errText = 'Video URL rỗng';
      });
      return;
    }

    try {
      late final VideoPlayerController ctl;

      if (kIsWeb) {
        ctl = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        final file = await VideoCache.getFile(url);
        ctl = VideoPlayerController.file(file);
      }

      await ctl.initialize().timeout(const Duration(seconds: 20));
      ctl
        ..setLooping(true)
        ..setVolume(_muted ? 0.0 : 1.0);

      if (!mounted) {
        await ctl.dispose();
        return;
      }

      setState(() {
        _ctl = ctl;
        _ready = true;
        _initFailed = false;
        _errText = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initFailed = true;
        _errText = e.toString();
      });
    }
  }

  Future<void> _logViewOnce() async {
    if (_viewLogged) return;
    _viewLogged = true;

    await FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .set({'views': FieldValue.increment(1)}, SetOptions(merge: true));
  }

  void _handleVisible(double visibleFraction) {
    final ctl = _ctl;
    if (!_ready || ctl == null) return;

    if (visibleFraction > 0.7) {
      if (!ctl.value.isPlaying) ctl.play();
      _logViewOnce();
    } else {
      if (ctl.value.isPlaying) ctl.pause();
    }
  }

  void _togglePlay() {
    final ctl = _ctl;
    if (!_ready || ctl == null) return;

    if (ctl.value.isPlaying) {
      ctl.pause();
    } else {
      ctl.play();
      _logViewOnce();
    }
    setState(() {});
  }

  void _toggleMute() {
    final ctl = _ctl;
    if (!_ready || ctl == null) return;

    setState(() => _muted = !_muted);
    ctl.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;

    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final w = mq.size.width;

    final safeBottom = mq.viewPadding.bottom;
    final barHeight = kBottomNavigationBarHeight + safeBottom;

    final gapAboveBar = (h * 0.018).clamp(8.0, 16.0);
    final overlayBottom = barHeight + gapAboveBar;

    final horizontalPad = (w * 0.04).clamp(12.0, 16.0);

    final safeTop = mq.padding.top;
    final soundTop = safeTop + 12;

    final gradientHeight = (h * 0.42).clamp(220.0, 340.0);

    final contentMaxWidth = w >= 560 ? 520.0 : double.infinity;

    final fallbackOverlayH = (w < 360) ? 156.0 : 116.0;
    final overlayH = (_overlayHeight > 0 ? _overlayHeight : fallbackOverlayH);

    final gapAboveOverlay = (h * 0.02).clamp(10.0, 18.0);
    final voucherBottom = overlayBottom + overlayH + gapAboveOverlay;

    return VisibilityDetector(
      key: ValueKey('video-${widget.videoId}'),
      onVisibilityChanged: (info) => _handleVisible(info.visibleFraction),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),

          if (_initFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white70, size: 28),
                    const SizedBox(height: 8),
                    const Text(
                      'Không phát được video',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errText,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _initFailed = false;
                          _errText = '';
                          _ready = false;
                        });
                        _init();
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          else if (!_ready || ctl == null)
            const Center(child: CircularProgressIndicator())
          else
            GestureDetector(
              onTap: _togglePlay,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // nền cover
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: ctl.value.size.width,
                      height: ctl.value.size.height,
                      child: VideoPlayer(ctl),
                    ),
                  ),
                  // blur + dark
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(color: Colors.black.withOpacity(0.35)),
                  ),
                  // khung chính 9:16 contain
                  Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ColoredBox(
                        color: Colors.black,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: ctl.value.size.width,
                            height: ctl.value.size.height,
                            child: VideoPlayer(ctl),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // play overlay
                  Center(
                    child: AnimatedOpacity(
                      opacity: ctl.value.isPlaying ? 0.0 : 0.9,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // mute button
          if (_ready && !_initFailed && ctl != null)
            Positioned(
              right: 12,
              top: soundTop,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),

          // gradient đáy
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: gradientHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.70),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // voucher
          if (widget.voucherText.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: voucherBottom,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.voucherText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // overlay sản phẩm + đo height
          Positioned(
            left: 0,
            right: 0,
            bottom: overlayBottom,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: MeasureSize(
                    onChange: (s) {
                      if ((s.height - _overlayHeight).abs() > 1) {
                        setState(() => _overlayHeight = s.height);
                      }
                    },
                    child: ProductOverlay(
                      productId: widget.productId,
                      voucherCode: widget.voucherCode,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== MeasureSize helper (không dùng .distance) =====
typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    super.key,
    required this.child,
    required this.onChange,
  });

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _oldSize;

  bool _changed(Size a, Size b, {double threshold = 1}) {
    final dx = (a.width - b.width).abs();
    final dy = (a.height - b.height).abs();
    return dx > threshold || dy > threshold;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.size;
      if (s == null) return;

      if (_oldSize == null || _changed(_oldSize!, s, threshold: 1)) {
        _oldSize = s;
        widget.onChange(s);
      }
    });

    return widget.child;
  }
}
