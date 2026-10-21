part of 'exercise_logger_bloc.dart';

abstract class ExerciseLoggerState extends Equatable {
  const ExerciseLoggerState();
  @override
  List<Object?> get props => [];
}

class ExerciseLoggerLoading extends ExerciseLoggerState {}

class ExerciseLoggerReady extends ExerciseLoggerState {
  final List<SetEntry> ghostSets;
  final List<SetEntry> currentSets;
  final List<bool> prFlags;
  final String notes;
  /// True while a Firestore write is in-flight.
  final bool isSaving;
  /// True when a new PR was just detected by a user input event.
  final bool newPRDetected;

  const ExerciseLoggerReady({
    required this.ghostSets,
    required this.currentSets,
    required this.prFlags,
    this.notes = '',
    this.isSaving = false,
    this.newPRDetected = false,
  });

  ExerciseLoggerReady copyWith({
    List<SetEntry>? ghostSets,
    List<SetEntry>? currentSets,
    List<bool>? prFlags,
    String? notes,
    bool? isSaving,
    bool? newPRDetected,
  }) =>
      ExerciseLoggerReady(
        ghostSets: ghostSets ?? this.ghostSets,
        currentSets: currentSets ?? this.currentSets,
        prFlags: prFlags ?? this.prFlags,
        notes: notes ?? this.notes,
        isSaving: isSaving ?? this.isSaving,
        newPRDetected: newPRDetected ?? this.newPRDetected,
      );

  @override
  List<Object?> get props => [ghostSets, currentSets, prFlags, notes, isSaving, newPRDetected];
}

class ExerciseLoggerSaved extends ExerciseLoggerState {
  final List<SetEntry> savedSets;
  const ExerciseLoggerSaved(this.savedSets);
  @override
  List<Object?> get props => [savedSets];
}

class ExerciseLoggerError extends ExerciseLoggerState {
  final String message;
  /// The ready state to restore to so the user doesn't lose their data.
  final ExerciseLoggerReady? previousState;
  const ExerciseLoggerError(this.message, {this.previousState});
  @override
  List<Object?> get props => [message, previousState];
}
