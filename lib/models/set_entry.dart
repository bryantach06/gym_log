import 'package:equatable/equatable.dart';

class SetEntry extends Equatable {
  final int setNumber;
  final double weightInput;
  final double weightTotal;
  final int reps;
  final bool isWarmup;
  final bool isDropset;

  const SetEntry({
    required this.setNumber,
    required this.weightInput,
    required this.weightTotal,
    required this.reps,
    this.isWarmup = false,
    this.isDropset = false,
  });

  Map<String, dynamic> toMap() => {
        'setNumber': setNumber,
        'weightInput': weightInput,
        'weightTotal': weightTotal,
        'reps': reps,
        'isWarmup': isWarmup,
        'isDropset': isDropset,
      };

  factory SetEntry.fromMap(Map<String, dynamic> map) => SetEntry(
        setNumber: (map['setNumber'] as num).toInt(),
        weightInput: (map['weightInput'] as num).toDouble(),
        weightTotal: (map['weightTotal'] as num).toDouble(),
        reps: (map['reps'] as num).toInt(),
        isWarmup: map['isWarmup'] as bool? ?? false,
        isDropset: map['isDropset'] as bool? ?? false,
      );

  SetEntry copyWith({
    int? setNumber,
    double? weightInput,
    double? weightTotal,
    int? reps,
    bool? isWarmup,
    bool? isDropset,
  }) =>
      SetEntry(
        setNumber: setNumber ?? this.setNumber,
        weightInput: weightInput ?? this.weightInput,
        weightTotal: weightTotal ?? this.weightTotal,
        reps: reps ?? this.reps,
        isWarmup: isWarmup ?? this.isWarmup,
        isDropset: isDropset ?? this.isDropset,
      );

  @override
  List<Object?> get props =>
      [setNumber, weightInput, weightTotal, reps, isWarmup, isDropset];
}
