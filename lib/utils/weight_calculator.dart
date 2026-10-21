import 'unit_converter.dart';

double deriveTotal(String equipmentType, double weightInput, double? barWeightKg) {
  switch (equipmentType) {
    case 'barbell':
    case 'smith':
      return (weightInput * 2) + (barWeightKg ?? 20);
    case 'dumbbell':
      return weightInput * 2;
    case 'machine':
    case 'bodyweight':
    default:
      return weightInput;
  }
}

String weightInputLabel(String equipmentType, {bool useLbs = false}) {
  final unit = unitLabel(useLbs);
  switch (equipmentType) {
    case 'barbell':
    case 'smith':
      return '$unit per side';
    case 'dumbbell':
      return '$unit per dumbbell';
    case 'machine':
      return 'stack weight ($unit)';
    case 'bodyweight':
      return 'added weight ($unit)';
    default:
      return 'weight ($unit)';
  }
}

/// Short uppercase header for the weight column in the set table.
String weightColumnLabel(String equipmentType, {bool useLbs = false}) {
  final unit = unitLabel(useLbs).toUpperCase();
  switch (equipmentType) {
    case 'barbell':
    case 'smith':
      return '$unit / SIDE';
    case 'dumbbell':
      return '$unit / DB';
    case 'bodyweight':
      return '+$unit';
    default:
      return unit;
  }
}

/// One-line explanation of what to enter, e.g.
/// "Enter kg per side — the 20 kg bar is added for you".
String weightEntryHint(String equipmentType, double? barWeightKg, {bool useLbs = false}) {
  final unit = unitLabel(useLbs);
  switch (equipmentType) {
    case 'barbell':
    case 'smith':
      final bar = toDisplayWeight(barWeightKg ?? 20, useLbs);
      final barText = bar == bar.truncateToDouble() ? bar.toInt().toString() : bar.toStringAsFixed(1);
      return 'Enter $unit per side — the $barText $unit bar is added for you';
    case 'dumbbell':
      return 'Enter $unit per dumbbell — totals count both';
    case 'bodyweight':
      return 'Enter added weight only ($unit)';
    default:
      return 'Enter the stack weight ($unit)';
  }
}

/// Whether the logged input differs from the total (so the total is worth showing).
bool hasDerivedTotal(String equipmentType) =>
    const {'barbell', 'smith', 'dumbbell'}.contains(equipmentType);
