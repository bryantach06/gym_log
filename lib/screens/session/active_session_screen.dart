import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../blocs/exercise_library/exercise_library_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/exercise.dart';
import '../../models/session_exercise.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/metrics_calculator.dart';
import '../../utils/unit_converter.dart';
import '../../widgets/elapsed_timer.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/muscle_avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import 'exercise_logger_screen.dart';

/// Matches the cap enforced in SessionBloc.
const _maxExercises = 10;

class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionBloc, SessionState>(
      listener: (context, state) {
        if (state is SessionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Something went wrong: ${state.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        if (state is SessionComplete || state is SessionInitial) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      // Errors are transient (the bloc restores the workout); don't flash a spinner.
      buildWhen: (_, state) => state is! SessionError,
      builder: (context, state) {
        if (state is! SessionActive) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _ActiveSessionView(state: state);
      },
    );
  }
}

class _ActiveSessionView extends StatelessWidget {
  final SessionActive state;
  const _ActiveSessionView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useLbs = context.watch<SettingsCubit>().state.useLbs;
    final working = state.exercises.expand((e) => workingSets(e.sets)).toList();
    final atCap = state.exercises.length >= _maxExercises;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Minimize',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workoutTitle(state.session.startedAt).toUpperCase(),
                style: theme.textTheme.labelSmall),
            const SizedBox(height: 2),
            ElapsedTimer(
              since: state.session.startedAt,
              style: AppTheme.number(context, size: 26, color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (_) => _confirmDiscard(context),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'discard',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Discard workout', style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          StatStrip(
            stats: [
              StatTile(label: 'Exercises', value: '${state.exercises.length}', valueSize: 26),
              StatTile(label: 'Sets', value: '${working.length}', valueSize: 26),
              StatTile(
                label: 'Volume',
                value: formatVolume(totalVolume(working), useLbs),
                unit: unitLabel(useLbs),
                valueSize: 26,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SessionNotesField(initialNotes: state.session.notes),
          const SectionHeader('Exercises'),
          if (state.exercises.isEmpty)
            EmptyState(
              icon: Icons.add_rounded,
              title: 'Add your first exercise',
              message: 'Pick from your library — sets from last time are pre-filled.',
              action: FilledButton.tonalIcon(
                onPressed: () => _showExercisePicker(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add exercise'),
              ),
            )
          else
            for (var i = 0; i < state.exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExerciseCard(
                  index: i,
                  exercise: state.exercises[i],
                  useLbs: useLbs,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseLoggerScreen(
                        sessionExercise: state.exercises[i],
                        sessionId: state.session.id,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: atCap ? null : () => _showExercisePicker(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(atCap ? 'Max $_maxExercises' : 'Add exercise'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmFinish(context, state),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExercisePicker(BuildContext context) {
    context.read<ExerciseLibraryCubit>().loadExercises();
    final added = state.exercises.map((e) => e.exerciseId).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => BlocProvider.value(
        value: context.read<ExerciseLibraryCubit>(),
        child: _ExercisePickerSheet(
          alreadyAdded: added,
          onSelected: (ex) {
            context.read<SessionBloc>().add(SessionExerciseAdded(ex));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _confirmFinish(BuildContext context, SessionActive state) {
    final unlogged = state.exercises.where((e) => e.sets.isEmpty).length;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Text(
          unlogged == 0
              ? 'Nice work. This saves the session to your history.'
              : '$unlogged exercise${unlogged == 1 ? ' has' : 's have'} no saved sets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep going'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<SessionBloc>().add(SessionFinished());
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _confirmDiscard(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('This deletes the session and every set logged in it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogCtx).colorScheme.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<SessionBloc>().add(SessionDiscarded());
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise card
// ---------------------------------------------------------------------------

class _ExerciseCard extends StatelessWidget {
  final int index;
  final SessionExercise exercise;
  final bool useLbs;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.useLbs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final sets = exercise.sets.where(isLogged).toList();
    final done = sets.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? gym.accent : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? Icon(Icons.check_rounded, size: 18, color: gym.onAccent)
                        : Text('${index + 1}', style: AppTheme.number(context, size: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.exerciseName, style: theme.textTheme.titleMedium),
                        Text(capitalize(exercise.equipmentType), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              if (!done)
                Text('Tap to log sets',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary))
              else
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
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session notes field — debounces writes via the bloc
// ---------------------------------------------------------------------------

class _SessionNotesField extends StatefulWidget {
  final String initialNotes;
  const _SessionNotesField({required this.initialNotes});

  @override
  State<_SessionNotesField> createState() => _SessionNotesFieldState();
}

class _SessionNotesFieldState extends State<_SessionNotesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      maxLines: null,
      decoration: const InputDecoration(
        hintText: 'How are you feeling today?',
        prefixIcon: Icon(Icons.notes_rounded),
      ),
      onChanged: (v) => context.read<SessionBloc>().add(SessionNotesUpdated(v)),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise picker bottom sheet
// ---------------------------------------------------------------------------

class _ExercisePickerSheet extends StatelessWidget {
  final Set<String> alreadyAdded;
  final ValueChanged<Exercise> onSelected;

  const _ExercisePickerSheet({required this.alreadyAdded, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(child: Text('Add exercise', style: theme.textTheme.headlineSmall)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (q) => context.read<ExerciseLibraryCubit>().search(q),
            ),
          ),
          Expanded(
            child: BlocBuilder<ExerciseLibraryCubit, ExerciseLibraryState>(
              builder: (context, state) {
                if (state is ExerciseLibraryLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is! ExerciseLibraryLoaded) return const SizedBox.shrink();
                return ListView.builder(
                  controller: ctrl,
                  // Keyboard when open, otherwise the system navigation bar.
                  padding: EdgeInsets.fromLTRB(
                    8,
                    4,
                    8,
                    24 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: state.filtered.length,
                  itemBuilder: (_, i) {
                    final ex = state.filtered[i];
                    final added = alreadyAdded.contains(ex.id);
                    return ListTile(
                      leading: MuscleAvatar(muscleGroup: ex.muscleGroup, size: 40),
                      title: Text(ex.name),
                      subtitle: Text(
                          '${capitalize(ex.muscleGroup)} · ${capitalize(ex.equipmentType)}'),
                      trailing: added
                          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                          : const Icon(Icons.add_circle_outline_rounded),
                      onTap: () => onSelected(ex),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
