import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PolicyTermsScreen extends StatefulWidget {
  const PolicyTermsScreen({super.key});

  @override
  State<PolicyTermsScreen> createState() => _PolicyTermsScreenState();
}

class _PolicyTermsScreenState extends State<PolicyTermsScreen> {
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Collection Firestore (không đổi)
    final col = FirebaseFirestore.instance.collection('policies');

    // Màu nền động theo iOS
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final shortestSide = mq.size.shortestSide;
    final bool isTablet = shortestSide >= 600;
    final double contentMaxWidth = isTablet ? 640 : width;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Chính sách & Điều khoản',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              children: [
                // 🔍 Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: CupertinoSearchTextField(
                    controller: _searchCtl,
                    placeholder: 'Tìm kiếm nội dung...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                // dòng mô tả nhỏ
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Các chính sách có thể được cập nhật định kỳ. '
                          'Vui lòng đọc kỹ để hiểu rõ quyền lợi của bạn.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: secondary,
                      ),
                    ),
                  ),
                ),

                // 🔄 Danh sách
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: col
                        .where('isActive', isEqualTo: true)
                        .orderBy('updatedAt', descending: false)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      if (snap.hasError) {
                        return _errorView(
                          context,
                          snap.error.toString(),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _emptyView(
                          context,
                          'Hiện chưa có chính sách nào được hiển thị.',
                        );
                      }

                      final filtered = docs.where((d) {
                        if (_query.isEmpty) return true;
                        final q = _query.toLowerCase();
                        final t = (d['title'] ?? '').toString().toLowerCase();
                        final c = (d['content'] ?? '').toString().toLowerCase();
                        return t.contains(q) || c.contains(q);
                      }).toList();

                      if (filtered.isEmpty) {
                        return _emptyView(
                          context,
                          'Không tìm thấy nội dung phù hợp.',
                        );
                      }

                      // Có kết quả -> show header + list
                      return Column(
                        children: [
                          if (_query.trim().isNotEmpty)
                            _resultHeader(context, filtered.length),
                          Expanded(
                            child: CupertinoScrollbar(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 4, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final doc = filtered[i];
                                  final item = doc.data();
                                  final rawTitle =
                                  (item['title'] ?? 'Không có tiêu đề')
                                      .toString()
                                      .trim();
                                  final content =
                                  (item['content'] ?? '').toString().trim();

                                  // Bỏ số thứ tự trong title (nếu có), dùng index list thay
                                  final title = rawTitle.replaceFirst(
                                    RegExp(r'^\d+\.\s*'),
                                    '',
                                  ); // "1. Giới thiệu" -> "Giới thiệu"

                                  final index = i + 1;

                                  // category & updatedAt (optional)
                                  final category =
                                  (item['category'] ?? '').toString().trim();
                                  DateTime? updatedAt;
                                  final rawUpdated = item['updatedAt'];
                                  if (rawUpdated is Timestamp) {
                                    updatedAt = rawUpdated.toDate();
                                  } else if (rawUpdated is DateTime) {
                                    updatedAt = rawUpdated;
                                  }

                                  return GestureDetector(
                                    onTap: () => _openDetailPage(
                                      context,
                                      rawTitle,
                                      content,
                                      category:
                                      category.isEmpty ? null : category,
                                      updatedAt: updatedAt,
                                    ),
                                    child: _PolicyCard(
                                      index: index,
                                      title: title,
                                      content: content,
                                      query: _query,
                                      category:
                                      category.isEmpty ? null : category,
                                      updatedAt: updatedAt,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // == Views phụ ====================================================

  Widget _errorView(BuildContext context, String msg) {
    final destructive =
    CupertinoColors.destructiveRed.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        '⚠️ Lỗi khi tải dữ liệu:\n$msg',
        textAlign: TextAlign.center,
        style: TextStyle(color: destructive, fontSize: 15),
      ),
    );
  }

  Widget _emptyView(BuildContext context, String msg) {
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: secondary, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _resultHeader(BuildContext context, int count) {
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Tìm thấy $count mục',
            style: TextStyle(
              fontSize: 12,
              color: label.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _openDetailPage(
      BuildContext context,
      String title,
      String content, {
        String? category,
        DateTime? updatedAt,
      }) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _PolicyDetailPage(
          title: title,
          content: content,
          category: category,
          updatedAt: updatedAt,
        ),
      ),
    );
  }
}

/// Card từng policy: số thứ tự + highlight search + meta
class _PolicyCard extends StatelessWidget {
  final int index;
  final String title;
  final String content;
  final String query;
  final String? category;
  final DateTime? updatedAt;

  const _PolicyCard({
    required this.index,
    required this.title,
    required this.content,
    required this.query,
    this.category,
    this.updatedAt,
  });

  String? get _formattedDate {
    if (updatedAt == null) return null;
    return DateFormat('dd/MM/yyyy').format(updatedAt!);
  }

  @override
  Widget build(BuildContext context) {
    final cardBg =
    CupertinoColors.systemBackground.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final sep = CupertinoColors.separator.resolveFrom(context);
    final isLight =
        CupertinoTheme.of(context).brightness == Brightness.light;

    // Gradient viền nhẹ như iOS card
    final borderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isLight
          ? [
        CupertinoColors.systemBlue
            .resolveFrom(context)
            .withOpacity(0.18),
        CupertinoColors.systemBlue
            .resolveFrom(context)
            .withOpacity(0.04),
      ]
          : [
        CupertinoColors.systemGrey
            .resolveFrom(context)
            .withOpacity(0.35),
        CupertinoColors.systemGrey2
            .resolveFrom(context)
            .withOpacity(0.10),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: borderGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (isLight)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: sep.withOpacity(0.35),
            width: 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔢 Số thứ tự
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CupertinoColors.systemBlue
                          .resolveFrom(context)
                          .withOpacity(0.9),
                      CupertinoColors.systemIndigo
                          .resolveFrom(context)
                          .withOpacity(0.9),
                    ],
                  ),
                  boxShadow: [
                    if (isLight)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),

              // 📝 Tiêu đề + meta + mô tả
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(
                      text: title,
                      query: query,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: label,
                        letterSpacing: 0.1,
                        decoration: TextDecoration.none,
                      ),
                      highlightStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: CupertinoColors.systemBlue
                            .resolveFrom(context),
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),

                    // meta: category + date
                    if ((category != null && category!.isNotEmpty) ||
                        _formattedDate != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (category != null && category!.isNotEmpty)
                            _metaChip(
                              context,
                              category!,
                              icon: CupertinoIcons.tag_solid,
                            ),
                          if (_formattedDate != null)
                            _metaChip(
                              context,
                              'Cập nhật: $_formattedDate',
                              icon: CupertinoIcons.time_solid,
                            ),
                        ],
                      ),
                    if ((category != null && category!.isNotEmpty) ||
                        _formattedDate != null)
                      const SizedBox(height: 4),

                    _buildHighlightedText(
                      text: content,
                      query: query,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: secondary,
                        decoration: TextDecoration.none,
                      ),
                      highlightStyle: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: CupertinoColors.systemBlue
                            .resolveFrom(context),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // ➡️ Chevron
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip meta (category, cập nhật...)
  Widget _metaChip(
      BuildContext context,
      String text, {
        required IconData icon,
      }) {
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoColors.systemGrey5.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final blue = CupertinoColors.systemBlue.resolveFrom(context);

    final isUpdateChip = text.startsWith('Cập nhật');

    // Nếu là chip "Cập nhật: 20/11/2025" thì làm style đặc biệt
    if (isUpdateChip) {
      // Tách phần ngày ra (sau dấu :)
      final parts = text.split(':');
      final dateStr =
      parts.length > 1 ? parts.sublist(1).join(':').trim() : text;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: blue.withOpacity(0.4),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vòng tròn icon đồng hồ
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withOpacity(0.15),
              ),
              child: Icon(
                icon,
                size: 10,
                color: blue,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Cập nhật',
              style: TextStyle(
                fontSize: 11,
                color: blue.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
            if (dateStr.isNotEmpty) ...[
              Text(
                ' • ',
                style: TextStyle(
                  fontSize: 11,
                  color: blue.withOpacity(0.7),
                  height: 1.1,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Các chip khác (category,...) giữ style nhẹ
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: secondary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Highlight query (case-insensitive) trong text
  static Widget _buildHighlightedText({
    required String text,
    required String query,
    required TextStyle style,
    required TextStyle highlightStyle,
    int? maxLines,
  }) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        // Phần còn lại
        spans.add(
          TextSpan(text: text.substring(start), style: style),
        );
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: style,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: highlightStyle,
        ),
      );

      start = index + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Trang chi tiết policy (đọc full nội dung)
class _PolicyDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final String? category;
  final DateTime? updatedAt;

  const _PolicyDetailPage({
    required this.title,
    required this.content,
    this.category,
    this.updatedAt,
  });

  String? get _formattedDate {
    if (updatedAt == null) return null;
    return DateFormat('dd/MM/yyyy').format(updatedAt!);
  }

  @override
  Widget build(BuildContext context) {
    // Màu kiểu iOS / Apple Store
    final bg =
    CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final cardBg = CupertinoColors.systemBackground.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final sep = CupertinoColors.separator.resolveFrom(context);
    final isLight =
        CupertinoTheme.of(context).brightness == Brightness.light;

    // Bỏ số thứ tự ở đầu nếu có (ví dụ "1. Điều khoản sử dụng")
    final cleanTitle = title.replaceFirst(RegExp(r'^\d+\.\s*'), '');

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final shortestSide = mq.size.shortestSide;
    final bool isTablet = shortestSide >= 600;
    final double contentMaxWidth = isTablet ? 640 : width;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          cleanTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        previousPageTitle: 'Chính sách',
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Tag nhỏ phía trên giống Apple Store section
                    _sectionTag(
                      context,
                      'Thông tin chính sách',
                      icon: CupertinoIcons.info,
                    ),
                    const SizedBox(height: 10),

                    // Header card: tiêu đề + meta (có accent bar phía trên)
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sep.withOpacity(isLight ? 0.35 : 0.6),
                          width: 0.6,
                        ),
                        boxShadow: [
                          if (isLight)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                        ],
                      ),
                      padding:
                      const EdgeInsets.fromLTRB(14, 12, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Accent bar mảnh phía trên (Apple style)
                          Container(
                            width: 34,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  CupertinoColors.systemBlue
                                      .resolveFrom(context)
                                      .withOpacity(0.95),
                                  CupertinoColors.systemTeal
                                      .resolveFrom(context)
                                      .withOpacity(0.95),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tiêu đề lớn
                          Text(
                            cleanTitle,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: label,
                              height: 1.25,
                              letterSpacing: 0.2,
                              decoration: TextDecoration.none,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sub meta: category + ngày cập nhật
                          if ((category != null &&
                              category!.isNotEmpty) ||
                              _formattedDate != null)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (category != null &&
                                    category!.isNotEmpty)
                                  _detailChip(
                                    context,
                                    category!,
                                    icon: CupertinoIcons.tag_solid,
                                  ),
                                if (_formattedDate != null)
                                  _detailChip(
                                    context,
                                    'Cập nhật: $_formattedDate',
                                    icon: CupertinoIcons.time_solid,
                                  ),
                              ],
                            )
                          else
                            Text(
                              'Chính sách áp dụng cho dịch vụ CSES',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: secondary,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ─── Tag "Nội dung chi tiết"
                    _sectionTag(
                      context,
                      'Nội dung chi tiết',
                      icon: CupertinoIcons.doc_text,
                    ),
                    const SizedBox(height: 10),

                    // Body content card
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sep.withOpacity(0.25),
                          width: 0.5,
                        ),
                      ),
                      padding:
                      const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      child: _buildContentParagraphs(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tag nhỏ cho tiêu đề section (pill + icon)
  Widget _sectionTag(
      BuildContext context,
      String text, {
        required IconData icon,
      }) {
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoColors.systemGrey5.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: secondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: secondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Tách content thành nhiều đoạn theo \n\n, tự nhận diện heading "1. ..."
  Widget _buildContentParagraphs(BuildContext context) {
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final blue = CupertinoColors.systemBlue.resolveFrom(context);

    final parts = content
        .split('\n\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return Text(
        content,
        textAlign: TextAlign.left,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: label,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            SizedBox(
              height:
              RegExp(r'^\d+\.\s+').hasMatch(parts[i]) ? 16 : 8,
            ),
          _buildParagraph(
            parts[i],
            label: label,
            secondary: secondary,
            blue: blue,
          ),
        ],
      ],
    );
  }

  /// Render từng đoạn: nếu là "1. Tiêu đề" thì style như heading
  Widget _buildParagraph(
      String text, {
        required Color label,
        required Color secondary,
        required Color blue,
      }) {
    final headingMatch = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(text);

    // Đoạn heading (ví dụ: "1. Phạm vi áp dụng")
    if (headingMatch != null) {
      final number = headingMatch.group(1)!;
      final title = headingMatch.group(2)!;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill số thứ tự
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: blue.withOpacity(0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: blue,
              ),
            ),
          ),
          // Tiêu đề section
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: label,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    // Đoạn nội dung thường
    return Text(
      text,
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.55,
        color: label,
        decoration: TextDecoration.none,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  /// Chip meta (category / cập nhật)
  Widget _detailChip(
      BuildContext context,
      String text, {
        required IconData icon,
      }) {
    final secondary =
    CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoColors.systemGrey5.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final blue = CupertinoColors.systemBlue.resolveFrom(context);

    final isUpdateChip = text.startsWith('Cập nhật');

    if (isUpdateChip) {
      final parts = text.split(':');
      final dateStr =
      parts.length > 1 ? parts.sublist(1).join(':').trim() : text;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: blue.withOpacity(0.4),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withOpacity(0.15),
              ),
              child: Icon(
                icon,
                size: 11,
                color: blue,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Cập nhật',
              style: TextStyle(
                fontSize: 11.5,
                color: blue.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
            if (dateStr.isNotEmpty) ...[
              Text(
                ' • ',
                style: TextStyle(
                  fontSize: 11.5,
                  color: blue.withOpacity(0.7),
                  height: 1.1,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11.5,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Chip thường (category)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: secondary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
