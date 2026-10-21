import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gym_log/blocs/exercise_logger/exercise_logger_bloc.dart';
import 'package:gym_log/models/session_exercise.dart';
import 'package:gym_log/models/set_entry.dart';
import 'package:gym_log/repositories/session_repository.dart';

class MockSessionRepository extends Mock implements SessionRepository {}

class FakeSetEntry extends Fake implements SetEntry {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _uid = 'uid1';
const _sessionId = 'sess1';
const _sessionExerciseId = 'se1';
const _exerciseId = 'ex1';

SetEntry _set({
  int setNumber = 1,
  double weightInput = 50,
  double weightTotal = 100,
  int reps = 5,
  bool isWarmup = false,
  bool isDropset = false,
}) =>
    SetEntry(
      setNumber: setNumber,
      weightInput: weightInput,
      weightTotal: weightTotal,
      reps: reps,
      isWarmup: isWarmup,
      isDropset: isDropset,
    );

SessionExercise _sessionExercise({List<SetEntry> sets = const []}) => SessionExercise(
      id: _sessionExerciseId,
      exerciseId: _exerciseId,
      exerciseName: 'Squat',
      equipmentType: 'machine',
      orderIndex: 0,
      sets: sets,
    );

// Builds a bloc with a barbell setup (bar = 20 kg) unless overridden.
ExerciseLoggerBloc _bloc(
  MockSessionRepository repo, {
  String equipmentType = 'machine',
  double? barWeightKg,
}) =>
    ExerciseLoggerBloc(
      repo: repo,
      uid: _uid,
      sessionId: _sessionId,
      sessionExerciseId: _sessionExerciseId,
      exerciseId: _exerciseId,
      equipmentType: equipmentType,
      barWeightKg: barWeightKg,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockSessionRepository repo;

  setUpAll(() {
    registerFallbackValue(FakeSetEntry());
  });

  setUp(() {
    repo = MockSessionRepository();
    // Default: writes succeed. Closing the bloc flushes pending debounced
    // writes, so most tests hit these even without stubbing them explicitly.
    when(() => repo.updateExerciseSets(any(), any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => repo.updateExerciseNotes(any(), any(), any(), any()))
        .thenAnswer((_) async {});
  });

  // ── ExerciseLoggerOpened ──────────────────────────────────────────────────

  group('ExerciseLoggerOpened', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'emits [Loading, Ready] with existing sets when exercise already has sets',
      build: () => _bloc(repo),
      setUp: () {
        when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
            .thenAnswer((_) async => _sessionExercise(sets: [_set()]));
        when(() => repo.getLastSessionSets(_uid, _exerciseId))
            .thenAnswer((_) async => []);
        when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [
        isA<ExerciseLoggerLoading>(),
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.length, 'sets count', 1),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'pre-fills from ghost sets when exercise has no saved sets',
      build: () => _bloc(repo),
      setUp: () {
        when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
            .thenAnswer((_) async => _sessionExercise(sets: []));
        when(() => repo.getLastSessionSets(_uid, _exerciseId))
            .thenAnswer((_) async => [_set(setNumber: 1), _set(setNumber: 2)]);
        when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [
        isA<ExerciseLoggerLoading>(),
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.length, 'ghost count', 2)
            .having((s) => s.ghostSets.length, 'ghostSets preserved', 2),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'creates a single blank set when no saved sets and no ghost sets',
      build: () => _bloc(repo),
      setUp: () {
        when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
            .thenAnswer((_) async => null);
        when(() => repo.getLastSessionSets(_uid, _exerciseId))
            .thenAnswer((_) async => []);
        when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [
        isA<ExerciseLoggerLoading>(),
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.length, 'blank set', 1)
            .having((s) => s.currentSets.first.reps, 'reps zero', 0),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'emits [Loading, Error] on repository exception',
      build: () => _bloc(repo),
      setUp: () {
        when(() => repo.getSessionExercise(any(), any(), any()))
            .thenThrow(Exception('firestore down'));
        when(() => repo.getLastSessionSets(any(), any()))
            .thenAnswer((_) async => []);
        when(() => repo.getAllSessionExercisesForExercise(any(), any()))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [isA<ExerciseLoggerLoading>(), isA<ExerciseLoggerError>()],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'fetches all three repo calls in parallel (all called once)',
      build: () => _bloc(repo),
      setUp: () {
        when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
            .thenAnswer((_) async => null);
        when(() => repo.getLastSessionSets(_uid, _exerciseId))
            .thenAnswer((_) async => []);
        when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [isA<ExerciseLoggerLoading>(), isA<ExerciseLoggerReady>()],
      verify: (_) {
        verify(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId)).called(1);
        verify(() => repo.getLastSessionSets(_uid, _exerciseId)).called(1);
        verify(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId)).called(1);
      },
    );
  });

  // ── SetWeightChanged ──────────────────────────────────────────────────────

  group('SetWeightChanged', () {
    ExerciseLoggerReady readyState({List<SetEntry>? sets, List<bool>? prFlags}) =>
        ExerciseLoggerReady(
          ghostSets: const [],
          currentSets: sets ?? [_set()],
          prFlags: prFlags ?? [false],
        );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'updates weightInput and weightTotal for the given set index',
      build: () => _bloc(repo),
      seed: () => readyState(),
      act: (b) => b.add(const SetWeightChanged(0, 75)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets[0].weightInput, 'weightInput', 75.0)
            .having((s) => s.currentSets[0].weightTotal, 'weightTotal', 75.0),
        // _PersistCompleted may follow (debounced — won't fire in test)
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'computes barbell total correctly (input×2 + bar)',
      build: () => _bloc(repo, equipmentType: 'barbell', barWeightKg: 20),
      seed: () => readyState(),
      act: (b) => b.add(const SetWeightChanged(0, 60)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets[0].weightTotal, 'total', 140.0),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(const SetWeightChanged(0, 50)),
      expect: () => [],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'sets newPRDetected=true when weight exceeds history best',
      build: () => _bloc(repo),
      setUp: () {
        // Pre-populate history via Opened so _cachedHistorySets is set.
        // Opened will produce a blank set (reps=0, weight=0) from the ghost path.
        when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
            .thenAnswer((_) async => _sessionExercise(sets: []));
        when(() => repo.getLastSessionSets(_uid, _exerciseId))
            .thenAnswer((_) async => []);
        // History: one set at 100 kg total, 5 reps → 1RM ≈ 116.7
        when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
            .thenAnswer((_) async =>
                [_sessionExercise(sets: [_set(weightTotal: 100, reps: 5)])]);
      },
      act: (b) async {
        b.add(ExerciseLoggerOpened());
        await Future.delayed(Duration.zero);
        // Set reps first so the set is valid (reps > 0), then raise weight above history.
        b.add(const SetRepsChanged(0, 5));
        await Future.delayed(Duration.zero);
        // weightTotal = 200 (machine), 5 reps → 1RM ≈ 233 > 116.7
        b.add(const SetWeightChanged(0, 200));
      },
      skip: 3, // skip Loading + initial Ready from Opened + Ready from SetRepsChanged
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.newPRDetected, 'newPRDetected', true),
      ],
    );
  });

