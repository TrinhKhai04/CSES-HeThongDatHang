import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Hiển thị version app dạng pill: "v1.2.0 (build 10)"
/// Dùng được ở mọi nơi: Home, Account, Settings, Policy...
class AppVersionBadge extends StatefulWidget {
  final bool compact; // true: chỉ hiện v1.2.0, false: kèm build

  const AppVersionBadge({super.key, this.compact = false});

  @override
  State<AppVersionBadge> createState() => _AppVersionBadgeState();
}

class _AppVersionBadgeState extends State<AppVersionBadge> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version; // lấy từ pubspec.yaml
      final build = info.buildNumber;
      if (mounted) {
        setState(() {
          _version = widget.compact ? 'v$v' : 'v$v ($build)';
        });
      }
    } catch (_) {
      // lỗi thì thôi, không hiện gì
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_version == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cs.primary.withOpacity(0.3),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: cs.primary,
          ),
          const SizedBox(width: 6),
          Text(
            _version!,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.primary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
