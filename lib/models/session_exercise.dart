import 'package:equatable/equatable.dart';
import 'set_entry.dart';

class SessionExercise extends Equatable {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String equipmentType;
  final double? barWeightKg;
  final int orderIndex;
  final String notes;
  final List<SetEntry> sets;

  const SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.equipmentType,
    this.barWeightKg,
    required this.orderIndex,
    this.notes = '',
    this.sets = const [],
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'equipmentType': equipmentType,
        'barWeightKg': barWeightKg,
        'orderIndex': orderIndex,
        'notes': notes,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory SessionExercise.fromMap(String id, Map<String, dynamic> map) =>
      SessionExercise(
        id: id,
        exerciseId: map['exerciseId'] as String,
        exerciseName: map['exerciseName'] as String,
        equipmentType: map['equipmentType'] as String,
        barWeightKg: (map['barWeightKg'] as num?)?.toDouble(),
        orderIndex: (map['orderIndex'] as num).toInt(),
        notes: map['notes'] as String? ?? '',
        sets: (map['sets'] as List<dynamic>? ?? [])
            .map((s) => SetEntry.fromMap(s as Map<String, dynamic>))
            .toList(),
      );

  SessionExercise copyWith({
    List<SetEntry>? sets,
    String? notes,
  }) =>
      SessionExercise(
        id: id,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        equipmentType: equipmentType,
        barWeightKg: barWeightKg,
        orderIndex: orderIndex,
        notes: notes ?? this.notes,
        sets: sets ?? this.sets,
      );

  @override
  List<Object?> get props =>
      [id, exerciseId, exerciseName, equipmentType, barWeightKg, orderIndex, notes, sets];
}
