import '../models/set_entry.dart';
import '../models/session_exercise.dart';

/// Sets that count toward records and progression (warmups excluded).
List<SetEntry> workingSets(List<SetEntry> sets) =>
    sets.where((s) => !s.isWarmup).toList();

double topSetWeight(List<SetEntry> sets) {
  if (sets.isEmpty) return 0;
  return sets.map((s) => s.weightTotal).reduce((a, b) => a > b ? a : b);
}

double estimated1RM(double weightTotal, int reps) {
  if (reps <= 0) return 0;
  return weightTotal * (1 + reps / 30);
}

double best1RMFromSets(List<SetEntry> sets) {
  if (sets.isEmpty) return 0;
  return sets
      .map((s) => estimated1RM(s.weightTotal, s.reps))
      .reduce((a, b) => a > b ? a : b);
}

double totalVolume(List<SetEntry> sets) {
  return sets.fold(0, (sum, s) => sum + s.weightTotal * s.reps);
}

int bestRepsAtWeight(List<SetEntry> sets, double weightTotal) {
  final matching = sets.where((s) => s.weightTotal == weightTotal);
  if (matching.isEmpty) return 0;
  return matching.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
}

double sessionVolume(SessionExercise ex) => totalVolume(ex.sets);
