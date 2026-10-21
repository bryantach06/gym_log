import 'package:flutter/material.dart';
import '../models/set_entry.dart';
import '../theme/app_theme.dart';

/// Square badge with the set number, or "W" / "D" for warmup / dropset sets.
class SetBadge extends StatelessWidget {
  final SetEntry set;
  final double size;

  const SetBadge({super.key, required this.set, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final (label, color) = set.isWarmup
        ? ('W', gym.warmup)
        : set.isDropset
            ? ('D', gym.dropset)
            : ('${set.setNumber}', theme.colorScheme.onSurfaceVariant);
    final tinted = set.isWarmup || set.isDropset;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.16) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(label, style: AppTheme.number(context, size: size * 0.52, color: color)),
    );
  }
}
