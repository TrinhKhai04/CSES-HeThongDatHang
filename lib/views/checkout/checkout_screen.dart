// lib/views/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🧩 Controllers
import '../../controllers/cart_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/address_controller.dart';
import '../../controllers/settings_controller.dart';

// 📦 Models & Data
import '../../models/app_address.dart';
import '../../data/repositories/voucher_repository.dart';
import '../../models/voucher.dart';

// 🧭 Routes
import '../../routes/app_routes.dart';

/// Màn hình thanh toán (Checkout)
/// - Theme-aware (Dark/Light)
/// - Gợi ý voucher theo user + subtotal (chỉ tính trên sản phẩm được chọn)
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _noteCtl = TextEditingController();
  final _voucherCtl = TextEditingController();
  bool _submitting = false;

  // recognizer cho link "Điều khoản mua hàng của CSES"
  final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer();

  // ID phương thức vận chuyển đang chọn (default: Tiết kiệm)
  String _selectedShippingId = 'economy';

  // Phí ship gốc (từ OSRM + ShippingConfig) – dùng để tính các option
  double? _baseShippingFee;

  // Số dư CSES Xu hiện có và toggle dùng Xu
  int _availableCoins = 0;
  bool _useCoins = false;

  ShippingMethodOption get _selectedShippingMethod =>
      kShippingOptions.firstWhere((m) => m.id == _selectedShippingId);

  // Tính phí theo từng phương thức dựa trên baseFee
  double _shippingFeeFor(ShippingMethodOption m, double baseFee) {
    if (baseFee <= 0) return 0;
    switch (m.id) {
      case 'fast':
        return (baseFee + 15000).clamp(0, double.infinity);
      case 'economy':
      default:
        return baseFee;
    }
  }

  /// Tính lại phí ship dựa trên địa chỉ mặc định hiện tại
  Future<void> _recalculateShippingForCurrentAddress() async {
    final cart = context.read<CartController>();
    final addrCtrl = context.read<AddressController>();
    final orderCtrl = context.read<OrderController>();

    final AppAddress? addr = addrCtrl.defaultAddress;
    if (addr == null || addr.lat == null || addr.lng == null) {
      if (mounted) {
        setState(() {
          _baseShippingFee = null;
        });
      }
      return;
    }

    await orderCtrl.estimateShippingFeeForCart(
      cart: cart,
      toLat: addr.lat!,
      toLng: addr.lng!,
    );

    final base = cart.shippingFee < 0 ? 0.0 : cart.shippingFee;

    final method = _selectedShippingMethod;
    final newFee = _shippingFeeFor(method, base);
    cart.setShippingFee(newFee);

    if (mounted) {
      setState(() {
        _baseShippingFee = base;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final addrCtrl = context.read<AddressController>();

        // Địa chỉ & phí ship gốc
        await addrCtrl.fetchDefaultAddress(uid);
        await _recalculateShippingForCurrentAddress();

        // Lấy số dư CSES Xu của user
        try {
          final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final data = snap.data();
          final rawXu = data?['xuBalance'] ?? data?['coins'] ?? 0;
          final int xu =
          rawXu is num ? rawXu.toInt() : int.tryParse('$rawXu') ?? 0;
          if (mounted) {
            setState(() {
              _availableCoins = xu;
            });
          }
        } catch (_) {
          // lỗi → coi như 0 xu
        }
      }
    });
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    _voucherCtl.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  // ================= Bottom sheet voucher: gợi ý theo user + subtotal =================
  Future<void> _openVoucherSuggestions(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final cart = context.read<CartController>();
    final repo = VoucherRepository();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final subtotal = cart.selectedSubtotal;

    List<Voucher> available;
    try {
      if (uid != null) {
        final allActive = await repo.listActive();
        final usable = <Voucher>[];

        for (final v in allActive) {
          if (v.minSubtotal != null && subtotal < v.minSubtotal!) continue;

          final canUse = await repo.canUserUse(voucher: v, userId: uid);
          if (!canUse) continue;

          usable.add(v);
        }

        available = usable;
      } else {
        final all = await repo.listActive();
        available = all
            .where((v) => v.minSubtotal == null || subtotal >= v.minSubtotal!)
            .toList();
      }
    } catch (e) {
      available = const [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được danh sách mã: $e')),
        );
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chọn mã giảm giá',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: available.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Chưa có mã phù hợp đơn hiện tại.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final v = available[i];
                    final subtitle = v.isPercent
                        ? 'Giảm ${(v.discount * 100).toStringAsFixed(0)}%'
                        : 'Giảm ${_vnd(v.discount)}';
                    return _VoucherTile(
                      code: v.code,
                      subtitle: subtitle,
                      onTap: () async {
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Bạn cần đăng nhập để áp dụng mã.'),
                            ),
                          );
                          return;
                        }
                        try {
                          await cart.applyVoucherCode(v.code, uid);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã áp dụng mã ${v.code}'),
                              backgroundColor: cs.inverseSurface,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Bottom sheet chọn phương thức vận chuyển ============
  Future<void> _openShippingMethods(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cart = context.read<CartController>();

    final double currentFee = cart.shippingFee;
    final double baseFee = _baseShippingFee ?? currentFee;

    String tempSelectedId = _selectedShippingId;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Phương thức vận chuyển',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: cs.outlineVariant),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setModalState) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        itemCount: kShippingOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final m = kShippingOptions[i];
                          final selected = m.id == tempSelectedId;
                          final feeForOption = _shippingFeeFor(m, baseFee);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setModalState(() {
                                tempSelectedId = m.id;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                  selected ? cs.primary : cs.outlineVariant,
                                  width: selected ? 1.2 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const RoundedIcon(
                                    icon: Icons.local_shipping_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              m.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              feeForOption == 0
                                                  ? 'Miễn phí'
                                                  : _vnd(feeForOption),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: feeForOption == 0
                                                    ? Colors.green
                                                    : cs.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m.subtitle,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        if (m.note != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            m.note!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        final selected = kShippingOptions
                            .firstWhere((m) => m.id == tempSelectedId);
                        final double base =
                            _baseShippingFee ?? cart.shippingFee;
                        final newFee = _shippingFeeFor(selected, base);
                        cart.setShippingFee(newFee);
                        Navigator.of(ctx).pop(tempSelectedId);
                      },
                      child: const Text(
                        'Xác nhận',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedShippingId = result;
      });
    }
  }

  // =============================== UI chính ===============================
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Nền kiểu iOS Settings
    final pageBg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    // scale nhẹ
    final clampedScale = media.textScaler.scale(1).clamp(1.0, 1.15);

    // Responsive: giới hạn maxWidth nội dung cho tablet / màn lớn
    final deviceWidth = media.size.width;
    final shortestSide = media.size.shortestSide;
    final bool isTablet = shortestSide >= 600;

    final double contentMaxWidth = isTablet ? 640 : deviceWidth;
    final double horizontalPadding = isTablet ? 24 : 16;
    final double sectionSpacing = isTablet ? 24 : 20;

    final cart = context.watch<CartController>();
    final addressCtrl = context.watch<AddressController>();
    final orderCtrl = context.read<OrderController>();
    final AppAddress? address = addressCtrl.defaultAddress;

    final settings = context.watch<SettingsController>();
    final paymentMethod = settings.paymentMethod;

    // Tiền: chỉ dựa trên sản phẩm được chọn
    final double subtotal = cart.selectedSubtotal;
    final double discount = cart.discountAmount;
    final double shippingFee = cart.shippingFee;

    // CSES Xu: 1 xu = 1đ, tối đa (subtotal - discount)
    final double coinBaseForUse =
    (subtotal - discount).clamp(0, double.infinity);
    final int maxByValue =
    coinBaseForUse <= 0 ? 0 : coinBaseForUse.floor();
    final int coinsCanUse = maxByValue == 0
        ? 0
        : (maxByValue < _availableCoins ? maxByValue : _availableCoins);
    final bool canUseCoins = coinsCanUse > 0;

    final int coinsUsed = (_useCoins && canUseCoins) ? coinsCanUse : 0;
    final double coinDiscount = coinsUsed.toDouble();

    // Tổng cộng
    final double total =
    (subtotal + shippingFee - discount - coinDiscount).clamp(0, double.infinity);

    // Xu nhận được: 1 xu / 1.000đ sau mọi giảm giá
    final double coinBaseForReward =
    (subtotal - discount - coinDiscount).clamp(0, double.infinity);
    final int rewardCoins =
    coinBaseForReward <= 0 ? 0 : (coinBaseForReward ~/ 1000);

    // card shipping chính đang là Tiết kiệm?
    final bool isEconomyCardSelected =
        _selectedShippingMethod.id == 'economy';

    // gán onTap cho recognizer
    _termsRecognizer.onTap = () {
      Navigator.pushNamed(context, AppRoutes.policyTerms);
    };

    // Danh sách sản phẩm được chọn
    final selectedItems =
    cart.items.where((it) => cart.selectedKeys.contains(it.key)).toList();

    // Map phương thức thanh toán → key + text hiển thị
    String paymentTitle;
    String paymentSubtitle;
    IconData paymentIcon;
    String paymentKey;

    if (paymentMethod == PaymentMethod.bankTransfer) {
      paymentKey = 'bank_transfer';
      paymentTitle = 'Chuyển khoản ngân hàng';
      paymentSubtitle = 'Chuyển khoản theo thông tin tài khoản của CSES.';
      paymentIcon = Icons.account_balance_outlined;
    } else if (paymentMethod == PaymentMethod.momo) {
      paymentKey = 'momo';
      paymentTitle = 'Ví MoMo';
      paymentSubtitle = 'Thanh toán nhanh qua ví MoMo (sắp ra mắt).';
      paymentIcon = Icons.qr_code_2_outlined;
    } else {
      paymentKey = 'cod';
      paymentTitle = 'Thanh toán khi nhận hàng (COD)';
      paymentSubtitle =
      'Phổ biến, thanh toán trực tiếp cho shipper khi nhận hàng.';
      paymentIcon = Icons.payments_outlined;
    }

    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(clampedScale),
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          foregroundColor:
          theme.appBarTheme.foregroundColor ?? cs.onSurface,
          title: Text(
            'Xác nhận đơn hàng',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SizedBox(
              width: contentMaxWidth,
              child: Column(
                children: [
                  // ================== CONTENT SCROLL ==================
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 12, horizontalPadding, 12),
                      children: [
                        // ---- Địa chỉ ----
                        SectionCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const RoundedIcon(
                                  icon: Icons.location_on_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: address != null
                                    ? Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      address.phone,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${address.line1}, '
                                          '${address.ward}, '
                                          '${address.district}, '
                                          '${address.province}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                )
                                    : Text(
                                  'Vui lòng thêm địa chỉ giao hàng.',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  final addrCtrl =
                                  context.read<AddressController>();

                                  await Navigator.pushNamed(
                                      context, AppRoutes.addressList);

                                  if (uid == null) return;

                                  await addrCtrl.fetchDefaultAddress(uid);
                                  await _recalculateShippingForCurrentAddress();
                                },
                                child: const Text('Thay đổi'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- Phương thức vận chuyển ----
                        SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Phương thức vận chuyển',
                                      style:
                                      theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => _openShippingMethods(context),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Xem tất cả',
                                          style: TextStyle(
                                            color: cs.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: cs.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _openShippingMethods(context),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withOpacity(
                                        isEconomyCardSelected ? 1.0 : 0.93),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: cs.primary.withOpacity(0.20),
                                      width: 1.1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const RoundedIcon(
                                        icon: Icons.local_shipping_outlined,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  _selectedShippingMethod.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  shippingFee == 0
                                                      ? 'Miễn phí'
                                                      : _vnd(shippingFee),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: shippingFee == 0
                                                        ? Colors.green
                                                        : cs.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedShippingMethod.subtitle,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                            if (_selectedShippingMethod.note !=
                                                null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedShippingMethod.note!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- Phương thức thanh toán ----
                        SectionCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.paymentMethods),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RoundedIcon(icon: paymentIcon),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Phương thức thanh toán',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        paymentTitle,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        paymentSubtitle,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- Mã giảm giá ----
                        SectionCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: ThemedTextField(
                                  controller: _voucherCtl,
                                  hintText: 'Nhập mã giảm giá',
                                  textInputAction: TextInputAction.done,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final code = _voucherCtl.text.trim();
                                  if (code.isEmpty) return;

                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Bạn cần đăng nhập để áp dụng mã.'),
                                      ),
                                    );
                                    return;
                                  }

                                  final repo = VoucherRepository();
                                  final v = await repo.getByCode(code);
                                  if (v == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Mã không hợp lệ hoặc đã hết hạn.'),
                                      ),
                                    );
                                    return;
                                  }

                                  final subtotal = context
                                      .read<CartController>()
                                      .selectedSubtotal;
                                  if (v.minSubtotal != null &&
                                      subtotal < v.minSubtotal!) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đơn tối thiểu ${_vnd(v.minSubtotal!)} để dùng mã này.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final canUse = await repo.canUserUse(
                                      voucher: v, userId: uid);
                                  if (!canUse) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Bạn đã dùng tối đa số lần cho mã này.'),
                                      ),
                                    );
                                    return;
                                  }

                                  await cart.applyVoucherCode(code, uid);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        cart.voucherError ??
                                            'Đã áp dụng mã: ${cart.appliedVoucher?.code}',
                                      ),
                                      backgroundColor: cs.inverseSurface,
                                    ),
                                  );
                                },
                                child: const Text('Áp dụng'),
                              ),
                              const SizedBox(width: 4),
                              InkResponse(
                                radius: 24,
                                onTap: () => _openVoucherSuggestions(context),
                                child: Icon(Icons.local_offer_outlined,
                                    color: cs.onSurface),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- CSES Xu ----
                        SectionCard(
                          child: Row(
                            children: [
                              const RoundedIcon(
                                  icon: Icons.monetization_on_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CSES Xu',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (_availableCoins > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (_useCoins && canUseCoins)
                                              ? cs.primary.withOpacity(0.10)
                                              : cs.surfaceContainerHighest,
                                          borderRadius:
                                          BorderRadius.circular(999),
                                          border: Border.all(
                                            color: (_useCoins && canUseCoins)
                                                ? cs.primary
                                                : cs.outlineVariant
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        child: Text(
                                          'Bạn đang có $_availableCoins xu',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: (_useCoins && canUseCoins)
                                                ? cs.primary
                                                : cs.onSurface,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'Bạn chưa có xu để sử dụng',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    if (coinsCanUse > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Có thể dùng tối đa $coinsCanUse xu (-${_vnd(coinDiscount)})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _useCoins && canUseCoins,
                                onChanged: canUseCoins
                                    ? (v) {
                                  setState(() {
                                    _useCoins = v;
                                  });
                                }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- Ghi chú ----
                        SectionCard(
                          child: ThemedTextField(
                            controller: _noteCtl,
                            maxLines: 2,
                            hintText: 'Ghi chú cho người bán (tùy chọn)',
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- Sản phẩm trong đơn ----
                        SectionCard(
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Sản phẩm trong đơn',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (selectedItems.isEmpty)
                                Text(
                                  'Chưa có sản phẩm nào được chọn.',
                                  style:
                                  TextStyle(color: cs.onSurfaceVariant),
                                )
                              else
                                ...selectedItems.map((it) {
                                  final cs =
                                      Theme.of(context).colorScheme;
                                  final String imageUrl =
                                      it.product.imageUrl ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          child: SizedBox(
                                            width: 52,
                                            height: 52,
                                            child: imageUrl.isNotEmpty
                                                ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) =>
                                                  Container(
                                                    color: cs
                                                        .surfaceContainerHighest,
                                                    child: Icon(
                                                      Icons
                                                          .image_not_supported_outlined,
                                                      size: 24,
                                                      color: cs
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                            )
                                                : Container(
                                              color: cs
                                                  .surfaceContainerHighest,
                                              child: Icon(
                                                Icons.image_outlined,
                                                size: 24,
                                                color: cs
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.product.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'x${it.qty}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                  cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _vnd(it.unitPrice * it.qty),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionSpacing),

                        // ---- Tổng cộng ----
                        SectionCard(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tạm tính',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant),
                                  ),
                                  Text(
                                    _vnd(subtotal),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              if (cart.appliedVoucher != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Giảm (${cart.appliedVoucher!.code})',
                                      style: TextStyle(
                                          color: Colors.green.shade600),
                                    ),
                                    Text(
                                      '-${_vnd(discount)}',
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (coinsUsed > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Giảm bằng Xu',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant),
                                    ),
                                    Text(
                                      '-${_vnd(coinDiscount)}',
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Phí vận chuyển',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant),
                                  ),
                                  Text(
                                    shippingFee == 0
                                        ? 'Miễn phí'
                                        : _vnd(shippingFee),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: shippingFee == 0
                                          ? Colors.green
                                          : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Divider(
                                height: 20,
                                color: cs.outlineVariant,
                              ),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tổng cộng',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _vnd(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              if (rewardCoins > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.monetization_on_outlined,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Xu có thể nhận được',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                    cs.onSurfaceVariant,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Xu sẽ được cộng sau khi đơn giao thành công '
                                                      'và bạn hoàn tất đánh giá sản phẩm.',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                    cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '+$rewardCoins xu',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // ================== STICKY BOTTOM BAR ==================
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: pageBg.withOpacity(isDark ? 0.96 : 0.94),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 14,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      6,
                      horizontalPadding,
                      8 + media.padding.bottom,
                    ),
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(maxWidth: contentMaxWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: 'Nhấn ',
                              children: [
                                const TextSpan(
                                  text: '"Đặt hàng ngay" ',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const TextSpan(
                                  text:
                                  'đồng nghĩa với việc bạn đồng ý với ',
                                ),
                                TextSpan(
                                  text: 'Điều khoản mua hàng của CSES',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    color: cs.primary,
                                  ),
                                  recognizer: _termsRecognizer,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tổng cộng',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _vnd(total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  icon: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: cs.onPrimary,
                                  ),
                                  label: Text(
                                    _submitting
                                        ? 'Đang xử lý...'
                                        : 'Đặt hàng ngay',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _submitting
                                      ? null
                                      : () async {
                                    if (address == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Vui lòng chọn địa chỉ giao hàng.'),
                                        ),
                                      );
                                      return;
                                    }

                                    if (selectedItems.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Vui lòng chọn sản phẩm trong giỏ trước khi đặt.'),
                                        ),
                                      );
                                      return;
                                    }

                                    final uid = FirebaseAuth
                                        .instance.currentUser?.uid;
                                    if (uid == null) return;

                                    setState(() => _submitting = true);

                                    try {
                                      final orderId =
                                      await orderCtrl.checkout(
                                        uid,
                                        cart,
                                        shippingAddress: address.toMap(),
                                        note: _noteCtl.text,
                                        context: context,
                                        shippingMethodId:
                                        _selectedShippingMethod.id,
                                        shippingMethodName:
                                        _selectedShippingMethod.name,
                                        shippingMethodSubtitle:
                                        _selectedShippingMethod
                                            .subtitle,
                                        usedXu: coinsUsed,
                                        xuDiscount: coinDiscount,
                                        paymentMethodKey: paymentKey,
                                        paymentMethodName: paymentTitle,
                                      );

                                      if (!mounted) return;

                                      if (paymentMethod ==
                                          PaymentMethod.bankTransfer) {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          AppRoutes.paymentBankTransfer,
                                          arguments: {
                                            'orderId': orderId,
                                            'amount': total,
                                          },
                                        );
                                      } else if (paymentMethod ==
                                          PaymentMethod.momo) {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          AppRoutes.paymentMomo,
                                          arguments: {
                                            'orderId': orderId,
                                            'amount': total,
                                          },
                                        );
                                      } else {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          AppRoutes.orders,
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Lỗi khi đặt hàng: $e'),
                                        ),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(
                                                () => _submitting = false);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon tròn nền mềm, dùng lại nhiều chỗ
class RoundedIcon extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double size;

  const RoundedIcon({
    super.key,
    required this.icon,
    this.iconColor,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size + 18,
      height: size + 18,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size,
        color: iconColor ?? cs.primary,
      ),
    );
  }
}

/// Thẻ nền dùng lại cho các section – Apple style nhưng “premium” hơn
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SectionCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isCompact = w < 360;
        final isWide = w > 480;

        final radius = isCompact ? 16.0 : 20.0;
        final innerPadding =
            padding ?? EdgeInsets.all(isCompact ? 14 : 16);

        final borderGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
            cs.primary.withOpacity(0.25),
            cs.primary.withOpacity(0.05),
          ]
              : [
            cs.primary.withOpacity(0.18),
            cs.primary.withOpacity(0.02),
          ],
        );

        final cardBg = isDark
            ? const Color(0xFF1C1C1E)
            : Colors.white.withOpacity(0.96);

        return Container(
          decoration: BoxDecoration(
            gradient: isWide ? borderGradient : null,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: isDark
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: isCompact ? 14 : 18,
                offset: const Offset(0, 10),
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: isCompact ? 12 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(radius - 2),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(isDark ? 0.28 : 0.18),
              ),
            ),
            padding: innerPadding,
            child: child,
          ),
        );
      },
    );
  }
}

/// TextField “chuẩn theme”: border mảnh, nền mịn, giống iOS search
class ThemedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int? maxLines;
  final TextInputAction? textInputAction;

  const ThemedTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width >= 600;

    final radius = isTablet ? 16.0 : 14.0;
    final vPad = isTablet ? 14.0 : 12.0;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style:
      theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: cs.onSurfaceVariant.withOpacity(0.8),
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.9),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: vPad,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: cs.outlineVariant.withOpacity(0.7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: cs.outlineVariant.withOpacity(0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: cs.primary,
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

/// Định dạng tiền kiểu Apple Store (₫ 1,234,567)
String _vnd(num value) =>
    '₫${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    )}';

/// Card voucher dạng ticket, responsive theo chiều rộng
class _VoucherTile extends StatelessWidget {
  final String code;
  final String subtitle;
  final VoidCallback onTap;

  const _VoucherTile({
    required this.code,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 360;
        final isWide = width > 420;

        final radius = isCompact ? 16.0 : 20.0;
        final padding = EdgeInsets.all(isCompact ? 12 : 14);
        final ticketWidth =
        isCompact ? 64.0 : (isWide ? 80.0 : 72.0);
        final ticketHeight = isCompact ? 60.0 : 64.0;

        final discountText = subtitle.startsWith('Giảm ')
            ? subtitle.substring('Giảm '.length)
            : subtitle;

        return InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                if (theme.brightness == Brightness.light)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Ticket bên trái
                Container(
                  width: ticketWidth,
                  height: ticketHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.primary.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: isCompact ? 20 : 22,
                        color: cs.onPrimary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        discountText,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Nội dung bên phải
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shipping options kiểu Shopee
class ShippingMethodOption {
  final String id;
  final String name;
  final String subtitle;
  final String? note;

  const ShippingMethodOption({
    required this.id,
    required this.name,
    required this.subtitle,
    this.note,
  });
}

const List<ShippingMethodOption> kShippingOptions = [
  ShippingMethodOption(
    id: 'fast',
    name: 'Nhanh',
    subtitle: 'Nhận trong 1 - 2 ngày làm việc',
    note: 'Có thể nhận voucher nếu giao trễ.',
  ),
  ShippingMethodOption(
    id: 'economy',
    name: 'Tiết kiệm',
    subtitle: 'Nhận trong 3 - 5 ngày làm việc',
  ),
];
