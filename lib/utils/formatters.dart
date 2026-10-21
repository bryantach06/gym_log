import '../models/set_entry.dart';
import 'unit_converter.dart';

/// "1h 05m", "42m", or "0m".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m';
}

/// Running clock: "4:07" or "1:04:07".
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Name for a session based on when it started, e.g. "Evening Workout".
String workoutTitle(DateTime startedAt) {
  final h = startedAt.hour;
  if (h < 5) return 'Late Night Workout';
  if (h < 12) return 'Morning Workout';
  if (h < 17) return 'Afternoon Workout';
  if (h < 21) return 'Evening Workout';
  return 'Night Workout';
}

/// Number without trailing ".0": 100 → "100", 102.5 → "102.5".
String trimNumber(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Weight in the display unit without the unit label.
String displayNumber(double kg, bool useLbs) => trimNumber(toDisplayWeight(kg, useLbs));

/// Volume, shortened above 10k: "8,450" / "12.4k".
String formatVolume(double kg, bool useLbs) {
  final v = toDisplayWeight(kg, useLbs);
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  final whole = v.round().toString();
  return whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// Compact set label: "100 × 5".
String setLabel(SetEntry s, bool useLbs) => '${displayNumber(s.weightTotal, useLbs)} × ${s.reps}';

/// Whether a set has anything logged in it.
bool isLogged(SetEntry s) => s.reps > 0 || s.weightTotal > 0;

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
