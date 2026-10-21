import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutSession extends Equatable {
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status; // 'draft' | 'finished'
  final String notes;

  /// Summary written by `SessionRepository.finishSession` so list views can
  /// show what was trained without loading each session's exercises.
  /// Empty / null for drafts and sessions finished before it existed.
  final List<String> exerciseNames;
  final int? workingSetCount;
  final double? volumeKg;

  const WorkoutSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.notes = '',
    this.exerciseNames = const [],
    this.workingSetCount,
    this.volumeKg,
  });

  bool get isDraft => status == 'draft';

  Duration? get duration => finishedAt?.difference(startedAt);

  Map<String, dynamic> toMap() => {
        'startedAt': Timestamp.fromDate(startedAt),
        'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
        'status': status,
        'notes': notes,
        'exerciseNames': exerciseNames,
        'workingSetCount': workingSetCount,
        'volumeKg': volumeKg,
      };

  factory WorkoutSession.fromMap(String id, Map<String, dynamic> map) =>
      WorkoutSession(
        id: id,
        startedAt: (map['startedAt'] as Timestamp).toDate(),
        finishedAt: (map['finishedAt'] as Timestamp?)?.toDate(),
        status: map['status'] as String? ?? 'draft',
        notes: map['notes'] as String? ?? '',
        exerciseNames: (map['exerciseNames'] as List<dynamic>? ?? []).cast<String>(),
        workingSetCount: (map['workingSetCount'] as num?)?.toInt(),
        volumeKg: (map['volumeKg'] as num?)?.toDouble(),
      );

  WorkoutSession copyWith({
    DateTime? finishedAt,
    String? status,
    String? notes,
  }) =>
      WorkoutSession(
        id: id,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        exerciseNames: exerciseNames,
        workingSetCount: workingSetCount,
        volumeKg: volumeKg,
      );

  @override
  List<Object?> get props =>
      [id, startedAt, finishedAt, status, notes, exerciseNames, workingSetCount, volumeKg];
}
