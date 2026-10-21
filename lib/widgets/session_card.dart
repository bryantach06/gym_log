import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_session.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/unit_converter.dart';

/// Finished-session summary: date block, title, stats line, exercises.
class SessionCard extends StatelessWidget {
  final WorkoutSession session;
  final bool useLbs;
  final VoidCallback? onTap;

  const SessionCard({super.key, required this.session, required this.useLbs, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    final meta = [
      if (s.duration != null) formatDuration(s.duration!),
      if (s.workingSetCount != null) '${s.workingSetCount} sets',
      if (s.volumeKg != null && s.volumeKg! > 0)
        '${formatVolume(s.volumeKg!, useLbs)} ${unitLabel(useLbs)}',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: s.startedAt),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workoutTitle(s.startedAt), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [DateFormat('h:mm a').format(s.startedAt), ...meta].join('  ·  '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (s.exerciseNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ExerciseNames(names: s.exerciseNames),
                    ] else if (s.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final DateTime date;
  const _DateBlock({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(DateFormat('MMM').format(date).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(DateFormat('d').format(date), style: AppTheme.number(context, size: 24)),
          const SizedBox(height: 2),
          Text(DateFormat('EEE').format(date).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ExerciseNames extends StatelessWidget {
  final List<String> names;
  const _ExerciseNames({required this.names});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const shown = 3;
    final extra = names.length - shown;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final n in names.take(shown)) _Pill(n),
        if (extra > 0)
          _Pill('+$extra', color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const _Pill(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(color: color ?? theme.colorScheme.onSurface),
      ),
    );
  }
}
