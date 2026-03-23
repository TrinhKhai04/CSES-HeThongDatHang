import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class RevenueDetailScreen extends StatelessWidget {
  final double totalRevenue;
  final double growthPercent;
  final Map<String, double> dailyRevenue; // key: 'dd/MM'

  const RevenueDetailScreen({
    super.key,
    required this.totalRevenue,
    required this.growthPercent,
    required this.dailyRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final growthUp = growthPercent >= 0;
    final growthColor = growthUp ? cs.tertiary : cs.error;

    // sắp xếp theo ngày tăng dần
    final entries = dailyRevenue.entries.toList()
      ..sort((a, b) => _parseKey(a.key).compareTo(_parseKey(b.key)));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Chi tiết doanh thu',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // ===== Tổng doanh thu + tăng trưởng =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng doanh thu',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: .64),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(totalRevenue),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      growthUp
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      color: growthColor,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${growthPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: growthColor,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      growthUp
                          ? 'tăng so với kỳ trước'
                          : 'giảm so với kỳ trước',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: .64),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ===== Biểu đồ doanh thu theo ngày =====
          Text(
            '📅 Doanh thu theo ngày',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: _cardDeco(context),
            child: _buildRevenueLineChart(context, entries),
          ),

          const SizedBox(height: 12),

          // ===== Danh sách đối chiếu từng ngày =====
          ...entries.map(
                (e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: _cardDeco(context, radius: 14, blur: 6, y: 2),
              child: ListTile(
                dense: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  CupertinoIcons.calendar,
                  size: 20,
                  color: cs.primary,
                ),
                title: Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                    color: cs.onSurface,
                  ),
                ),
                trailing: Text(
                  currency.format(e.value),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              'Vuốt sang phải hoặc bấm ← để quay lại',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: .45),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Biểu đồ đường doanh thu theo ngày
  // ---------------------------------------------------------------------------
  Widget _buildRevenueLineChart(
      BuildContext context,
      List<MapEntry<String, double>> entries,
      ) {
    final cs = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Chưa có dữ liệu doanh thu',
            style: TextStyle(color: cs.onSurface.withValues(alpha: .64)),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    final labels = <String>[];
    double minY = double.infinity;
    double maxY = 0;

    for (var i = 0; i < entries.length; i++) {
      final y = entries[i].value;
      spots.add(FlSpot(i.toDouble(), y));
      labels.add(entries[i].key); // 'dd/MM'
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final dy = (maxY - minY).abs();
    // padTop mềm hơn: nếu dy = 0 thì lấy 30% maxY (hoặc 1 nếu maxY = 0)
    final padTop = dy == 0
        ? (maxY == 0 ? 1 : maxY * 0.3)
        : dy * 0.15;
    final padBottom = dy == 0 ? 0 : dy * 0.05;

    final axisColor = cs.onSurface.withValues(alpha: .22);
    final labelColor = cs.onSurface.withValues(alpha: .64);
    final lineColor = cs.primary;

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: (minY - padBottom).clamp(0, double.infinity),
          maxY: maxY + padTop,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
            dy == 0 ? 1 : (maxY / 4).ceilToDouble(),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: axisColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (spots.length / 6).clamp(1, 6).toDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.round();
                  if (idx < 0 || idx >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[idx],
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval:
                dy == 0 ? 1 : (maxY / 4).ceilToDouble(),
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _shortMoney(value),
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => touched.map((t) {
                final idx = t.x.round();
                final label =
                (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                return LineTooltipItem(
                  '$label\n${_money(t.y)}',
                  TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                );
              }).toList(),
              // Nếu bản fl_chart hỗ trợ: có thể thêm getTooltipColor:
              // getTooltipColor: (_) => cs.surfaceContainerHighest,
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: lineColor,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: .20),
                    lineColor.withValues(alpha: .02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: axisColor),
              bottom: BorderSide(color: axisColor),
              right: const BorderSide(color: Colors.transparent),
              top: const BorderSide(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static BoxDecoration _cardDeco(
      BuildContext context, {
        double radius = 18,
        double blur = 8,
        double y = 3,
      }) {
    final cs = Theme.of(context).colorScheme;
    final shadow = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: .30)
        : Colors.black.withValues(alpha: .05);

    return BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: shadow,
          blurRadius: blur,
          offset: Offset(0, y),
        ),
      ],
      border: Border.all(
        color: cs.outlineVariant.withValues(alpha: .4),
        width: 0.6,
      ),
    );
  }

  DateTime _parseKey(String k) {
    try {
      final p = k.split('/');
      final d = int.parse(p[0]);
      final m = int.parse(p[1]);
      final now = DateTime.now();
      return DateTime(now.year, m, d);
    } catch (_) {
      return DateTime.now();
    }
  }

  static String _shortMoney(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  static String _money(num v) {
    final f = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return f.format(v);
  }
}
