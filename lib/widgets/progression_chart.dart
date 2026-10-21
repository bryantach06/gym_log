import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/session_exercise.dart';
import '../blocs/exercise_detail/exercise_detail_cubit.dart';
import '../theme/app_theme.dart';
import '../utils/metrics_calculator.dart';
import '../utils/unit_converter.dart';

class ProgressionChart extends StatelessWidget {
  /// History entries to plot, oldest-first.
  final List<SessionExercise> history;

  /// Session date for each entry in [history], same order.
  final List<DateTime> dates;

  final ProgressionMetric metric;
  final bool useLbs;

  const ProgressionChart({
    super.key,
    required this.history,
    required this.dates,
    required this.metric,
    this.useLbs = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spots = _buildSpots();
    if (spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 36, color: scheme.outline),
            const SizedBox(height: 8),
            Text('No data yet', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    // X-axis: days since epoch.
    final minX = spots.first.x;
    final maxX = spots.last.x;
    final xRange = maxX - minX;

    // Choose a sensible label interval based on the date span.
    final double labelInterval;
    final DateFormat dateFmt;
    if (xRange <= 60) {
      labelInterval = 7;
      dateFmt = DateFormat('MMM d');
    } else if (xRange <= 365) {
      labelInterval = 30;
      dateFmt = DateFormat('MMM');
    } else {
      labelInterval = 90;
      dateFmt = DateFormat('MMM yy');
    }

    // Pad the Y range so the line doesn't hug the edges.
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() < 1 ? (maxY.abs() * 0.1 + 1) : (maxY - minY) * 0.15;

    final axisStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 10.5);
    final line = scheme.primary;
    final unit = metric == ProgressionMetric.bestReps ? 'reps' : unitLabel(useLbs);

    return LineChart(
      LineChartData(
        // A single point needs some width to be drawn.
        minX: xRange == 0 ? minX - 1 : minX,
        maxX: xRange == 0 ? maxX + 1 : maxX,
        minY: (minY - pad).clamp(0, double.infinity),
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (val, meta) {
                if (val == meta.min || val == meta.max) return const SizedBox.shrink();
                return Text(val.toStringAsFixed(0), style: axisStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: xRange > 0,
              reservedSize: 26,
              interval: labelInterval,
              getTitlesWidget: (val, meta) {
                if (val == meta.min || val == meta.max) return const SizedBox.shrink();
                final date = DateTime.fromMillisecondsSinceEpoch(
                  (val * Duration.millisecondsPerDay).round(),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dateFmt.format(date), style: axisStyle),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            barWidth: 3,
            color: line,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                radius: i == spots.length - 1 ? 5 : 3,
                color: line,
                strokeWidth: 2,
                strokeColor: scheme.surfaceContainer,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final date = DateTime.fromMillisecondsSinceEpoch(
                (s.x * Duration.millisecondsPerDay).round(),
              );
              return LineTooltipItem(
                '${s.y.toStringAsFixed(s.y % 1 == 0 ? 0 : 1)} $unit\n',
                AppTheme.number(context, size: 16, color: scheme.onInverseSurface),
                children: [
                  TextSpan(
                    text: DateFormat('MMM d, y').format(date),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      if (i >= dates.length) break;
      final val = _metricValue(history[i]);
      if (val <= 0) continue;
      // X = days since epoch (avoids large millisecond numbers in fl_chart).
      final xDays = dates[i].millisecondsSinceEpoch / Duration.millisecondsPerDay;
      // Rep counts are unitless; only weight metrics get converted.
      final y = metric == ProgressionMetric.bestReps ? val : toDisplayWeight(val, useLbs);
      spots.add(FlSpot(xDays, y));
    }
    return spots;
  }

  double _metricValue(SessionExercise ex) {
    final working = workingSets(ex.sets);
    switch (metric) {
      case ProgressionMetric.topSetWeight:
        return topSetWeight(working);
      case ProgressionMetric.estimated1RM:
        return best1RMFromSets(working);
      case ProgressionMetric.sessionVolume:
        return totalVolume(working);
      case ProgressionMetric.bestReps:
        return bestRepsAtWeight(working, topSetWeight(working)).toDouble();
    }
  }
}
