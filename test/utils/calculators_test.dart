import 'package:flutter_test/flutter_test.dart';

import 'package:gym_log/models/set_entry.dart';
import 'package:gym_log/utils/metrics_calculator.dart';
import 'package:gym_log/utils/unit_converter.dart';
import 'package:gym_log/utils/weight_calculator.dart';

SetEntry _set(double total, int reps, {bool warmup = false}) => SetEntry(
      setNumber: 1,
      weightInput: total,
      weightTotal: total,
      reps: reps,
      isWarmup: warmup,
    );

void main() {
  group('deriveTotal', () {
    test('barbell and smith: per-side ×2 + bar', () {
      expect(deriveTotal('barbell', 40, 20), 100);
      expect(deriveTotal('smith', 10, 15), 35);
    });

    test('barbell falls back to a 20 kg bar', () {
      expect(deriveTotal('barbell', 40, null), 100);
    });

    test('dumbbell: per-dumbbell ×2', () {
      expect(deriveTotal('dumbbell', 25, null), 50);
    });

    test('machine, bodyweight and unknown: input as-is', () {
      expect(deriveTotal('machine', 70, null), 70);
      expect(deriveTotal('bodyweight', 10, null), 10);
      expect(deriveTotal('kettlebell', 16, null), 16);
    });
  });

  group('labels follow the unit setting', () {
    test('weightInputLabel', () {
      expect(weightInputLabel('barbell'), 'kg per side');
      expect(weightInputLabel('barbell', useLbs: true), 'lbs per side');
      expect(weightInputLabel('machine', useLbs: true), 'stack weight (lbs)');
    });

    test('weightColumnLabel', () {
      expect(weightColumnLabel('barbell'), 'KG / SIDE');
      expect(weightColumnLabel('dumbbell', useLbs: true), 'LBS / DB');
      expect(weightColumnLabel('bodyweight'), '+KG');
      expect(weightColumnLabel('machine'), 'KG');
    });

    test('weightEntryHint converts the bar weight', () {
      expect(weightEntryHint('barbell', 20), 'Enter kg per side — the 20 kg bar is added for you');
      expect(weightEntryHint('barbell', 20, useLbs: true),
          'Enter lbs per side — the 44.1 lbs bar is added for you');
    });
  });

  group('unit conversion', () {
    test('round-trips kg ↔ lbs', () {
      expect(fromDisplayWeight(toDisplayWeight(100, true), true), closeTo(100, 1e-9));
      expect(toDisplayWeight(100, false), 100);
    });

    test('formatWeight', () {
      expect(formatWeight(100, false), '100.0 kg');
      expect(formatWeight(100, true), '220.5 lbs');
    });
  });

  group('metrics', () {
    test('estimated1RM uses Epley and is 0 for no reps', () {
      expect(estimated1RM(100, 30), 200);
      expect(estimated1RM(100, 0), 0);
    });

    test('empty lists produce 0', () {
      expect(topSetWeight([]), 0);
      expect(best1RMFromSets([]), 0);
      expect(totalVolume([]), 0);
      expect(bestRepsAtWeight([], 100), 0);
    });

    test('workingSets drops warmups', () {
      final sets = [_set(60, 10, warmup: true), _set(100, 5)];
      expect(workingSets(sets), [sets[1]]);
    });

    test('topSetWeight, totalVolume, bestRepsAtWeight', () {
      final sets = [_set(100, 5), _set(110, 3), _set(110, 4)];
      expect(topSetWeight(sets), 110);
      expect(totalVolume(sets), 100 * 5 + 110 * 3 + 110 * 4);
      expect(bestRepsAtWeight(sets, 110), 4);
    });
  });
}
