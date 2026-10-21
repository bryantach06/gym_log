part of 'exercise_logger_bloc.dart';

abstract class ExerciseLoggerEvent extends Equatable {
  const ExerciseLoggerEvent();
  @override
  List<Object?> get props => [];
}

class ExerciseLoggerOpened extends ExerciseLoggerEvent {}

class SetWeightChanged extends ExerciseLoggerEvent {
  final int setIndex;
  final double value;
  const SetWeightChanged(this.setIndex, this.value);
  @override
  List<Object?> get props => [setIndex, value];
}

class SetRepsChanged extends ExerciseLoggerEvent {
  final int setIndex;
  final int reps;
  const SetRepsChanged(this.setIndex, this.reps);
  @override
  List<Object?> get props => [setIndex, reps];
}

class SetWarmupToggled extends ExerciseLoggerEvent {
  final int setIndex;
  const SetWarmupToggled(this.setIndex);
  @override
  List<Object?> get props => [setIndex];
}

class SetDropsetToggled extends ExerciseLoggerEvent {
  final int setIndex;
  const SetDropsetToggled(this.setIndex);
  @override
  List<Object?> get props => [setIndex];
}

class SetAdded extends ExerciseLoggerEvent {}

class SetRemoved extends ExerciseLoggerEvent {
  final int setIndex;
  const SetRemoved(this.setIndex);
  @override
  List<Object?> get props => [setIndex];
}

class SetsSaved extends ExerciseLoggerEvent {}

// Internal events fired from background persist callbacks.
class _PersistCompleted extends ExerciseLoggerEvent {
  const _PersistCompleted();
}

class _PersistFailed extends ExerciseLoggerEvent {
  final String message;
  const _PersistFailed(this.message);
  @override
  List<Object?> get props => [message];
}

/// Fired by the UI after it has shown the PR toast, so the flag resets.
class PRNotificationShown extends ExerciseLoggerEvent {
  const PRNotificationShown();
}

class ExerciseNotesUpdated extends ExerciseLoggerEvent {
  final String notes;
  const ExerciseNotesUpdated(this.notes);
  @override
  List<Object?> get props => [notes];
}
