part of 'session_bloc.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();
  @override
  List<Object?> get props => [];
}

class SessionStarted extends SessionEvent {}

class SessionResumed extends SessionEvent {
  const SessionResumed();
}

class SessionExerciseAdded extends SessionEvent {
  final Exercise exercise;
  const SessionExerciseAdded(this.exercise);
  @override
  List<Object?> get props => [exercise];
}

class SessionFinished extends SessionEvent {}

class SessionDiscarded extends SessionEvent {}

class SessionExerciseSetsUpdated extends SessionEvent {
  final String sessionExerciseId;
  final List<SetEntry> sets;
  const SessionExerciseSetsUpdated(this.sessionExerciseId, this.sets);
  @override
  List<Object?> get props => [sessionExerciseId, sets];
}

class SessionNotesUpdated extends SessionEvent {
  final String notes;
  const SessionNotesUpdated(this.notes);
  @override
  List<Object?> get props => [notes];
}
