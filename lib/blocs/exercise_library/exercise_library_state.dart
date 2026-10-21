part of 'exercise_library_cubit.dart';

abstract class ExerciseLibraryState extends Equatable {
  const ExerciseLibraryState();
  @override
  List<Object?> get props => [];
}

class ExerciseLibraryLoading extends ExerciseLibraryState {}

class ExerciseLibraryLoaded extends ExerciseLibraryState {
  final List<Exercise> all;
  final List<Exercise> filtered;
  final String? activeGroup;
  final String searchQuery;

  const ExerciseLibraryLoaded({
    required this.all,
    required this.filtered,
    this.activeGroup,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [all, filtered, activeGroup, searchQuery];
}

class ExerciseLibraryError extends ExerciseLibraryState {
  final String message;
  const ExerciseLibraryError(this.message);
  @override
  List<Object?> get props => [message];
}
