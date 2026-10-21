import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/set_entry.dart';
import '../../models/session_exercise.dart';
import '../../repositories/session_repository.dart';
import '../../utils/weight_calculator.dart';
import '../../utils/metrics_calculator.dart';

part 'exercise_logger_event.dart';
part 'exercise_logger_state.dart';

class ExerciseLoggerBloc extends Bloc<ExerciseLoggerEvent, ExerciseLoggerState> {
  final SessionRepository _repo;
  final String _uid;
  final String _sessionId;
  final String _sessionExerciseId;
  final String _exerciseId;
  final String _equipmentType;
  final double? _barWeightKg;

  /// Debounce timers for Firestore writes triggered by text input. Sets and
  /// notes write different fields, so they get separate timers — sharing one
  /// would let a notes keystroke cancel a pending sets write (and vice versa).
  Timer? _setsDebounce;
  Timer? _notesDebounce;

  /// Payloads of the pending debounced writes, flushed on [close].
  List<SetEntry>? _pendingSets;
  String? _pendingNotes;

  /// Cached PR history so we don't re-fetch on every keystroke.
  List<SetEntry>? _cachedHistorySets;

  ExerciseLoggerBloc({
    required SessionRepository repo,
    required String uid,
    required String sessionId,
    required String sessionExerciseId,
    required String exerciseId,
    required String equipmentType,
    double? barWeightKg,
  })  : _repo = repo,
        _uid = uid,
        _sessionId = sessionId,
        _sessionExerciseId = sessionExerciseId,
        _exerciseId = exerciseId,
        _equipmentType = equipmentType,
        _barWeightKg = barWeightKg,
        super(ExerciseLoggerLoading()) {
    on<ExerciseLoggerOpened>(_onOpened);
    on<SetWeightChanged>(_onWeightChanged);
    on<SetRepsChanged>(_onRepsChanged);
    on<SetWarmupToggled>(_onWarmupToggled);
    on<SetDropsetToggled>(_onDropsetToggled);
    on<SetAdded>(_onSetAdded);
    on<SetRemoved>(_onSetRemoved);
    on<SetsSaved>(_onSetsSaved);
    on<PRNotificationShown>(_onPRNotificationShown);
    on<ExerciseNotesUpdated>(_onExerciseNotesUpdated);
    on<_PersistCompleted>(_onPersistCompleted);
    on<_PersistFailed>(_onPersistFailed);
  }

