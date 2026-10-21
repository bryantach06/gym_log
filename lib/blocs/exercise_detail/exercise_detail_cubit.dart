import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/session_exercise.dart';
import '../../models/pr_data.dart';
import '../../repositories/session_repository.dart';
import '../../utils/metrics_calculator.dart';

part 'exercise_detail_state.dart';

enum ProgressionMetric { topSetWeight, estimated1RM, sessionVolume, bestReps }

class ExerciseDetailCubit extends Cubit<ExerciseDetailState> {
  final SessionRepository _repo;
  final String _uid;

  ExerciseDetailCubit(this._repo, this._uid) : super(ExerciseDetailLoading());

  Future<void> load(String exerciseId) async {
    emit(ExerciseDetailLoading());
    try {
      final result = await _repo.getAllSessionExercisesWithDates(_uid, exerciseId);
      final history = result.map((e) => e.$1).toList();
      final dates = result.map((e) => e.$2).toList();
      final prs = _computePRs(history);
      emit(ExerciseDetailLoaded(
        history: history,
        historyDates: dates,
        prs: prs,
        selectedMetric: ProgressionMetric.topSetWeight,
      ));
    } catch (e) {
      emit(ExerciseDetailError(e.toString()));
    }
  }

  void toggleMetric(ProgressionMetric metric) {
    final current = state;
    if (current is! ExerciseDetailLoaded) return;
    emit(current.copyWith(selectedMetric: metric));
  }

  void setDateFilter(DateTimeRange? range) {
    final current = state;
    if (current is! ExerciseDetailLoaded) return;
    emit(current.copyWith(
      dateFilter: range,
      clearDateFilter: range == null,
    ));
  }

  PRData _computePRs(List<SessionExercise> history) {
    if (history.isEmpty) return const PRData.empty();
    final allSets = workingSets(history.expand((e) => e.sets).toList());
    if (allSets.isEmpty) return const PRData.empty();

    final heaviest = topSetWeight(allSets);
    final best1rm = best1RMFromSets(allSets);
    final bestVol = history
        .map((e) => totalVolume(workingSets(e.sets)))
        .reduce((a, b) => a > b ? a : b);
    final bestRepsCount = bestRepsAtWeight(allSets, heaviest);

    return PRData(
      heaviestSet: heaviest,
      bestRepsAtWeight: heaviest,
      bestRepsCount: bestRepsCount,
      best1RM: best1rm,
      bestVolume: bestVol,
    );
  }
}
