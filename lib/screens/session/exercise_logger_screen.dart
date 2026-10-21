import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/exercise_logger/exercise_logger_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/session_exercise.dart';
import '../../models/set_entry.dart';
import '../../repositories/session_repository.dart';
import '../../utils/formatters.dart';
import '../../utils/weight_calculator.dart';
import '../../widgets/pr_badge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/set_input_row.dart';

class ExerciseLoggerScreen extends StatelessWidget {
  final SessionExercise sessionExercise;
  final String sessionId;

  const ExerciseLoggerScreen({
    super.key,
    required this.sessionExercise,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.read<String>();

    return BlocProvider(
      create: (_) => ExerciseLoggerBloc(
        repo: context.read<SessionRepository>(),
        uid: uid,
        sessionId: sessionId,
        sessionExerciseId: sessionExercise.id,
        exerciseId: sessionExercise.exerciseId,
        equipmentType: sessionExercise.equipmentType,
        barWeightKg: sessionExercise.barWeightKg,
      )..add(ExerciseLoggerOpened()),
      child: _ExerciseLoggerView(sessionExercise: sessionExercise),
    );
  }
}

class _ExerciseLoggerView extends StatefulWidget {
  final SessionExercise sessionExercise;
  const _ExerciseLoggerView({required this.sessionExercise});

  @override
  State<_ExerciseLoggerView> createState() => _ExerciseLoggerViewState();
}

class _ExerciseLoggerViewState extends State<_ExerciseLoggerView> {
  void _handleSaved(BuildContext context, List<SetEntry> sets) {
    // Notify the SessionBloc so the exercise list stays in sync.
    context.read<SessionBloc>().add(
          SessionExerciseSetsUpdated(widget.sessionExercise.id, List.from(sets)),
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.sessionExercise.exerciseName} saved'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _usePrevious(BuildContext context, int index, SetEntry previous) {
    final bloc = context.read<ExerciseLoggerBloc>();
    bloc.add(SetWeightChanged(index, previous.weightInput));
    bloc.add(SetRepsChanged(index, previous.reps));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useLbs = context.watch<SettingsCubit>().state.useLbs;
    final ex = widget.sessionExercise;

    return BlocConsumer<ExerciseLoggerBloc, ExerciseLoggerState>(
      listener: (context, state) {
        // PR toast: only fires when the bloc explicitly sets newPRDetected=true
        // (i.e. triggered by user weight/reps input, never on initial load).
        if (state is ExerciseLoggerReady && state.newPRDetected) {
          PRBadge.show(context, 'New personal record!');
          context.read<ExerciseLoggerBloc>().add(const PRNotificationShown());
        }
        if (state is ExerciseLoggerSaved) {
          _handleSaved(context, state.savedSets);
        }
        if (state is ExerciseLoggerError && state.previousState != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Save failed: ${state.message}'),
              backgroundColor: theme.colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                textColor: theme.colorScheme.onError,
                onPressed: () => context.read<ExerciseLoggerBloc>().add(SetsSaved()),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final appBar = AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ex.exerciseName, overflow: TextOverflow.ellipsis),
              Text(capitalize(ex.equipmentType), style: theme.textTheme.bodySmall),
            ],
          ),
        );

        // Full-screen loading only on initial open.
        if (state is ExerciseLoggerLoading) {
          return Scaffold(appBar: appBar, body: const Center(child: CircularProgressIndicator()));
        }

        // Recover from error by restoring the previous ready state.
        final ready = state is ExerciseLoggerReady
            ? state
            : (state is ExerciseLoggerError ? state.previousState : null);

        if (ready == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                state is ExerciseLoggerError ? state.message : '',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }

        final isSaving = ready.isSaving;
        final bloc = context.read<ExerciseLoggerBloc>();

        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        weightEntryHint(ex.equipmentType, ex.barWeightKg, useLbs: useLbs),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                  child: Column(
                    children: [
                      SetTableHeader(
                        weightLabel: weightColumnLabel(ex.equipmentType, useLbs: useLbs),
                      ),
                      ...List.generate(ready.currentSets.length, (i) {
                        final previous =
                            i < ready.ghostSets.length ? ready.ghostSets[i] : null;
                        return SetInputRow(
                          key: ValueKey('set_row_$i'),
                          set: ready.currentSets[i],
                          index: i,
                          previous: previous,
                          isLastSet: ready.currentSets.length == 1,
                          equipmentType: ex.equipmentType,
                          barWeightKg: ex.barWeightKg,
                          isPR: i < ready.prFlags.length && ready.prFlags[i],
                          useLbs: useLbs,
                          onWeightChanged: (v) => bloc.add(SetWeightChanged(i, v)),
                          onRepsChanged: (v) => bloc.add(SetRepsChanged(i, v)),
                          onWarmupToggled: () => bloc.add(SetWarmupToggled(i)),
                          onDropsetToggled: () => bloc.add(SetDropsetToggled(i)),
                          onRemove: () => bloc.add(SetRemoved(i)),
                          onUsePrevious:
                              previous == null ? null : () => _usePrevious(context, i, previous),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: theme.colorScheme.onSurface,
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add set'),
                            onPressed: () => bloc.add(SetAdded()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                child: Text(
                  'Tap a set number for warmup / drop set · swipe left to remove · '
                  'tap a previous value to reuse it',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ),
              const SectionHeader('Notes', padding: EdgeInsets.fromLTRB(6, 24, 6, 10)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _ExerciseNotesField(initialNotes: ready.notes),
              ),
            ],
          ),
          // Save button in a persistent bottom bar so it's always reachable.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                icon: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(isSaving ? 'Saving…' : 'Save sets'),
                onPressed: isSaving ? null : () => bloc.add(SetsSaved()),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise notes field — debounces writes via the bloc
// ---------------------------------------------------------------------------

class _ExerciseNotesField extends StatefulWidget {
  final String initialNotes;
  const _ExerciseNotesField({required this.initialNotes});

  @override
  State<_ExerciseNotesField> createState() => _ExerciseNotesFieldState();
}

class _ExerciseNotesFieldState extends State<_ExerciseNotesField> {
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
        hintText: 'Form cues, seat height, how it felt…',
      ),
      onChanged: (v) => context.read<ExerciseLoggerBloc>().add(ExerciseNotesUpdated(v)),
    );
  }
}