  @override
  Future<void> close() {
    // Leaving the screen within the debounce window must not drop the edit.
    if (_setsDebounce?.isActive ?? false) {
      _setsDebounce!.cancel();
      _repo
          .updateExerciseSets(_uid, _sessionId, _sessionExerciseId, _pendingSets!)
          .catchError((_) {});
    }
    if (_notesDebounce?.isActive ?? false) {
      _notesDebounce!.cancel();
      _repo
          .updateExerciseNotes(_uid, _sessionId, _sessionExerciseId, _pendingNotes!)
          .catchError((_) {});
    }
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // Opened
  // ---------------------------------------------------------------------------

  Future<void> _onOpened(
      ExerciseLoggerOpened event, Emitter<ExerciseLoggerState> emit) async {
    emit(ExerciseLoggerLoading());
    try {
      // Fetch the current exercise doc, ghost sets, and PR history in parallel.
      final results = await Future.wait([
        _repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId),
        _repo.getLastSessionSets(_uid, _exerciseId),
        _repo.getAllSessionExercisesForExercise(_uid, _exerciseId),
      ]);

      final currentExercise = results[0] as SessionExercise?;
      final ghostSets = results[1] as List<SetEntry>;
      final history = results[2] as List<SessionExercise>;
      _cachedHistorySets = workingSets(history.expand((e) => e.sets).toList());

      // Priority: already-saved sets > pre-fill from ghost sets > blank set.
      final List<SetEntry> currentSets;
      if (currentExercise != null && currentExercise.sets.isNotEmpty) {
        currentSets = currentExercise.sets;
      } else if (ghostSets.isNotEmpty) {
        currentSets =
            ghostSets.map((s) => s.copyWith(setNumber: s.setNumber)).toList();
      } else {
        currentSets = [
          SetEntry(
            setNumber: 1,
            weightInput: 0,
            weightTotal: deriveTotal(_equipmentType, 0, _barWeightKg),
            reps: 0,
          )
        ];
      }

      final prFlags = _computePRFlagsSync(currentSets);

      emit(ExerciseLoggerReady(
        ghostSets: ghostSets,
        currentSets: currentSets,
        prFlags: prFlags,
        notes: currentExercise?.notes ?? '',
      ));
    } catch (e) {
      emit(ExerciseLoggerError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Weight changed — optimistic emit, debounced persist
  // ---------------------------------------------------------------------------

  Future<void> _onWeightChanged(
      SetWeightChanged event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady) return;

    final updated = List<SetEntry>.from(current.currentSets);
    final total = deriveTotal(_equipmentType, event.value, _barWeightKg);
    updated[event.setIndex] =
        updated[event.setIndex].copyWith(weightInput: event.value, weightTotal: total);
    final prFlags = _computePRFlagsSync(updated);

    // Detect a new PR only when triggered by user input.
    final hadPR = current.prFlags.any((f) => f);
    final hasPR = prFlags.any((f) => f);
    final newPR = hasPR && !hadPR;

    // Emit immediately — no spinner, no waiting.
    emit(current.copyWith(currentSets: updated, prFlags: prFlags, newPRDetected: newPR));

    _schedulePersist(updated);
  }

  // ---------------------------------------------------------------------------
  // Reps changed — optimistic emit, debounced persist
  // ---------------------------------------------------------------------------

  Future<void> _onRepsChanged(
      SetRepsChanged event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady) return;

    final updated = List<SetEntry>.from(current.currentSets);
    updated[event.setIndex] =
        updated[event.setIndex].copyWith(reps: event.reps);
    final prFlags = _computePRFlagsSync(updated);

    final hadPR = current.prFlags.any((f) => f);
    final hasPR = prFlags.any((f) => f);
    final newPR = hasPR && !hadPR;

    emit(current.copyWith(currentSets: updated, prFlags: prFlags, newPRDetected: newPR));

    _schedulePersist(updated);
  }

  // ---------------------------------------------------------------------------
  // Warmup / Dropset toggles — optimistic emit, immediate persist
  // ---------------------------------------------------------------------------

  Future<void> _onWarmupToggled(
      SetWarmupToggled event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady) return;

    final updated = List<SetEntry>.from(current.currentSets);
    updated[event.setIndex] =
        updated[event.setIndex].copyWith(isWarmup: !updated[event.setIndex].isWarmup);

    // Warmups don't count toward PRs, so the flags change with the toggle.
    emit(current.copyWith(
      currentSets: updated,
      prFlags: _computePRFlagsSync(updated),
      isSaving: true,
    ));
    await _persistNow(updated, current);
  }

  Future<void> _onDropsetToggled(
      SetDropsetToggled event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady) return;

    final updated = List<SetEntry>.from(current.currentSets);
    updated[event.setIndex] =
        updated[event.setIndex].copyWith(isDropset: !updated[event.setIndex].isDropset);

