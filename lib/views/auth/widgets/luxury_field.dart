// lib/views/auth/widgets/luxury_field.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class LuxuryLabeledField extends StatefulWidget {
  const LuxuryLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.enableObscureToggle = false,
    this.validator,
    this.prefixIcon,
    this.scrollPadding = const EdgeInsets.only(bottom: 160),
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onEditingComplete,
    this.focusNode,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  final bool obscureText;
  final bool enableObscureToggle;
  final String? Function(String?)? validator;

  final Widget? prefixIcon;
  final EdgeInsets scrollPadding;

  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final FocusNode? focusNode;

  @override
  State<LuxuryLabeledField> createState() => _LuxuryLabeledFieldState();
}

class _LuxuryLabeledFieldState extends State<LuxuryLabeledField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Màu theo theme: đảm bảo auto đổi Light/Dark
    final labelColor   = isDark ? Colors.white70 : theme.textTheme.titleSmall?.color ?? Colors.black87;
    final fieldFgColor = theme.colorScheme.onSurface;           // màu chữ trong TextField
    final hintColor    = isDark ? Colors.white54 : const Color(0xFF7A7F87);
    final fillColor    = theme.inputDecorationTheme.fillColor   // ưu tiên theo theme nếu set
        ?? (isDark ? Colors.white.withOpacity(0.08) : Colors.white);
    final borderColor  = theme.inputDecorationTheme.enabledBorder is OutlineInputBorder
        ? (theme.inputDecorationTheme.enabledBorder as OutlineInputBorder).borderSide.color
        : (isDark ? const Color(0x40FFFFFF) : const Color(0xFFE6E8EC));

    final suffix = widget.enableObscureToggle
        ? IconButton(
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
    )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nhãn bên trên kiểu boutique
        Text(
          widget.label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: labelColor, // dùng màu theo theme
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          obscureText: _obscure,
          validator: widget.validator,
          scrollPadding: widget.scrollPadding,

          // ✅ Không dùng const + không phụ thuộc AppTheme.charcoal
          style: TextStyle(color: fieldFgColor),
          cursorColor: AppTheme.brand, // xanh Apple

          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: hintColor),

            filled: true,
            fillColor: fillColor, // nền theo theme

            prefixIcon: widget.prefixIcon,
            suffixIcon: suffix,

            // Đồng bộ border theo theme
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.brand, width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
        ),
      ],
    );
  }
}
