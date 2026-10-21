import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/exercise_library/exercise_library_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/exercise.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/muscle_avatar.dart';
import 'exercise_detail_screen.dart';

const _muscleGroups = [
  'chest', 'back', 'shoulders', 'biceps', 'triceps',
  'legs', 'glutes', 'core', 'cardio', 'other',
];

const _equipmentTypes = ['barbell', 'dumbbell', 'machine', 'bodyweight', 'smith'];

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExerciseLibraryCubit>().loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Exercises')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (q) => context.read<ExerciseLibraryCubit>().search(q),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const _GroupChip(label: 'All', group: null),
                  ..._muscleGroups.map((g) => _GroupChip(label: capitalize(g), group: g)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          BlocBuilder<ExerciseLibraryCubit, ExerciseLibraryState>(
            builder: (context, state) {
              if (state is ExerciseLibraryLoading) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (state is ExerciseLibraryError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load exercises",
                    message: state.message,
                  ),
                );
              }
              if (state is! ExerciseLibraryLoaded) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              if (state.filtered.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Try another search, or add it as a custom exercise.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                sliver: SliverList.builder(
                  itemCount: state.filtered.length,
                  itemBuilder: (_, i) => _ExerciseTile(exercise: state.filtered[i]),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('New exercise'),
        onPressed: () => _showExerciseSheet(context),
      ),
    );
  }
}

void _showExerciseSheet(BuildContext context, {Exercise? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: context.read<ExerciseLibraryCubit>(),
      child: _CustomExerciseSheet(existing: existing),
    ),
  );
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = exercise;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: MuscleAvatar(muscleGroup: ex.muscleGroup),
      title: Row(
        children: [
          Flexible(child: Text(ex.name, overflow: TextOverflow.ellipsis)),
          if (ex.isCustom) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('CUSTOM', style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
            ),
          ],
        ],
      ),
      subtitle: Text('${capitalize(ex.muscleGroup)} · ${capitalize(ex.equipmentType)}'),
      trailing: ex.isCustom
          ? _CustomExerciseMenu(exercise: ex)
          : Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Three-dot menu for custom exercises
// ---------------------------------------------------------------------------

class _CustomExerciseMenu extends StatelessWidget {
  final Exercise exercise;
  const _CustomExerciseMenu({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<_ExerciseAction>(
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (action) {
        switch (action) {
          case _ExerciseAction.edit:
            _showExerciseSheet(context, existing: exercise);
          case _ExerciseAction.delete:
            _confirmDelete(context);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: _ExerciseAction.edit, child: Text('Edit')),
        PopupMenuItem(
          value: _ExerciseAction.delete,
          child: Text('Delete', style: TextStyle(color: error)),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<ExerciseLibraryCubit>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: Text('"${exercise.name}" will be removed from your library. '
            'Past workouts keep their sets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogCtx).colorScheme.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              cubit.deleteCustomExercise(exercise.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

enum _ExerciseAction { edit, delete }

// ---------------------------------------------------------------------------
// Muscle group filter chip
// ---------------------------------------------------------------------------

class _GroupChip extends StatelessWidget {
  final String label;
  final String? group;
  const _GroupChip({required this.label, required this.group});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExerciseLibraryCubit, ExerciseLibraryState>(
      builder: (context, state) {
        final active = state is ExerciseLibraryLoaded ? state.activeGroup == group : false;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: active,
            onSelected: (_) => context.read<ExerciseLibraryCubit>().filterByMuscleGroup(group),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit custom exercise sheet
// ---------------------------------------------------------------------------

class _CustomExerciseSheet extends StatefulWidget {
  /// When non-null, the sheet is in edit mode.
  final Exercise? existing;
  const _CustomExerciseSheet({this.existing});

  @override
  State<_CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<_CustomExerciseSheet> {
  late final TextEditingController _nameCtrl;
  late String _muscleGroup;
  late String _equipmentType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _muscleGroup = widget.existing?.muscleGroup ?? 'other';
    _equipmentType = widget.existing?.equipmentType ?? 'barbell';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final cubit = context.read<ExerciseLibraryCubit>();
    final needsBar = _equipmentType == 'barbell' || _equipmentType == 'smith';
    final defaultBar = context.read<SettingsCubit>().state.defaultBarWeightKg;
    if (_isEditing) {
      cubit.updateCustomExercise(
        widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          muscleGroup: _muscleGroup,
          equipmentType: _equipmentType,
          barWeightKg: needsBar ? (widget.existing!.barWeightKg ?? defaultBar) : null,
          clearBarWeight: !needsBar,
        ),
      );
    } else {
      cubit.addCustomExercise(
        Exercise(
          id: '',
          name: _nameCtrl.text.trim(),
          muscleGroup: _muscleGroup,
          equipmentType: _equipmentType,
          barWeightKg: needsBar ? defaultBar : null,
          isCustom: true,
          createdAt: DateTime.now(),
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);

    Widget chips(List<String> values, String selected, ValueChanged<String> onSelect) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(capitalize(v)),
                selected: v == selected,
                labelStyle: theme.textTheme.labelLarge
                    ?.copyWith(color: v == selected ? gym.onAccent : theme.colorScheme.onSurface),
                onSelected: (_) => setState(() => onSelect(v)),
              ),
          ],
        );

    return Padding(
      padding: EdgeInsets.only(
        // Keyboard when open, otherwise the system navigation bar.
        bottom: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEditing ? 'Edit exercise' : 'New exercise', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Exercise name'),
            ),
            const SizedBox(height: 20),
            Text('MUSCLE GROUP', style: theme.textTheme.labelSmall),
            const SizedBox(height: 10),
            chips(_muscleGroups, _muscleGroup, (v) => _muscleGroup = v),
            const SizedBox(height: 20),
            Text('EQUIPMENT', style: theme.textTheme.labelSmall),
            const SizedBox(height: 10),
            chips(_equipmentTypes, _equipmentType, (v) => _equipmentType = v),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save changes' : 'Add exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
