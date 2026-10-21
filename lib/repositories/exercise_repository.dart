import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise.dart';

class ExerciseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('exercises');

  Future<List<Exercise>> getExercises(String uid) async {
    final snap = await _col(uid).orderBy('name').get();
    return snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList();
  }

  Future<void> seedIfEmpty(String uid) async {
    final snap = await _col(uid).limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
    final batch = _db.batch();
    for (final item in list) {
      final ref = _col(uid).doc();
      final ex = Exercise.fromJson(item as Map<String, dynamic>);
      batch.set(ref, ex.toMap());
    }
    await batch.commit();
  }

  Future<Exercise> addExercise(String uid, Exercise exercise) async {
    final ref = await _col(uid).add(exercise.toMap());
    return exercise.copyWith(id: ref.id);
  }

  Future<void> updateExercise(String uid, Exercise exercise) async {
    await _col(uid).doc(exercise.id).update(exercise.toMap());
  }

  Future<void> deleteExercise(String uid, String exerciseId) async {
    await _col(uid).doc(exerciseId).delete();
  }
}
