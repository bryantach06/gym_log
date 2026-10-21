import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/exercise_detail/exercise_detail_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/exercise.dart';
import '../../repositories/session_repository.dart';
import '../../models/session_exercise.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/unit_converter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/muscle_avatar.dart';
import '../../widgets/progression_chart.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<String>();
    return BlocProvider(
      create: (_) => ExerciseDetailCubit(context.read<SessionRepository>(), uid)
        ..load(exercise.id),
      child: _ExerciseDetailView(exercise: exercise),
    );
  }
}

class _ExerciseDetailView extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseDetailView({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final useLbs = context.watch<SettingsCubit>().state.useLbs;
    final unit = unitLabel(useLbs);

    return Scaffold(
      appBar: AppBar(),
      body: BlocBuilder<ExerciseDetailCubit, ExerciseDetailState>(
        builder: (context, state) {
          final header = _Header(exercise: exercise);
          if (state is ExerciseDetailLoading) {
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                header,
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (state is ExerciseDetailError) {
            return Center(child: Text(state.message));
          }
          if (state is! ExerciseDetailLoaded) return const SizedBox.shrink();

          final prs = state.prs;
          final filtered = state.filteredHistory;
          final filteredDates = state.filteredDates;
          String weight(double? kg) => kg == null ? '—' : displayNumber(kg, useLbs);

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              header,
              const SectionHeader('Personal records'),
              if (state.history.isEmpty)
                const Card(
                  child: EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'No records yet',
                    message: 'Log this exercise in a workout to start tracking PRs.',
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.75,
                  children: [
                    _PRCard(
                      label: 'Heaviest',
                      value: weight(prs.heaviestSet),
                      unit: unit,
                      icon: Icons.emoji_events_rounded,
                      color: gym.pr,
                    ),
                    _PRCard(
                      label: 'Est. 1RM',
                      value: weight(prs.best1RM),
                      unit: unit,
                      icon: Icons.trending_up_rounded,
                    ),
                    _PRCard(
                      label: 'Best volume',
                      value: prs.bestVolume == null ? '—' : formatVolume(prs.bestVolume!, useLbs),
                      unit: unit,
                      icon: Icons.stacked_bar_chart_rounded,
                    ),
                    _PRCard(
                      label: 'Reps @ heaviest',
                      value: prs.bestRepsCount?.toString() ?? '—',
                      unit: prs.bestRepsAtWeight == null
                          ? null
                          : '@ ${weight(prs.bestRepsAtWeight)} $unit',
                      icon: Icons.repeat_rounded,
                    ),
                  ],
                ),

              // ── Progression chart ─────────────────────────────────────────
              const SectionHeader('Progress'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricToggle(selected: state.selectedMetric),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _DateRangeButton(
                          activeFilter: state.dateFilter,
                          onPick: (range) =>
                              context.read<ExerciseDetailCubit>().setDateFilter(range),
                          onClear: () => context.read<ExerciseDetailCubit>().setDateFilter(null),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 210,
                        child: ProgressionChart(
                          history: filtered,
                          dates: filteredDates,
                          metric: state.selectedMetric,
                          useLbs: useLbs,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── History list ──────────────────────────────────────────────
              SectionHeader(
                state.dateFilter == null
                    ? 'History'
                    : 'History · ${_fmt(state.dateFilter!.start)} – ${_fmt(state.dateFilter!.end)}',
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      state.history.isEmpty ? 'No sessions yet' : 'No sessions in this range',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                // Newest first reads better in a list (the chart is oldest-first).
                ...List.generate(filtered.length, (j) {
                  final i = filtered.length - 1 - j;
                  final date = i < filteredDates.length ? filteredDates[i] : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(ex: filtered[i], date: date, useLbs: useLbs),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat('MMM d').format(d);
}

class _Header extends StatelessWidget {
  final Exercise exercise;
  const _Header({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        MuscleAvatar(muscleGroup: exercise.muscleGroup, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercise.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                [
                  capitalize(exercise.muscleGroup),
                  capitalize(exercise.equipmentType),
                  if (exercise.barWeightKg != null) '${trimNumber(exercise.barWeightKg!)} kg bar',
                  if (exercise.isCustom) 'Custom',
                ].join('  ·  '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PRCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? color;

  const _PRCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: StatTile(label: label, value: value, unit: unit, icon: icon, accent: color),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SessionExercise ex;
  final DateTime? date;
  final bool useLbs;

  const _HistoryCard({required this.ex, required this.date, required this.useLbs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final sets = ex.sets.where(isLogged).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null)
              Text(DateFormat('EEE, MMM d y').format(date!).toUpperCase(),
                  style: theme.textTheme.labelSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in sets)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: s.isWarmup
                          ? gym.warmup.withValues(alpha: 0.14)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      setLabel(s, useLbs),
                      style: AppTheme.number(context,
                          size: 15, color: s.isWarmup ? gym.warmup : null),
                    ),
                  ),
              ],
            ),
            if (ex.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ex.notes,
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date range filter button
// ---------------------------------------------------------------------------

class _DateRangeButton extends StatelessWidget {
  final DateTimeRange? activeFilter;
  final ValueChanged<DateTimeRange?> onPick;
  final VoidCallback onClear;

  const _DateRangeButton({
    required this.activeFilter,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeFilter != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          icon: Icon(
            Icons.date_range,
            size: 16,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          label: Text(
            isActive ? 'Filtered' : 'All time',
            style: TextStyle(
              fontSize: 13,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: now,
              initialDateRange: activeFilter ??
                  DateTimeRange(
                    start: now.subtract(const Duration(days: 90)),
                    end: now,
                  ),
            );
            if (picked != null) onPick(picked);
          },
        ),
        if (isActive)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Clear filter',
            onPressed: onClear,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Metric toggle chips
// ---------------------------------------------------------------------------

class _MetricToggle extends StatelessWidget {
  final ProgressionMetric selected;
  const _MetricToggle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ProgressionMetric.values.map((m) {
        return ChoiceChip(
          label: Text(_label(m)),
          selected: selected == m,
          onSelected: (_) =>
              context.read<ExerciseDetailCubit>().toggleMetric(m),
        );
      }).toList(),
    );
  }

  String _label(ProgressionMetric m) {
    switch (m) {
      case ProgressionMetric.topSetWeight:
        return 'Top set';
      case ProgressionMetric.estimated1RM:
        return '1RM';
      case ProgressionMetric.sessionVolume:
        return 'Volume';
      case ProgressionMetric.bestReps:
        return 'Reps';
    }
  }
}
