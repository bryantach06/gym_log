import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_session.dart';
import '../models/session_exercise.dart';
import '../models/set_entry.dart';
import '../utils/metrics_calculator.dart';

/// Fields copied from the parent session onto each session-exercise doc so the
/// history queries can run as a single collection-group query scoped to the
/// user (which is also what the security rules check).
const _kUid = 'uid';
const _kSessionStatus = 'sessionStatus';
const _kSessionStartedAt = 'sessionStartedAt';

/// Bumped when the denormalized fields above change; see [SessionRepository.backfillExerciseMetadata].
const _kMetaVersionField = 'exerciseMetaVersion';
const _kMetaVersion = 2; // 1: exercise-doc fields, 2: finished-session summary

class SessionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  CollectionReference<Map<String, dynamic>> _exercises(String uid, String sessionId) =>
      _sessions(uid).doc(sessionId).collection('exercises');

  // ---------------------------------------------------------------------------
  // Session CRUD
  // ---------------------------------------------------------------------------

  Future<WorkoutSession> createSession(String uid) async {
    final now = DateTime.now();
    final data = WorkoutSession(
      id: '',
      startedAt: now,
      status: 'draft',
    ).toMap();
    final ref = await _sessions(uid).add(data);
    return WorkoutSession(id: ref.id, startedAt: now, status: 'draft');
  }

  Future<WorkoutSession?> getDraftSession(String uid) async {
    final snap = await _sessions(uid)
        .where('status', isEqualTo: 'draft')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return WorkoutSession.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<void> finishSession(String uid, String sessionId) async {
    final exSnap = await _exercises(uid, sessionId).get();
    final exercises = exSnap.docs
        .map((d) => SessionExercise.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final working = exercises.expand((e) => workingSets(e.sets)).toList();

    final batch = _db.batch();
    batch.update(_sessions(uid).doc(sessionId), {
      'status': 'finished',
      'finishedAt': Timestamp.fromDate(DateTime.now()),
      'exerciseNames': exercises.map((e) => e.exerciseName).toList(),
      'workingSetCount': working.length,
      'volumeKg': totalVolume(working),
    });
    for (final d in exSnap.docs) {
      batch.update(d.reference, {_kSessionStatus: 'finished'});
    }
    await batch.commit();
  }

  Future<void> updateSessionNotes(String uid, String sessionId, String notes) async {
    await _sessions(uid).doc(sessionId).update({'notes': notes});
  }

  /// Deletes a session and all its exercise sub-documents.
  /// Splits into chunks of 500 to stay within Firestore batch limits.
  Future<void> discardSession(String uid, String sessionId) async {
    final exSnap = await _exercises(uid, sessionId).get();
    final allRefs = [
      ...exSnap.docs.map((d) => d.reference),
      _sessions(uid).doc(sessionId),
    ];

    const chunkSize = 500;
    for (var i = 0; i < allRefs.length; i += chunkSize) {
      final batch = _db.batch();
      final chunk = allRefs.skip(i).take(chunkSize);
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Returns one page of finished sessions, newest first, plus the cursor to
  /// pass as [startAfter] for the next page.
  Future<({List<WorkoutSession> sessions, DocumentSnapshot? lastDoc})>
      getFinishedSessions(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    var query = _sessions(uid)
        .where('status', isEqualTo: 'finished')
        .orderBy('startedAt', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.get();
    return (
      sessions: snap.docs.map((d) => WorkoutSession.fromMap(d.id, d.data())).toList(),
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
    );
  }

  // ---------------------------------------------------------------------------
  // Session exercises
  // ---------------------------------------------------------------------------

  Future<List<SessionExercise>> getSessionExercises(String uid, String sessionId) async {
    final snap = await _exercises(uid, sessionId).orderBy('orderIndex').get();
    return snap.docs.map((d) => SessionExercise.fromMap(d.id, d.data())).toList();
  }

  Future<SessionExercise> addExerciseToSession(
      String uid, String sessionId, SessionExercise ex,
      {required DateTime sessionStartedAt}) async {
    final ref = await _exercises(uid, sessionId).add({
      ...ex.toMap(),
      _kUid: uid,
      _kSessionStatus: 'draft',
      _kSessionStartedAt: Timestamp.fromDate(sessionStartedAt),
    });
    return SessionExercise(
      id: ref.id,
      exerciseId: ex.exerciseId,
      exerciseName: ex.exerciseName,
      equipmentType: ex.equipmentType,
      barWeightKg: ex.barWeightKg,
      orderIndex: ex.orderIndex,
      sets: ex.sets,
    );
  }

  Future<void> updateExerciseSets(
      String uid, String sessionId, String sessionExerciseId, List<SetEntry> sets) async {
    await _exercises(uid, sessionId).doc(sessionExerciseId).update({
      'sets': sets.map((s) => s.toMap()).toList(),
    });
  }

  Future<void> updateExerciseNotes(
      String uid, String sessionId, String sessionExerciseId, String notes) async {
    await _exercises(uid, sessionId).doc(sessionExerciseId).update({'notes': notes});
  }

  Future<SessionExercise?> getSessionExercise(
      String uid, String sessionId, String sessionExerciseId) async {
    final doc = await _exercises(uid, sessionId).doc(sessionExerciseId).get();
    if (!doc.exists) return null;
    return SessionExercise.fromMap(doc.id, doc.data()!);
  }

  // ---------------------------------------------------------------------------
  // History queries (ghost rows, PRs, progression)
  //
  // A single collectionGroup query over the denormalized fields. Requires the
  // composite index in firestore.indexes.json:
  //   collectionGroup: exercises | uid, exerciseId, sessionStatus ASC, sessionStartedAt DESC
  // ---------------------------------------------------------------------------

  Query<Map<String, dynamic>> _finishedEntries(String uid, String exerciseId) => _db
      .collectionGroup('exercises')
      .where(_kUid, isEqualTo: uid)
      .where('exerciseId', isEqualTo: exerciseId)
      .where(_kSessionStatus, isEqualTo: 'finished')
      .orderBy(_kSessionStartedAt, descending: true);

  /// Sets from the most recent finished session containing [exerciseId].
  Future<List<SetEntry>> getLastSessionSets(String uid, String exerciseId) async {
    final snap = await _finishedEntries(uid, exerciseId).limit(1).get();
    if (snap.docs.isEmpty) return [];
    return SessionExercise.fromMap(snap.docs.first.id, snap.docs.first.data()).sets;
  }

  Future<List<SessionExercise>> getAllSessionExercisesForExercise(
      String uid, String exerciseId) async {
    final result = await getAllSessionExercisesWithDates(uid, exerciseId);
    return result.map((e) => e.$1).toList();
  }

  /// Returns (SessionExercise, sessionDate) pairs sorted oldest-first.
  Future<List<(SessionExercise, DateTime)>> getAllSessionExercisesWithDates(
      String uid, String exerciseId) async {
    final snap = await _finishedEntries(uid, exerciseId).get();
    // The index is newest-first; reverse so the chart reads left-to-right.
    return snap.docs.reversed
        .map((d) => (
              SessionExercise.fromMap(d.id, d.data()),
              (d.data()[_kSessionStartedAt] as Timestamp).toDate(),
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // One-time migration
  // ---------------------------------------------------------------------------

  /// Migrates data written by older app versions:
  /// - copies uid / session status / session start onto session-exercise docs
  ///   so they show up in history queries;
  /// - writes the list summary (`exerciseNames` etc.) onto finished sessions.
  /// Idempotent; a version marker on users/{uid} makes repeat calls one read.
  Future<void> backfillExerciseMetadata(String uid) async {
    final userDoc = _db.collection('users').doc(uid);
    final marker = await userDoc.get();
    if (((marker.data()?[_kMetaVersionField] as num?) ?? 0) >= _kMetaVersion) return;

    final sessions = await _sessions(uid).get();
    final updates = <(DocumentReference, Map<String, dynamic>)>[];
    for (final session in sessions.docs) {
      final data = session.data();
      final exercises = await _exercises(uid, session.id).get();
      for (final ex in exercises.docs) {
        updates.add((ex.reference, {
          _kUid: uid,
          _kSessionStatus: data['status'],
          _kSessionStartedAt: data['startedAt'],
        }));
      }
      if (data['status'] == 'finished' && data['exerciseNames'] == null) {
        final parsed = exercises.docs
            .map((d) => SessionExercise.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final working = parsed.expand((e) => workingSets(e.sets)).toList();
        updates.add((session.reference, {
          'exerciseNames': parsed.map((e) => e.exerciseName).toList(),
          'workingSetCount': working.length,
          'volumeKg': totalVolume(working),
        }));
      }
    }

    const chunkSize = 500;
    for (var i = 0; i < updates.length; i += chunkSize) {
      final batch = _db.batch();
      for (final (ref, fields) in updates.skip(i).take(chunkSize)) {
        batch.update(ref, fields);
      }
      await batch.commit();
    }
    await userDoc.set({_kMetaVersionField: _kMetaVersion}, SetOptions(merge: true));
  }
}
