import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise extends Equatable {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipmentType;
  final double? barWeightKg;
  final bool isCustom;
  final DateTime createdAt;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipmentType,
    this.barWeightKg,
    required this.isCustom,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'muscleGroup': muscleGroup,
        'equipmentType': equipmentType,
        'barWeightKg': barWeightKg,
        'isCustom': isCustom,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Exercise.fromMap(String id, Map<String, dynamic> map) => Exercise(
        id: id,
        name: map['name'] as String,
        muscleGroup: map['muscleGroup'] as String,
        equipmentType: map['equipmentType'] as String,
        barWeightKg: (map['barWeightKg'] as num?)?.toDouble(),
        isCustom: map['isCustom'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: '',
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
        equipmentType: json['equipmentType'] as String,
        barWeightKg: (json['barWeightKg'] as num?)?.toDouble(),
        isCustom: json['isCustom'] as bool? ?? false,
        createdAt: DateTime.now(),
      );

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipmentType,
    double? barWeightKg,
    bool? isCustom,
    DateTime? createdAt,
    bool clearBarWeight = false,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        muscleGroup: muscleGroup ?? this.muscleGroup,
        equipmentType: equipmentType ?? this.equipmentType,
        barWeightKg: clearBarWeight ? null : (barWeightKg ?? this.barWeightKg),
        isCustom: isCustom ?? this.isCustom,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props =>
      [id, name, muscleGroup, equipmentType, barWeightKg, isCustom];
}
