import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Label over a large number with an optional unit, e.g. "VOLUME / 12.4k kg".
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? accent;
  final double valueSize;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accent,
    this.valueSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent ?? theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: AppTheme.number(context, size: valueSize, color: accent),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Card holding stat tiles side by side, separated by hairlines.
class StatStrip extends StatelessWidget {
  final List<StatTile> stats;
  final EdgeInsetsGeometry padding;

  const StatStrip({
    super.key,
    required this.stats,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return Card(
      child: Padding(
        padding: padding,
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: VerticalDivider(width: 1, color: divider),
                  ),
                Expanded(child: stats[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
