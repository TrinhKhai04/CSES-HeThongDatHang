import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/repositories/shipping_config_repository.dart';
import '../../../controllers/order_controller.dart' show ShippingConfig;

class AdminShippingConfigScreen extends StatefulWidget {
  const AdminShippingConfigScreen({super.key});

  @override
  State<AdminShippingConfigScreen> createState() =>
      _AdminShippingConfigScreenState();
}

class _AdminShippingConfigScreenState
    extends State<AdminShippingConfigScreen> {
  final _repo = ShippingConfigRepository();

  final _innerMaxKmCtl = TextEditingController();
  final _nearOuterMaxKmCtl = TextEditingController();
  final _farOuterMaxKmCtl = TextEditingController();
  final _interNearMaxKmCtl = TextEditingController();

  final _feeInnerCtl = TextEditingController();
  final _feeNearOuterCtl = TextEditingController();
  final _feeFarOuterCtl = TextEditingController();
  final _feeInterNearCtl = TextEditingController();
  final _feeInterFarCtl = TextEditingController();

  final _freeShipThresholdCtl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await _repo.getConfig();

      _innerMaxKmCtl.text = cfg.innerMaxKm.toStringAsFixed(0);
      _nearOuterMaxKmCtl.text = cfg.nearOuterMaxKm.toStringAsFixed(0);
      _farOuterMaxKmCtl.text = cfg.farOuterMaxKm.toStringAsFixed(0);
      _interNearMaxKmCtl.text = cfg.interNearMaxKm.toStringAsFixed(0);

      _feeInnerCtl.text = cfg.feeInner.toStringAsFixed(0);
      _feeNearOuterCtl.text = cfg.feeNearOuter.toStringAsFixed(0);
      _feeFarOuterCtl.text = cfg.feeFarOuter.toStringAsFixed(0);
      _feeInterNearCtl.text = cfg.feeInterNear.toStringAsFixed(0);
      _feeInterFarCtl.text = cfg.feeInterFar.toStringAsFixed(0);

      _freeShipThresholdCtl.text =
          cfg.freeShipThreshold.toStringAsFixed(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải cấu hình: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _parseDouble(TextEditingController ctl, double fallback) {
    final t = ctl.text.replaceAll(',', '').trim();
    if (t.isEmpty) return fallback;
    return double.tryParse(t) ?? fallback;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cfg = ShippingConfig(
        innerMaxKm: _parseDouble(_innerMaxKmCtl, 5),
        nearOuterMaxKm: _parseDouble(_nearOuterMaxKmCtl, 20),
        farOuterMaxKm: _parseDouble(_farOuterMaxKmCtl, 60),
        interNearMaxKm: _parseDouble(_interNearMaxKmCtl, 300),
        feeInner: _parseDouble(_feeInnerCtl, 20000),
        feeNearOuter: _parseDouble(_feeNearOuterCtl, 30000),
        feeFarOuter: _parseDouble(_feeFarOuterCtl, 40000),
        feeInterNear: _parseDouble(_feeInterNearCtl, 50000),
        feeInterFar: _parseDouble(_feeInterFarCtl, 70000),
        freeShipThreshold: _parseDouble(_freeShipThresholdCtl, 0),
      );

      await _repo.saveConfig(cfg);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cấu hình phí vận chuyển.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu cấu hình: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _innerMaxKmCtl.dispose();
    _nearOuterMaxKmCtl.dispose();
    _farOuterMaxKmCtl.dispose();
    _interNearMaxKmCtl.dispose();

    _feeInnerCtl.dispose();
    _feeNearOuterCtl.dispose();
    _feeFarOuterCtl.dispose();
    _feeInterNearCtl.dispose();
    _feeInterFarCtl.dispose();

    _freeShipThresholdCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceVariant.withOpacity(0.25),
      appBar: AppBar(
        title: const Text('Cấu hình phí vận chuyển'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- CARD KHOẢNG CÁCH ---
          _sectionCard(
            icon: Icons.social_distance,
            title: 'Khoảng cách (km)',
            subtitle: 'Dùng để phân tầng nội thành / ngoại thành / liên tỉnh',
            children: [
              _rowField(
                label: 'Nội thành (≤ innerMaxKm)',
                controller: _innerMaxKmCtl,
                suffix: 'km',
              ),
              _rowField(
                label: 'Ngoại thành gần (≤ nearOuterMaxKm)',
                controller: _nearOuterMaxKmCtl,
                suffix: 'km',
              ),
              _rowField(
                label: 'Ngoại thành xa / cùng tỉnh (≤ farOuterMaxKm)',
                controller: _farOuterMaxKmCtl,
                suffix: 'km',
              ),
              _rowField(
                label: 'Liên tỉnh gần (≤ interNearMaxKm)',
                controller: _interNearMaxKmCtl,
                suffix: 'km',
              ),
            ],
          ),

          // --- CARD GIÁ ---
          _sectionCard(
            icon: Icons.payments_outlined,
            title: 'Giá (đồng)',
            subtitle: 'Áp dụng lần lượt theo khoảng cách phía trên',
            children: [
              _rowField(
                label: 'Nội thành',
                controller: _feeInnerCtl,
                suffix: '₫',
              ),
              _rowField(
                label: 'Ngoại thành gần',
                controller: _feeNearOuterCtl,
                suffix: '₫',
              ),
              _rowField(
                label: 'Ngoại thành xa / cùng tỉnh',
                controller: _feeFarOuterCtl,
                suffix: '₫',
              ),
              _rowField(
                label: 'Liên tỉnh gần',
                controller: _feeInterNearCtl,
                suffix: '₫',
              ),
              _rowField(
                label: 'Liên tỉnh rất xa',
                controller: _feeInterFarCtl,
                suffix: '₫',
              ),
            ],
          ),

          // --- CARD FREE SHIP ---
          _sectionCard(
            icon: Icons.local_mall_outlined,
            title: 'Miễn phí ship theo giá trị đơn',
            subtitle: 'Đơn có tổng tiền >= ngưỡng này sẽ free ship. 0 = tắt.',
            children: [
              _rowField(
                label: 'Ngưỡng free ship',
                controller: _freeShipThresholdCtl,
                suffix: '₫',
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu cấu hình'),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // CARD SECTION
  // ────────────────────────────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon nằm trong “pill”
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 1 dòng label (trên) + ô nhập (dưới) – full width, không overflow
  // ────────────────────────────────────────────────────────────────
  Widget _rowField({
    required String label,
    required TextEditingController controller,
    String? suffix,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.3),
              suffixText: suffix,
            ),
          ),
        ],
      ),
    );
  }
}
