import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../models/session_exercise.dart';
import '../../models/set_entry.dart';
import '../../models/pr_data.dart';
import '../../repositories/session_repository.dart';

part 'session_event.dart';
part 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionRepository _repo;
  final String _uid;

  SessionBloc(this._repo, this._uid) : super(SessionInitial()) {
    on<SessionStarted>(_onStarted);
    on<SessionResumed>(_onResumed);
    on<SessionExerciseAdded>(_onExerciseAdded);
    on<SessionFinished>(_onFinished);
    on<SessionDiscarded>(_onDiscarded);
    on<SessionExerciseSetsUpdated>(_onExerciseSetsUpdated);
    on<SessionNotesUpdated>(_onNotesUpdated);
  }

  Future<void> _onStarted(SessionStarted event, Emitter<SessionState> emit) async {
    // Guard: don't create a second session if one is already active or loading.
    if (state is SessionActive || state is SessionLoading) return;

    emit(SessionLoading());
    try {
      // Check for an existing draft first — avoids creating duplicates if the
      // user somehow triggers this while a draft already exists.
      final existing = await _repo.getDraftSession(_uid);
      if (existing != null) {
        final exercises = await _repo.getSessionExercises(_uid, existing.id);
        emit(SessionActive(session: existing, exercises: exercises, pendingPRs: const {}));
        return;
      }
      final session = await _repo.createSession(_uid);
      emit(SessionActive(session: session, exercises: const [], pendingPRs: const {}));
    } catch (e) {
      emit(SessionError(e.toString()));
      // Nothing was created; drop back so the session screen closes.
      emit(SessionInitial());
    }
  }

  Future<void> _onResumed(SessionResumed event, Emitter<SessionState> emit) async {
    // Already active — nothing to do.
    if (state is SessionActive) return;

    emit(SessionLoading());
    try {
      final snap = await _repo.getDraftSession(_uid);
      if (snap == null) {
        emit(SessionInitial());
        return;
      }
      final exercises = await _repo.getSessionExercises(_uid, snap.id);
      emit(SessionActive(session: snap, exercises: exercises, pendingPRs: const {}));
    } catch (e) {
      // Firestore offline: persistence is enabled so the query may still
      // succeed from cache. If it truly fails, fall back to SessionInitial
      // so the UI isn't stuck on a spinner.
      emit(SessionInitial());
    }
  }

  Future<void> _onExerciseAdded(SessionExerciseAdded event, Emitter<SessionState> emit) async {
    final current = state;
    if (current is! SessionActive) return;

    // Enforce a maximum of 10 exercises per session.
    if (current.exercises.length >= 10) return;

    final ex = SessionExercise(
      id: '',
      exerciseId: event.exercise.id,
      exerciseName: event.exercise.name,
      equipmentType: event.exercise.equipmentType,
      barWeightKg: event.exercise.barWeightKg,
      orderIndex: current.exercises.length,
    );
    try {
      final saved = await _repo.addExerciseToSession(
        _uid,
        current.session.id,
        ex,
        sessionStartedAt: current.session.startedAt,
      );
      // Re-read state: notes may have been edited while the write was in flight.
      // Skip if the session was finished/discarded meanwhile.
      final latest = state;
      if (latest is! SessionActive) return;
      emit(SessionActive(
        session: latest.session,
        exercises: [...latest.exercises, saved],
        pendingPRs: latest.pendingPRs,
      ));
    } catch (e) {
      _reportAndRestore(emit, e, current);
    }
  }

  Future<void> _onFinished(SessionFinished event, Emitter<SessionState> emit) async {
    final current = state;
    if (current is! SessionActive) return;
    emit(SessionFinishing());
    try {
      await _repo.finishSession(_uid, current.session.id);
      emit(SessionComplete());
    } catch (e) {
      _reportAndRestore(emit, e, current);
    }
  }

  Future<void> _onDiscarded(SessionDiscarded event, Emitter<SessionState> emit) async {
    final current = state;
    if (current is! SessionActive) return;
    try {
      await _repo.discardSession(_uid, current.session.id);
      emit(SessionInitial());
    } catch (e) {
      _reportAndRestore(emit, e, current);
    }
  }

  void _onExerciseSetsUpdated(
      SessionExerciseSetsUpdated event, Emitter<SessionState> emit) {
    final current = state;
    if (current is! SessionActive) return;
    final updatedExercises = current.exercises.map((ex) {
      if (ex.id == event.sessionExerciseId) {
        return ex.copyWith(sets: event.sets);
      }
      return ex;
    }).toList();
    emit(SessionActive(
      session: current.session,
      exercises: updatedExercises,
      pendingPRs: current.pendingPRs,
    ));
  }

  Future<void> _onNotesUpdated(
      SessionNotesUpdated event, Emitter<SessionState> emit) async {
    final current = state;
    if (current is! SessionActive) return;
    // Optimistic update — persist in background.
    final updatedSession = current.session.copyWith(notes: event.notes);
    emit(SessionActive(
      session: updatedSession,
      exercises: current.exercises,
      pendingPRs: current.pendingPRs,
    ));
    try {
      await _repo.updateSessionNotes(_uid, current.session.id, event.notes);
    } catch (_) {
      // Silently ignore — notes are non-critical; the in-memory state is still updated.
    }
  }

  /// Emits [SessionError] for the UI to report, then puts the workout back so
  /// the session screen doesn't sit on a spinner and the user can retry.
  void _reportAndRestore(
      Emitter<SessionState> emit, Object error, SessionActive fallback) {
    final latest = state;
    emit(SessionError(error.toString()));
    emit(latest is SessionActive ? latest : fallback);
  }
}
