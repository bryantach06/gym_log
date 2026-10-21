import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exercise.dart';
import '../../repositories/exercise_repository.dart';

part 'exercise_library_state.dart';

class ExerciseLibraryCubit extends Cubit<ExerciseLibraryState> {
  final ExerciseRepository _repo;
  final String _uid;

  List<Exercise> _allExercises = [];

  ExerciseLibraryCubit(this._repo, this._uid) : super(ExerciseLibraryLoading());

  Future<void> loadExercises() async {
    if (_allExercises.isNotEmpty) {
      emit(ExerciseLibraryLoaded(all: _allExercises, filtered: _allExercises));
      return;
    }
    emit(ExerciseLibraryLoading());
    try {
      _allExercises = await _repo.getExercises(_uid);
      emit(ExerciseLibraryLoaded(all: _allExercises, filtered: _allExercises));
    } catch (e) {
      emit(ExerciseLibraryError(e.toString()));
    }
  }

  void filterByMuscleGroup(String? group) {
    final current = state;
    if (current is! ExerciseLibraryLoaded) return;
    final filtered = group == null
        ? _allExercises
        : _allExercises.where((e) => e.muscleGroup == group).toList();
    emit(ExerciseLibraryLoaded(
      all: _allExercises,
      filtered: filtered,
      activeGroup: group,
      searchQuery: current.searchQuery,
    ));
  }

  void search(String query) {
    final current = state;
    if (current is! ExerciseLibraryLoaded) return;
    final q = query.toLowerCase();
    final filtered = _allExercises.where((e) {
      final matchesGroup = current.activeGroup == null ||
          e.muscleGroup == current.activeGroup;
      final matchesQuery = q.isEmpty || e.name.toLowerCase().contains(q);
      return matchesGroup && matchesQuery;
    }).toList();
    emit(ExerciseLibraryLoaded(
      all: _allExercises,
      filtered: filtered,
      activeGroup: current.activeGroup,
      searchQuery: query,
    ));
  }

  Future<void> addCustomExercise(Exercise exercise) async {
    try {
      final saved = await _repo.addExercise(_uid, exercise);
      _allExercises = [..._allExercises, saved]
        ..sort((a, b) => a.name.compareTo(b.name));
      final current = state;
      final group = current is ExerciseLibraryLoaded ? current.activeGroup : null;
      final query = current is ExerciseLibraryLoaded ? current.searchQuery : '';
      filterByMuscleGroup(group);
      if (query.isNotEmpty) search(query);
    } catch (e) {
      emit(ExerciseLibraryError(e.toString()));
    }
  }

  Future<void> updateCustomExercise(Exercise exercise) async {
    try {
      await _repo.updateExercise(_uid, exercise);
      _allExercises = _allExercises
          .map((e) => e.id == exercise.id ? exercise : e)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final current = state;
      final group = current is ExerciseLibraryLoaded ? current.activeGroup : null;
      final query = current is ExerciseLibraryLoaded ? current.searchQuery : '';
      filterByMuscleGroup(group);
      if (query.isNotEmpty) search(query);
    } catch (e) {
      emit(ExerciseLibraryError(e.toString()));
    }
  }

  Future<void> deleteCustomExercise(String exerciseId) async {
    try {
      await _repo.deleteExercise(_uid, exerciseId);
      _allExercises = _allExercises.where((e) => e.id != exerciseId).toList();
      final current = state;
      final group = current is ExerciseLibraryLoaded ? current.activeGroup : null;
      final query = current is ExerciseLibraryLoaded ? current.searchQuery : '';
      filterByMuscleGroup(group);
      if (query.isNotEmpty) search(query);
    } catch (e) {
      emit(ExerciseLibraryError(e.toString()));
    }
  }
}
