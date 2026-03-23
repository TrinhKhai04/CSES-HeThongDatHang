import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/address_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/app_address.dart';

// 👇 Picker bản đồ free (Nominatim + OSM)
import 'address_map_picker.dart';

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  // ---------------------- Controllers & State ----------------------
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _line1Ctl = TextEditingController();
  final _wardCtl = TextEditingController();
  final _districtCtl = TextEditingController();
  final _provinceCtl = TextEditingController();

  bool _setDefault = false;
  AppAddress? _editing;

  // 🆕 Toạ độ lấy từ map (lưu cùng địa chỉ)
  double? _geoLat, _geoLng;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Nhận dữ liệu khi sửa
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final a = args?['address'] as AppAddress?;
    if (a != null && _editing == null) {
      _editing = a;
      _nameCtl.text = a.name;
      _phoneCtl.text = a.phone;
      _line1Ctl.text = a.line1;
      _wardCtl.text = a.ward;
      _districtCtl.text = a.district;
      _provinceCtl.text = a.province;
      _setDefault = a.isDefault;

      // 🆕 Nếu model có lat/lng thì prefill vào state (không bắt buộc)
      try {
        _geoLat = (a as dynamic).lat as double?;
        _geoLng = (a as dynamic).lng as double?;
      } catch (_) {
        // model cũ không có lat/lng cũng không sao
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _line1Ctl.dispose();
    _wardCtl.dispose();
    _districtCtl.dispose();
    _provinceCtl.dispose();
    super.dispose();
  }

  // ---------------------- MỞ MAP & ĐỔ VỀ FORM ----------------------
  Future<void> _pickOnMap() async {
    final res = await Navigator.push<AddressPickResult>(
      context,
      MaterialPageRoute(builder: (_) => const AddressMapPicker()),
    );
    if (res == null) return;

    setState(() {
      _line1Ctl.text = res.street.isNotEmpty ? res.street : res.full;
      _wardCtl.text = res.ward;
      _districtCtl.text = res.district;
      _provinceCtl.text = res.province;
      _geoLat = res.lat; // 🆕
      _geoLng = res.lng; // 🆕
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lấy địa chỉ & toạ độ từ bản đồ')),
    );
  }

  // ---------------------- LƯU ĐỊA CHỈ ----------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthController>().user?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa đăng nhập')),
      );
      return;
    }

    final ac = context.read<AddressController>();

    // 🆕 Nhúng toạ độ vào AppAddress (nếu model có lat/lng)
    AppAddress data = AppAddress(
      id: _editing?.id ?? '',
      name: _nameCtl.text.trim(),
      phone: _phoneCtl.text.trim(),
      line1: _line1Ctl.text.trim(),
      ward: _wardCtl.text.trim(),
      district: _districtCtl.text.trim(),
      province: _provinceCtl.text.trim(),
      isDefault: _editing?.isDefault ?? false,
      // Nếu model AppAddress có lat/lng, mở comment 2 dòng bên dưới:
      // lat: _geoLat,
      // lng: _geoLng,
    );

    // 🆕 Nếu model CHƯA có lat/lng: vẫn patch trực tiếp vào Firestore bằng merge
    final bool patchGeoAfterWrite = !_addressModelHasGeo();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      late String id;
      if (_editing == null) {
        id = await ac.addAddressReturnId(uid, data);
        if (_setDefault) await ac.setDefault(uid, id);
      } else {
        id = _editing!.id;
        await ac.updateAddress(uid, data.copyWith(id: id));
        if (_setDefault && !_editing!.isDefault) {
          await ac.setDefault(uid, id);
        }
      }

      // 🆕 Bổ sung lat/lng nếu model chưa có field (ghi merge, không phá dữ liệu cũ)
      if (patchGeoAfterWrite && (_geoLat != null && _geoLng != null)) {
        await ac.patchExtra(uid, id, {
          'lat': _geoLat,
          'lng': _geoLng,
        });
      }

      if (mounted) {
        Navigator.pop(context); // close dialog
        Navigator.pop(context); // back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editing == null ? 'Đã thêm địa chỉ' : 'Đã lưu địa chỉ'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  // 🆕 Thử phát hiện nhanh model có field lat/lng không (tránh vỡ build)
  bool _addressModelHasGeo() {
    try {
      // ignore: unnecessary_cast
      final _ = (AppAddress as dynamic);
      return _editing == null
          ? false
          : (((_editing as dynamic).lat) != null ||
          ((_editing as dynamic).lng) != null);
    } catch (_) {
      return false;
    }
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = _editing != null;
    final hasGeo = _geoLat != null && _geoLng != null; // 🆕

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa địa chỉ' : 'Thêm địa chỉ'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: false,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Lưu'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // === Nhóm 1: Thông tin liên hệ
            const _SectionHeader('Thông tin liên hệ'),
            _GroupCard(
              children: [
                const SizedBox(height: 8),
                _Field(
                  controller: _nameCtl,
                  label: 'Họ & tên',
                  icon: Icons.person_outline,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _phoneCtl,
                  label: 'Số điện thoại',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Nhập số điện thoại';
                    if (t.length < 9) return 'Số điện thoại không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),

            // === Nhóm 2: Địa chỉ giao hàng
            const _SectionHeader('Địa chỉ giao hàng'),
            _GroupCard(
              children: [
                // Nút chọn bản đồ (card đẹp hơn)
                InkWell(
                  onTap: _pickOnMap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.primary.withOpacity(.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 20,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasGeo
                                      ? 'Đã chọn vị trí trên bản đồ'
                                      : 'Chọn trên bản đồ & tự điền',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasGeo
                                      ? 'Lat: ${_geoLat!.toStringAsFixed(5)}, Lng: ${_geoLng!.toStringAsFixed(5)}'
                                      : 'Bản đồ Nominatim + OpenStreetMap (khuyên dùng để tránh nhập sai).',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (hasGeo)
                            IconButton(
                              tooltip: 'Xoá toạ độ',
                              onPressed: () => setState(() {
                                _geoLat = null;
                                _geoLng = null;
                              }),
                              icon: Icon(
                                Icons.close_rounded,
                                color: cs.onSurfaceVariant,
                                size: 18,
                              ),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _Field(
                  controller: _line1Ctl,
                  label: 'Số nhà, đường',
                  icon: Icons.home_outlined,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập địa chỉ' : null,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _wardCtl,
                  label: 'Phường/Xã',
                  icon: Icons.location_city_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nhập phường/xã'
                      : null,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _districtCtl,
                  label: 'Quận/Huyện',
                  icon: Icons.apartment_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nhập quận/huyện'
                      : null,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _provinceCtl,
                  label: 'Tỉnh/TP',
                  icon: Icons.public_outlined,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập tỉnh/TP' : null,
                ),
                const SizedBox(height: 10),
              ],
            ),

            // === Nhóm 3: Tuỳ chọn
            const _SectionHeader('Tuỳ chọn'),
            _GroupCard(
              children: [
                Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return SwitchListTile.adaptive(
                      value: _setDefault,
                      onChanged: (v) => setState(() => _setDefault = v),
                      title: Text(
                        'Đặt làm mặc định',
                        style: TextStyle(color: cs.onSurface),
                      ),
                      secondary: Icon(
                        _setDefault
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _setDefault ? cs.primary : cs.onSurfaceVariant,
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- COMPONENTS PHỤ ----------------------

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: .6,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(.7),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            spreadRadius: -6,
            offset: const Offset(0, 6),
            color: cs.brightness == Brightness.dark
                ? Colors.transparent
                : const Color(0x1F000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.outlineVariant),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        autocorrect: false,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.label,
          hintStyle: TextStyle(color: cs.onSurfaceVariant),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: Icon(
            widget.icon,
            size: 22,
            color: cs.onSurfaceVariant,
          ),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
            onPressed: () => widget.controller.clear(),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            tooltip: 'Xoá',
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: cs.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}