  // ── SetRepsChanged ────────────────────────────────────────────────────────

  group('SetRepsChanged', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'updates reps for the correct set index',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set(reps: 5), _set(setNumber: 2, reps: 5)],
        prFlags: [false, false],
      ),
      act: (b) => b.add(const SetRepsChanged(1, 10)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets[0].reps, 'set 0 unchanged', 5)
            .having((s) => s.currentSets[1].reps, 'set 1 updated', 10),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(const SetRepsChanged(0, 8)),
      expect: () => [],
    );
  });

  // ── SetWarmupToggled ──────────────────────────────────────────────────────

  group('SetWarmupToggled', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'flips isWarmup and persists immediately',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set(isWarmup: false)],
        prFlags: [false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(const SetWarmupToggled(0)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets[0].isWarmup, 'isWarmup toggled on', true)
            .having((s) => s.isSaving, 'isSaving true', true),
        isA<ExerciseLoggerReady>()
            .having((s) => s.isSaving, 'isSaving cleared', false),
      ],
      verify: (_) =>
          verify(() => repo.updateExerciseSets(any(), any(), any(), any())).called(1),
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'emits Error when persist fails',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: [false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenThrow(Exception('write error'));
      },
      act: (b) => b.add(const SetWarmupToggled(0)),
      expect: () => [
        isA<ExerciseLoggerReady>().having((s) => s.isSaving, 'isSaving', true),
        isA<ExerciseLoggerError>(),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(const SetWarmupToggled(0)),
      expect: () => [],
    );
  });

  // ── SetDropsetToggled ─────────────────────────────────────────────────────

  group('SetDropsetToggled', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'flips isDropset and persists immediately',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set(isDropset: false)],
        prFlags: [false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(const SetDropsetToggled(0)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets[0].isDropset, 'isDropset toggled on', true)
            .having((s) => s.isSaving, 'isSaving true', true),
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets[0].isDropset, 'isDropset still on', true)
            .having((s) => s.isSaving, 'isSaving cleared', false),
      ],
    );
  });

  // ── SetAdded ──────────────────────────────────────────────────────────────

  group('SetAdded', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'appends a new set copying weight/reps from last set',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set(weightInput: 80, weightTotal: 80, reps: 8)],
        prFlags: [false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(SetAdded()),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.length, 'count', 2)
            .having((s) => s.currentSets.last.weightInput, 'copied weight', 80.0)
            .having((s) => s.currentSets.last.reps, 'copied reps', 8)
            .having((s) => s.currentSets.last.setNumber, 'setNumber', 2),
        isA<ExerciseLoggerReady>()
            .having((s) => s.isSaving, 'isSaving cleared', false),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'new set gets setNumber = existing count + 1',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set(setNumber: 1), _set(setNumber: 2)],
        prFlags: [false, false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(SetAdded()),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.last.setNumber, 'setNumber', 3)
            .having((s) => s.isSaving, 'isSaving true', true),
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.last.setNumber, 'setNumber still 3', 3)
            .having((s) => s.isSaving, 'isSaving cleared', false),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(SetAdded()),
      expect: () => [],
    );
  });

  // ── SetRemoved ────────────────────────────────────────────────────────────

  group('SetRemoved', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'removes set at index and renumbers remaining sets',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [
          _set(setNumber: 1),
          _set(setNumber: 2),
          _set(setNumber: 3),
        ],
        prFlags: [false, false, false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(const SetRemoved(1)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.length, 'count', 2)
            .having((s) => s.currentSets.map((s) => s.setNumber).toList(),
                'renumbered', [1, 2])
            .having((s) => s.isSaving, 'isSaving true', true),
        isA<ExerciseLoggerReady>()
            .having((s) => s.currentSets.length, 'count still 2', 2)
            .having((s) => s.isSaving, 'isSaving cleared', false),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does not remove when only one set remains',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: [false],
      ),
      act: (b) => b.add(const SetRemoved(0)),
      expect: () => [],
      verify: (_) =>
          verifyNever(() => repo.updateExerciseSets(any(), any(), any(), any())),
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(const SetRemoved(0)),
      expect: () => [],
    );
  });

  // ── SetsSaved ─────────────────────────────────────────────────────────────

  group('SetsSaved', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'emits [Ready(isSaving=true), Saved] on success',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: [false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(SetsSaved()),
      expect: () => [
        isA<ExerciseLoggerReady>().having((s) => s.isSaving, 'isSaving', true),
        isA<ExerciseLoggerSaved>()
            .having((s) => s.savedSets.length, 'saved count', 1),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'emits [Ready(isSaving=true), Error] on repository failure',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: [false],
      ),
      setUp: () {
        when(() => repo.updateExerciseSets(_uid, _sessionId, _sessionExerciseId, any()))
            .thenThrow(Exception('write failed'));
      },
      act: (b) => b.add(SetsSaved()),
      expect: () => [
        isA<ExerciseLoggerReady>().having((s) => s.isSaving, 'isSaving', true),
        isA<ExerciseLoggerError>()
            .having((s) => s.previousState, 'previousState non-null', isNotNull),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(SetsSaved()),
      expect: () => [],
    );
  });

  // ── PRNotificationShown ───────────────────────────────────────────────────

  group('PRNotificationShown', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'resets newPRDetected to false',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: [true],
        newPRDetected: true,
      ),
      act: (b) => b.add(const PRNotificationShown()),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.newPRDetected, 'newPRDetected', false),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(const PRNotificationShown()),
      expect: () => [],
    );
  });

  // ── ExerciseNotesUpdated ──────────────────────────────────────────────────

  group('ExerciseNotesUpdated', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'updates notes optimistically without waiting for persist',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: [false],
        notes: '',
      ),
      setUp: () {
        when(() => repo.updateExerciseNotes(any(), any(), any(), any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(const ExerciseNotesUpdated('felt good')),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.notes, 'notes', 'felt good'),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'does nothing when state is not Ready',
      build: () => _bloc(repo),
      act: (b) => b.add(const ExerciseNotesUpdated('ignored')),
      expect: () => [],
    );
  });

  // ── Property: state equality & copyWith ───────────────────────────────────

  group('ExerciseLoggerReady properties', () {
    final base = ExerciseLoggerReady(
      ghostSets: const [],
      currentSets: [_set()],
      prFlags: const [false],
    );

    test('two instances with same data are equal', () {
      final other = ExerciseLoggerReady(
        ghostSets: const [],
        currentSets: [_set()],
        prFlags: const [false],
      );
      expect(base, equals(other));
    });

    test('copyWith isSaving changes equality', () {
      expect(base.copyWith(isSaving: true), isNot(equals(base)));
    });

    test('copyWith newPRDetected changes equality', () {
      expect(base.copyWith(newPRDetected: true), isNot(equals(base)));
    });

    test('copyWith notes changes equality', () {
      expect(base.copyWith(notes: 'changed'), isNot(equals(base)));
    });

    test('ExerciseLoggerError carries previousState in props', () {
      final err = ExerciseLoggerError('boom', previousState: base);
      expect(err.props, containsAll(['boom', base]));
    });

    test('ExerciseLoggerSaved carries the correct sets in props', () {
      final s = _set(setNumber: 7, reps: 12);
      final saved = ExerciseLoggerSaved([s]);
      expect(saved.savedSets, [s]);
      expect(saved.props, contains(saved.savedSets));
    });
  });

  // ── Property: PR flag computation ─────────────────────────────────────────

  group('PR flag computation', () {
    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'no PR flags when history is empty',
      build: () => _bloc(repo),
      setUp: () {
        when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
            .thenAnswer((_) async => _sessionExercise(sets: [_set(weightTotal: 100, reps: 5)]));
        when(() => repo.getLastSessionSets(_uid, _exerciseId)).thenAnswer((_) async => []);
        when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [
        isA<ExerciseLoggerLoading>(),
        isA<ExerciseLoggerReady>()
            .having((s) => s.prFlags.any((f) => f), 'no PR flags', false),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'sets with zero reps never flag as PR',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        // Start with reps=5 so the change to reps=0 produces a new state.
        currentSets: [_set(weightTotal: 200, reps: 5)],
        prFlags: [false],
      ),
      act: (b) => b.add(const SetRepsChanged(0, 0)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.prFlags[0], 'PR flag with zero reps', false),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'sets with zero weightTotal never flag as PR',
      build: () => _bloc(repo),
      seed: () => ExerciseLoggerReady(
        ghostSets: const [],
        // Start with weight=50 so the change to 0 produces a new state.
        currentSets: [_set(weightInput: 50, weightTotal: 50, reps: 10)],
        prFlags: [false],
      ),
      act: (b) => b.add(const SetWeightChanged(0, 0)),
      expect: () => [
        isA<ExerciseLoggerReady>()
            .having((s) => s.prFlags[0], 'PR flag with zero weight', false),
      ],
    );

    void stubOpenedWithHistory({required List<SetEntry> current}) {
      when(() => repo.getSessionExercise(_uid, _sessionId, _sessionExerciseId))
          .thenAnswer((_) async => _sessionExercise(sets: current));
      when(() => repo.getLastSessionSets(_uid, _exerciseId)).thenAnswer((_) async => []);
      when(() => repo.getAllSessionExercisesForExercise(_uid, _exerciseId))
          .thenAnswer((_) async => [
                _sessionExercise(sets: [
                  _set(weightTotal: 100, reps: 5),
                  // A heavy warmup in history must not raise the bar for PRs.
                  _set(weightTotal: 500, reps: 5, isWarmup: true),
                ]),
              ]);
    }

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'warmup sets never flag as PR, and history warmups are ignored',
      build: () => _bloc(repo),
      setUp: () => stubOpenedWithHistory(current: [
        _set(setNumber: 1, weightTotal: 150, reps: 5, isWarmup: true),
        _set(setNumber: 2, weightTotal: 120, reps: 5),
      ]),
      act: (b) => b.add(ExerciseLoggerOpened()),
      expect: () => [
        isA<ExerciseLoggerLoading>(),
        isA<ExerciseLoggerReady>()
            .having((s) => s.prFlags, 'flags', [false, true]),
      ],
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'toggling warmup recomputes PR flags',
      build: () => _bloc(repo),
      setUp: () => stubOpenedWithHistory(current: [
        _set(weightTotal: 150, reps: 5, isWarmup: true),
      ]),
      act: (b) async {
        b.add(ExerciseLoggerOpened());
        await Future<void>.delayed(Duration.zero);
        b.add(const SetWarmupToggled(0));
      },
      skip: 2,
      expect: () => [
        isA<ExerciseLoggerReady>().having((s) => s.prFlags, 'flags', [true]),
        isA<ExerciseLoggerReady>().having((s) => s.isSaving, 'isSaving', false),
      ],
    );
  });

  // ── Regression: debounced persistence ─────────────────────────────────────

  group('Debounced persistence', () {
    ExerciseLoggerReady seed() => ExerciseLoggerReady(
          ghostSets: const [],
          currentSets: [_set(weightInput: 50, weightTotal: 50)],
          prFlags: const [false],
        );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'a structural change cancels the pending debounced write',
      build: () => _bloc(repo),
      seed: seed,
      act: (b) {
        b.add(const SetWeightChanged(0, 60));
        b.add(SetAdded());
      },
      wait: const Duration(milliseconds: 800),
      verify: (_) {
        // Only the immediate write (with both sets) — the stale single-set
        // debounced write must not land after it.
        final written = verify(() => repo.updateExerciseSets(any(), any(), any(), captureAny()))
            .captured;
        expect(written, hasLength(1));
        expect((written.single as List<SetEntry>).length, 2);
        expect((written.single as List<SetEntry>).first.weightInput, 60);
      },
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'editing notes does not cancel a pending sets write',
      build: () => _bloc(repo),
      seed: seed,
      act: (b) {
        b.add(const SetWeightChanged(0, 60));
        b.add(const ExerciseNotesUpdated('felt heavy'));
      },
      wait: const Duration(milliseconds: 800),
      verify: (_) {
        verify(() => repo.updateExerciseSets(any(), any(), any(), any())).called(1);
        verify(() => repo.updateExerciseNotes(_uid, _sessionId, _sessionExerciseId, 'felt heavy'))
            .called(1);
      },
    );

    blocTest<ExerciseLoggerBloc, ExerciseLoggerState>(
      'closing within the debounce window flushes pending writes',
      build: () => _bloc(repo),
      seed: seed,
      act: (b) {
        b.add(const SetWeightChanged(0, 60));
        b.add(const ExerciseNotesUpdated('felt heavy'));
      },
      // No wait: bloc_test closes the bloc right after act.
      verify: (_) {
        final written = verify(() => repo.updateExerciseSets(any(), any(), any(), captureAny()))
            .captured;
        expect((written.single as List<SetEntry>).first.weightInput, 60);
        verify(() => repo.updateExerciseNotes(_uid, _sessionId, _sessionExerciseId, 'felt heavy'))
            .called(1);
      },
    );
  });
}
