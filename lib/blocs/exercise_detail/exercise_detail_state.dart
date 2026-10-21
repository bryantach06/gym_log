part of 'exercise_detail_cubit.dart';

abstract class ExerciseDetailState extends Equatable {
  const ExerciseDetailState();
  @override
  List<Object?> get props => [];
}

class ExerciseDetailLoading extends ExerciseDetailState {}

class ExerciseDetailLoaded extends ExerciseDetailState {
  /// Full history (all time), oldest-first.
  final List<SessionExercise> history;

  /// Session date for each entry in [history], same order.
  final List<DateTime> historyDates;

  final PRData prs;
  final ProgressionMetric selectedMetric;

  /// Active date-range filter. Null means "all time".
  final DateTimeRange? dateFilter;

  const ExerciseDetailLoaded({
    required this.history,
    required this.historyDates,
    required this.prs,
    required this.selectedMetric,
    this.dateFilter,
  });

  /// History entries that fall within [dateFilter], or all entries when null.
  List<SessionExercise> get filteredHistory {
    if (dateFilter == null) return history;
    return [
      for (var i = 0; i < history.length; i++)
        if (!historyDates[i].isBefore(dateFilter!.start) &&
            !historyDates[i].isAfter(dateFilter!.end))
          history[i],
    ];
  }

  /// Dates corresponding to [filteredHistory].
  List<DateTime> get filteredDates {
    if (dateFilter == null) return historyDates;
    return [
      for (var i = 0; i < historyDates.length; i++)
        if (!historyDates[i].isBefore(dateFilter!.start) &&
            !historyDates[i].isAfter(dateFilter!.end))
          historyDates[i],
    ];
  }

  ExerciseDetailLoaded copyWith({
    List<SessionExercise>? history,
    List<DateTime>? historyDates,
    PRData? prs,
    ProgressionMetric? selectedMetric,
    DateTimeRange? dateFilter,
    bool clearDateFilter = false,
  }) =>
      ExerciseDetailLoaded(
        history: history ?? this.history,
        historyDates: historyDates ?? this.historyDates,
        prs: prs ?? this.prs,
        selectedMetric: selectedMetric ?? this.selectedMetric,
        dateFilter: clearDateFilter ? null : (dateFilter ?? this.dateFilter),
      );

  @override
  List<Object?> get props =>
      [history, historyDates, prs, selectedMetric, dateFilter];
}

class ExerciseDetailError extends ExerciseDetailState {
  final String message;
  const ExerciseDetailError(this.message);
  @override
  List<Object?> get props => [message];
}
