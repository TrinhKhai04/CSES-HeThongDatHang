// lib/views/xu/xu_lucky_wheel_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/xu_controller.dart';

const _kBlue = Color(0xFF007AFF);
const _kBlueLight = Color(0xFF4F8BFF);
const _kBlueSoft = Color(0xFFE0EDFF);

class XuLuckyWheelScreen extends StatefulWidget {
  const XuLuckyWheelScreen({super.key});

  @override
  State<XuLuckyWheelScreen> createState() => _XuLuckyWheelScreenState();
}

class _XuLuckyWheelScreenState extends State<XuLuckyWheelScreen>
    with WidgetsBindingObserver {
  /// Các mốc phần thưởng thực (phải khớp logic trong XuController)
  static const List<int> _baseRewards = [50, 100, 200, 500];

  /// Các ô trên vòng quay (10 ô)
  final List<int> _segmentRewards = const [
    50,
    100,
    50,
    200,
    100,
    50,
    200,
    100,
    500, // ô nổi bật
    50,
  ];

  /// Danh sách link YouTube để xem quảng cáo (dạng watch, KHÔNG phải embed)
  static const List<String> _adVideoUrls = [
    'https://www.youtube.com/watch?v=C41MkjY384o&t=4s',
    'https://www.youtube.com/watch?v=18g8gOz2Gd0&t=3s',
    'https://www.youtube.com/watch?v=EzHkAjeHhoc&t=9s',
  ];

  // broadcast để FortuneWheel listen an toàn
  final StreamController<int> _selected = StreamController<int>.broadcast();

  bool _spinning = false;

  // trạng thái xem quảng cáo
  bool _watchingAd = false;
  DateTime? _adStartTime; // thời điểm mở YouTube hiện tại
  bool _pendingAdReward = false; // đang chờ xét thưởng (tích luỹ thời gian)
  int _adWatchedSeconds = 0; // tổng số giây đã xem (cộng dồn)
  static const int _requiredAdSeconds = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selected.close();
    super.dispose();
  }

  /// Khi app chuyển trạng thái (background / resume)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // quay lại app -> thử cập nhật tiến độ xem quảng cáo
      _updateAdWatchProgress(showSnackIfNotEnough: true);
    }
  }

  /// Cập nhật thời gian xem quảng cáo từ lần mở gần nhất (_adStartTime)
  Future<void> _updateAdWatchProgress({
    required bool showSnackIfNotEnough,
  }) async {
    if (!_pendingAdReward || _adStartTime == null || !mounted) return;

    final now = DateTime.now();
    final diffSeconds = now.difference(_adStartTime!).inSeconds;
    if (diffSeconds <= 0) return;

    final xu = context.read<XuController>();

    _adWatchedSeconds += diffSeconds;

    // reset session hiện tại (đã quay lại app)
    setState(() {
      _watchingAd = false;
      _adStartTime = null;
    });

    if (_adWatchedSeconds >= _requiredAdSeconds) {
      // 🎉 ĐỦ THỜI GIAN → thưởng 1 lượt quay
      await xu.grantAdSpinWithContext(context);

      setState(() {
        _pendingAdReward = false;
        _adWatchedSeconds = 0;
      });

      // Hỏi quay luôn không – popup kiểu “card” đẹp hơn
      final spinNow = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Dialog(
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kBlueSoft,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: _kBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nhận lượt quay thành công',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bạn vừa nhận thêm 1 lượt quay từ video.\n'
                        'Bạn muốn quay luôn bây giờ hay để dành sau?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4B5563),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Để sau'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Quay luôn',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (spinNow == true && mounted) {
        await _spin();
      }
    } else if (showSnackIfNotEnough) {
      final remain = _requiredAdSeconds - _adWatchedSeconds;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          content: Text(
            'Bạn mới xem khoảng $_adWatchedSeconds giây.\n'
                'Xem thêm khoảng $remain giây nữa để nhận lượt quay.',
          ),
        ),
      );
    }
  }

  /// Quay vòng – sử dụng lượt miễn phí hoặc lượt thêm (nếu có)
  Future<void> _spin() async {
    if (_spinning) return;

    final auth = context.read<AuthController>();
    final xu = context.read<XuController>();
    final uid = auth.user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Bạn cần đăng nhập để quay vòng may mắn.'),
        ),
      );
      return;
    }

    // Hôm nay không còn lượt nào (free + lượt thêm)
    if (!xu.canSpin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text(
            'Hôm nay bạn đã sử dụng hết lượt quay.\n'
                'Hãy xem video để nhận lượt quay thêm hoặc quay lại vào ngày mai nhé!',
          ),
        ),
      );
      return;
    }

    setState(() => _spinning = true);

    // Transaction: random + cộng Xu (free hoặc lượt thêm)
    final reward = await xu.spinToday(context);
    if (!mounted) return;

    if (!_baseRewards.contains(reward)) {
      setState(() => _spinning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Có lỗi khi quay thưởng, vui lòng thử lại sau.'),
        ),
      );
      return;
    }

    // Tìm tất cả index trên vòng quay trùng reward
    final indices = <int>[];
    for (int i = 0; i < _segmentRewards.length; i++) {
      if (_segmentRewards[i] == reward) indices.add(i);
    }

    int index = 0;
    if (indices.isNotEmpty) {
      index = indices[math.Random().nextInt(indices.length)];
    }

    // phát index cho FortuneWheel quay
    _selected.add(index);
  }

  /// Xử lý khi bấm nút tròn giữa / nút QUAY bên dưới
  Future<void> _onCenterTap() async {
    final xu = context.read<XuController>();
    if (xu.canSpin) {
      await _spin();
    } else {
      final spunToday = xu.spunToday;
      final adSpinsLeft = xu.adSpinsLeftToday;

      if (spunToday && adSpinsLeft == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            content: Text(
              'Bạn đã hết lượt quay hôm nay.\n'
                  'Hãy xem video 15 giây để nhận thêm 1 lượt quay nhé!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            content: Text('Hôm nay bạn đã dùng hết lượt quay.'),
          ),
        );
      }
    }
  }

  /// Mở YouTube app / browser, không embed
  Future<void> _watchAdForExtraSpin() async {
    if (_watchingAd) return;

    final auth = context.read<AuthController>();
    final xu = context.read<XuController>();
    final uid = auth.user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Bạn cần đăng nhập để nhận lượt quay thêm.'),
        ),
      );
      return;
    }

    if (_adVideoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Chưa cấu hình video quảng cáo.'),
        ),
      );
      return;
    }

    // 👉 Trước khi mở video mới, cập nhật thời gian đã xem của video trước (nếu có)
    await _updateAdWatchProgress(showSnackIfNotEnough: false);

    // random 1 URL YouTube
    final url = _adVideoUrls[math.Random().nextInt(_adVideoUrls.length)];
    final uri = Uri.parse(url);

    setState(() {
      _watchingAd = true;
      _adStartTime = DateTime.now();

      if (!_pendingAdReward) {
        _pendingAdReward = true;
        _adWatchedSeconds = 0;
      }
    });

    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            content: Text('Không mở được YouTube, vui lòng thử lại.'),
          ),
        );
        setState(() {
          _watchingAd = false;
          _pendingAdReward = false;
          _adStartTime = null;
          _adWatchedSeconds = 0;
        });
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          content: Text('Có lỗi khi mở video, vui lòng thử lại.'),
        ),
      );
      setState(() {
        _watchingAd = false;
        _pendingAdReward = false;
        _adStartTime = null;
        _adWatchedSeconds = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final xu = context.watch<XuController>();

    final spunToday = xu.spunToday; // đã dùng lượt free?
    final adSpinsLeft = xu.adSpinsLeftToday; // lượt thêm hiện có
    final canSpin = !_spinning && xu.canSpin; // hiện tại chưa dùng, để dành nếu sau này dùng nút phụ

    // màu cho từng ô – ô 500 Xu tô vàng đậm, các ô còn lại xanh
    Color _bgForReward(int r, int index) {
      if (r == 500) {
        return const Color(0xFFFFF7D6); // vàng nhạt nổi bật hơn
      }
      return index.isEven
          ? const Color(0xFFCFDDFF)
          : const Color(0xFFE5EFFF);
    }

    Color _fgForReward(int r) {
      if (r == 500) return const Color(0xFF92400E);
      return const Color(0xFF0F172A);
    }

    Color _iconColorForReward(int r) {
      if (r == 500) return const Color(0xFFF59E0B);
      return const Color(0xFF0369A1);
    }

    String _spinButtonText() {
      if (!xu.canSpin) {
        return 'Hết lượt quay hôm nay';
      }
      if (spunToday && adSpinsLeft > 0) {
        return 'Quay bằng lượt thêm';
      }
      return 'Quay ngay';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Vòng quay may mắn',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: _kBlue),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE3EDFF),
                Color(0xFFF9FAFB),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ==== THẺ GIỚI THIỆU (banner) ====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kBlueLight, _kBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.casino_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quay 1 lần mỗi ngày\nrinh ngay Xu may mắn!',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        !spunToday
                                            ? Icons.bolt_rounded
                                            : (adSpinsLeft > 0
                                            ? Icons.replay_rounded
                                            : Icons.lock_clock_rounded),
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        !spunToday
                                            ? 'Còn 1 lượt quay miễn phí hôm nay'
                                            : (adSpinsLeft > 0
                                            ? 'Bạn có $adSpinsLeft lượt quay thêm'
                                            : 'Hẹn bạn ngày mai ✨'),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ===== KHU VỰC BÁNH XE =====
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final shortest = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final wheelSize = shortest * 0.95;

                    return Center(
                      child: SizedBox(
                        width: wheelSize,
                        height: wheelSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // bóng ellipse dưới bánh xe
                            Positioned(
                              bottom: wheelSize * 0.03,
                              child: Container(
                                width: wheelSize * 0.70,
                                height: wheelSize * 0.18,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius:
                                  BorderRadius.circular(wheelSize),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 30,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // bokeh mờ phía sau
                            Positioned(
                              top: wheelSize * 0.06,
                              left: wheelSize * 0.12,
                              child: Container(
                                width: wheelSize * 0.45,
                                height: wheelSize * 0.45,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: wheelSize * 0.05,
                              right: wheelSize * 0.12,
                              child: Container(
                                width: wheelSize * 0.34,
                                height: wheelSize * 0.34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kBlueSoft.withOpacity(0.70),
                                ),
                              ),
                            ),

                            // vòng ngoài bóng đổ
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFE0EAFF),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 26,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                            ),

                            // viền + FortuneWheel được ClipOval
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFFF9FBFF),
                                      Color(0xFFE0EAFF),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFD4DDFB),
                                    width: 4,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xFFFDFEFF),
                                          Color(0xFFE3ECFF),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5F5),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: FortuneWheel(
                                        selected: _selected.stream,
                                        animateFirst: false,
                                        indicators: const <FortuneIndicator>[
                                          FortuneIndicator(
                                            alignment: Alignment.topCenter,
                                            child: Padding(
                                              padding: EdgeInsets.only(top: 6),
                                              child: TriangleIndicator(
                                                color: _kBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                        items: [
                                          for (int i = 0;
                                          i < _segmentRewards.length;
                                          i++)
                                            FortuneItem(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .monetization_on_rounded,
                                                    size: 20,
                                                    color: _iconColorForReward(
                                                      _segmentRewards[i],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '+${_segmentRewards[i]} Xu',
                                                    style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.w700,
                                                      fontSize: 13,
                                                      color: _fgForReward(
                                                        _segmentRewards[i],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              style: FortuneItemStyle(
                                                color: _bgForReward(
                                                  _segmentRewards[i],
                                                  i,
                                                ),
                                                borderColor: Colors.white,
                                                borderWidth: 2,
                                              ),
                                            ),
                                        ],
                                        onAnimationEnd: () {
                                          setState(() => _spinning = false);

                                          final reward = xu.spinRewardToday;
                                          showDialog(
                                            context: context,
                                            barrierColor: Colors.black
                                                .withOpacity(0.35),
                                            builder: (ctx) {
                                              final theme = Theme.of(ctx);
                                              return Dialog(
                                                insetPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 28,
                                                  vertical: 24,
                                                ),
                                                backgroundColor:
                                                Colors.transparent,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        24),
                                                    gradient:
                                                    const LinearGradient(
                                                      begin:
                                                      Alignment.topLeft,
                                                      end: Alignment
                                                          .bottomRight,
                                                      colors: [
                                                        Color(0xFFF4F7FF),
                                                        Color(0xFFE0F7FF),
                                                      ],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.14),
                                                        blurRadius: 18,
                                                        offset:
                                                        const Offset(0, 10),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                    const EdgeInsets.fromLTRB(
                                                      20,
                                                      18,
                                                      20,
                                                      14,
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                      MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding:
                                                          const EdgeInsets
                                                              .all(12),
                                                          decoration:
                                                          const BoxDecoration(
                                                            shape:
                                                            BoxShape.circle,
                                                            gradient:
                                                            LinearGradient(
                                                              colors: [
                                                                Color(
                                                                    0xFFE0EDFF),
                                                                Color(
                                                                    0xFFC7D2FE),
                                                              ],
                                                            ),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .monetization_on_rounded,
                                                            color: _kBlue,
                                                            size: 26,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 12),
                                                        Text(
                                                          'Chúc mừng 🎉',
                                                          style: theme
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                            fontWeight:
                                                            FontWeight.w700,
                                                            color: const Color(
                                                                0xFF111827),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          'Bạn vừa nhận được',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                            color: const Color(
                                                                0xFF4B5563),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          '+$reward Xu',
                                                          style: theme
                                                              .textTheme
                                                              .headlineSmall
                                                              ?.copyWith(
                                                            fontWeight:
                                                            FontWeight.w800,
                                                            color: _kBlue,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Container(
                                                          padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                          decoration:
                                                          BoxDecoration(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                0.9),
                                                            borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                999),
                                                          ),
                                                          child: Text(
                                                            'Xu đã được cộng vào ví của bạn',
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                              color: const Color(
                                                                  0xFF4B5563),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 18),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                              FilledButton(
                                                                style: FilledButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                  _kBlue,
                                                                  foregroundColor:
                                                                  Colors
                                                                      .white,
                                                                  shape:
                                                                  RoundedRectangleBorder(
                                                                    borderRadius:
                                                                    BorderRadius.circular(
                                                                        999),
                                                                  ),
                                                                  padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                    vertical:
                                                                    10,
                                                                  ),
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                        ctx)
                                                                        .pop(),
                                                                child: const Text(
                                                                  'Tiếp tục quay',
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),

                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
                                                                  .pop(),
                                                          child: const Text(
                                                              'Đóng'),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ===== NÚT TRUNG TÂM – COIN CSES XANH / TRẮNG =====
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _spinning ? null : _onCenterTap,
                              child: AnimatedScale(
                                scale: _spinning ? 0.94 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                child: Container(
                                  width: wheelSize * 0.24,
                                  height: wheelSize * 0.24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [_kBlueLight, _kBlue],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kBlue.withOpacity(0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // glow xanh sau coin
                                      Container(
                                        width: wheelSize * 0.18,
                                        height: wheelSize * 0.18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.55),
                                              _kBlueSoft.withOpacity(0.55),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // mặt coin trắng + text
                                      // mặt coin trắng + text
                                      Container(
                                        width: wheelSize * 0.15,
                                        height: wheelSize * 0.15,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Text(
                                              'CSES',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight
                                                    .w800, // 👈 PHẢI CÓ "fontWeight:" và ".w800", không để FontWeight trơ
                                                letterSpacing: 1.2,
                                                color: _kBlue,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'QUAY',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight
                                                    .w600, // 👈 tương tự ở đây
                                                letterSpacing: 1.1,
                                                color: _kBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // highlight 3D nhẹ
                                      Positioned(
                                        top: wheelSize * 0.02,
                                        child: Opacity(
                                          opacity: 0.55,
                                          child: Container(
                                            width: wheelSize * 0.11,
                                            height: wheelSize * 0.05,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(999),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white
                                                      .withOpacity(0.96),
                                                  Colors.white
                                                      .withOpacity(0.0),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ===== KHỐI INFO + NÚT XEM VIDEO =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE9F2FF),
                        Color(0xFFE4F9FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ───────── TITLE + ICON ─────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: Color(0xFFFB923C),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mẹo nhận thêm Xu',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tối đa nhận được 500 Xu cho mỗi lượt quay.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mỗi lần xem video 15 giây, bạn nhận thêm 1 lượt quay. '
                                      'Có thể xem nhiều lần trong ngày.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),

                      // ───────── CTA: LUÔN HIỆN NÚT XEM VIDEO ─────────
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            side: BorderSide(
                              color: _watchingAd ? cs.outline : _kBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          onPressed:
                          _watchingAd ? null : _watchAdForExtraSpin,
                          icon: _watchingAd
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(
                            Icons.play_circle_fill_rounded,
                            size: 18,
                            color: _kBlue,
                          ),
                          label: Text(
                            _watchingAd
                                ? 'Đang mở YouTube...'
                                : 'Xem video 15 giây để nhận 1 lượt quay',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _kBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
