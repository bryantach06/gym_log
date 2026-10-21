import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/session_history/session_history_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/session_exercise.dart';
import '../../models/workout_session.dart';
import '../../repositories/session_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/metrics_calculator.dart';
import '../../utils/unit_converter.dart';
import '../../widgets/section_header.dart';
import '../../widgets/set_badge.dart';
import '../../widgets/stat_tile.dart';

class SessionDetailScreen extends StatefulWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<SessionExercise>? _exercises;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = context.read<String>();
      final exercises = await context
          .read<SessionRepository>()
          .getSessionExercises(uid, widget.session.id);
      if (mounted) setState(() => _exercises = exercises);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This permanently removes the workout and all its sets.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await context.read<SessionHistoryCubit>().deleteSession(widget.session.id);
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Workout deleted')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete workout.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.session;
    final useLbs = context.watch<SettingsCubit>().state.useLbs;
    final exercises = _exercises;

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (_) => _confirmDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Delete workout', style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            DateFormat('EEEE, MMM d · h:mm a').format(s.startedAt).toUpperCase(),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Text(workoutTitle(s.startedAt), style: theme.textTheme.displaySmall),
          const SizedBox(height: 20),
          _SummaryStrip(session: s, exercises: exercises, useLbs: useLbs),
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.notes, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
          const SectionHeader('Exercises'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text("Couldn't load exercises.", style: theme.textTheme.bodyMedium),
            )
          else if (exercises == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final ex in exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExerciseCard(ex: ex, useLbs: useLbs),
              ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final WorkoutSession session;
  final List<SessionExercise>? exercises;
  final bool useLbs;

  const _SummaryStrip({required this.session, required this.exercises, required this.useLbs});

  @override
  Widget build(BuildContext context) {
    // Prefer live numbers from the loaded exercises; fall back to the summary.
    final working = exercises?.expand((e) => workingSets(e.sets)).toList();
    final sets = working?.length ?? session.workingSetCount;
    final volume = working != null ? totalVolume(working) : session.volumeKg;
    return StatStrip(
      stats: [
        StatTile(
          label: 'Duration',
          value: session.duration != null ? formatDuration(session.duration!) : '—',
          valueSize: 26,
        ),
        StatTile(label: 'Sets', value: sets?.toString() ?? '—', valueSize: 26),
        StatTile(
          label: 'Volume',
          value: volume != null ? formatVolume(volume, useLbs) : '—',
          unit: volume != null ? unitLabel(useLbs) : null,
          valueSize: 26,
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final SessionExercise ex;
  final bool useLbs;
  const _ExerciseCard({required this.ex, required this.useLbs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final working = workingSets(ex.sets);
    // Highlight the set with the best estimated 1RM.
    final best = working.isEmpty
        ? null
        : working.reduce((a, b) =>
            estimated1RM(a.weightTotal, a.reps) >= estimated1RM(b.weightTotal, b.reps) ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(ex.exerciseName, style: theme.textTheme.titleMedium)),
                Text(
                  '${working.length} sets',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (ex.sets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('No sets logged', style: theme.textTheme.bodySmall),
              ),
            for (final s in ex.sets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SetBadge(set: s, size: 26),
                    const SizedBox(width: 14),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: displayNumber(s.weightTotal, useLbs)),
                        TextSpan(
                          text: ' ${unitLabel(useLbs)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const TextSpan(text: '  ×  '),
                        TextSpan(text: '${s.reps}'),
                      ]),
                      style: AppTheme.number(context, size: 19),
                    ),
                    const Spacer(),
                    if (identical(s, best) && working.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gym.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('TOP SET',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.primary, fontSize: 10)),
                      ),
                  ],
                ),
              ),
            if (ex.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ex.notes,
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