    emit(current.copyWith(currentSets: updated, isSaving: true));
    await _persistNow(updated, current);
  }

  // ---------------------------------------------------------------------------
  // Set added / removed — optimistic emit, immediate persist
  // ---------------------------------------------------------------------------

  Future<void> _onSetAdded(
      SetAdded event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady) return;

    final last = current.currentSets.isNotEmpty ? current.currentSets.last : null;
    final newSet = SetEntry(
      setNumber: current.currentSets.length + 1,
      weightInput: last?.weightInput ?? 0,
      weightTotal:
          last?.weightTotal ?? deriveTotal(_equipmentType, 0, _barWeightKg),
      reps: last?.reps ?? 0,
    );
    final updated = [...current.currentSets, newSet];

    emit(current.copyWith(
      currentSets: updated,
      prFlags: [...current.prFlags, false],
      isSaving: true,
    ));
    await _persistNow(updated, current);
  }

  Future<void> _onSetRemoved(
      SetRemoved event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady || current.currentSets.length <= 1) return;

    final updated = List<SetEntry>.from(current.currentSets)
      ..removeAt(event.setIndex);
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(setNumber: i + 1);
    }
    final prFlags = List<bool>.from(current.prFlags)..removeAt(event.setIndex);

    emit(current.copyWith(currentSets: updated, prFlags: prFlags, isSaving: true));
    await _persistNow(updated, current);
  }

  // ---------------------------------------------------------------------------
  // Save Sets — flush debounce, final persist, emit saved
  // ---------------------------------------------------------------------------

  Future<void> _onSetsSaved(
      SetsSaved event, Emitter<ExerciseLoggerState> emit) async {
    final current = state;
    if (current is! ExerciseLoggerReady) return;

    // Cancel any pending debounced write — we're about to do a final one.
    _setsDebounce?.cancel();

    emit(current.copyWith(isSaving: true));
    try {
      await _repo.updateExerciseSets(
          _uid, _sessionId, _sessionExerciseId, current.currentSets);
      emit(ExerciseLoggerSaved(current.currentSets));
    } catch (e) {
      emit(ExerciseLoggerError(e.toString(), previousState: current.copyWith(isSaving: false)));
    }
  }

  // ---------------------------------------------------------------------------
  // Exercise notes updated — optimistic emit, debounced persist
  // ---------------------------------------------------------------------------

  void _onExerciseNotesUpdated(
      ExerciseNotesUpdated event, Emitter<ExerciseLoggerState> emit) {
    final current = state;
    if (current is! ExerciseLoggerReady) return;
    emit(current.copyWith(notes: event.notes));
    // Debounce the Firestore write so we don't write on every keystroke.
    _pendingNotes = event.notes;
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 600), () {
      _repo
          .updateExerciseNotes(_uid, _sessionId, _sessionExerciseId, event.notes)
          .catchError((_) {}); // notes are non-critical; swallow errors silently
    });
  }

  // ---------------------------------------------------------------------------
  // PR notification acknowledged — reset the flag
  // ---------------------------------------------------------------------------

  void _onPRNotificationShown(
      PRNotificationShown event, Emitter<ExerciseLoggerState> emit) {
    final current = state;
    if (current is ExerciseLoggerReady) {
      emit(current.copyWith(newPRDetected: false));
    }
  }

  // ---------------------------------------------------------------------------
  // Internal persist-result events (fired from background callbacks)
  // ---------------------------------------------------------------------------

  void _onPersistCompleted(
      _PersistCompleted event, Emitter<ExerciseLoggerState> emit) {
    final current = state;
    if (current is ExerciseLoggerReady) {
      emit(current.copyWith(isSaving: false));
    }
  }

  void _onPersistFailed(
      _PersistFailed event, Emitter<ExerciseLoggerState> emit) {
    final current = state;
    if (current is ExerciseLoggerReady) {
      emit(ExerciseLoggerError(
        event.message,
        previousState: current.copyWith(isSaving: false),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Debounce text-input persists by 600 ms to avoid a Firestore write per keystroke.
  void _schedulePersist(List<SetEntry> sets) {
    _pendingSets = sets;
    _setsDebounce?.cancel();
    _setsDebounce = Timer(const Duration(milliseconds: 600), () {
      _repo
          .updateExerciseSets(_uid, _sessionId, _sessionExerciseId, sets)
          .then((_) => _addIfOpen(const _PersistCompleted()))
          .catchError((e) => _addIfOpen(_PersistFailed(e.toString())));
    });
  }

  /// Immediate persist used for structural changes (add/remove/toggle).
  Future<void> _persistNow(
      List<SetEntry> sets, ExerciseLoggerReady previousReady) async {
    // [sets] already includes any pending text edits; a debounced write firing
    // after this one would overwrite it with an older list.
    _setsDebounce?.cancel();
    try {
      await _repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, sets);
      _addIfOpen(const _PersistCompleted());
    } catch (e) {
      _addIfOpen(_PersistFailed(e.toString()));
    }
  }

  /// Writes can complete after the screen has closed the bloc.
  void _addIfOpen(ExerciseLoggerEvent event) {
    if (!isClosed) add(event);
  }

  /// Synchronous PR computation using the cached history — no async Firestore call.
  List<bool> _computePRFlagsSync(List<SetEntry> sets) {
    final historySets = _cachedHistorySets;
    if (historySets == null || historySets.isEmpty) {
      return List.filled(sets.length, false);
    }
    final histBest1RM = best1RMFromSets(historySets);
    final histHeaviest = topSetWeight(historySets);

    return sets.map((s) {
      if (s.isWarmup || s.weightTotal <= 0 || s.reps <= 0) return false;
      return estimated1RM(s.weightTotal, s.reps) > histBest1RM ||
          s.weightTotal > histHeaviest;
    }).toList();
  }
}
