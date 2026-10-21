import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gym_log/blocs/session/session_bloc.dart';
import 'package:gym_log/models/exercise.dart';
import 'package:gym_log/models/session_exercise.dart';
import 'package:gym_log/models/set_entry.dart';
import 'package:gym_log/models/workout_session.dart';
import 'package:gym_log/repositories/session_repository.dart';

class MockSessionRepository extends Mock implements SessionRepository {}

class FakeSessionExercise extends Fake implements SessionExercise {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _now = DateTime(2024, 1, 1, 10);

WorkoutSession _session({String id = 'sess1', String status = 'draft', String notes = ''}) =>
    WorkoutSession(id: id, startedAt: _now, status: status, notes: notes);

SessionExercise _sessionExercise({String id = 'se1', int orderIndex = 0}) => SessionExercise(
      id: id,
      exerciseId: 'ex1',
      exerciseName: 'Squat',
      equipmentType: 'barbell',
      orderIndex: orderIndex,
    );

Exercise _exercise({String id = 'ex1'}) => Exercise(
      id: id,
      name: 'Squat',
      muscleGroup: 'legs',
      equipmentType: 'barbell',
      isCustom: false,
      createdAt: _now,
    );

SetEntry _set({int setNumber = 1}) => SetEntry(
      setNumber: setNumber,
      weightInput: 100,
      weightTotal: 120,
      reps: 5,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockSessionRepository repo;

  setUpAll(() {
    registerFallbackValue(FakeSessionExercise());
  });

  setUp(() {
    repo = MockSessionRepository();
  });

  SessionBloc build() => SessionBloc(repo, 'uid1');

  // ── SessionStarted ────────────────────────────────────────────────────────

  group('SessionStarted', () {
    blocTest<SessionBloc, SessionState>(
      'emits [Loading, Active] when no draft exists',
      build: build,
      setUp: () {
        when(() => repo.getDraftSession('uid1')).thenAnswer((_) async => null);
        when(() => repo.createSession('uid1')).thenAnswer((_) async => _session());
      },
      act: (b) => b.add(SessionStarted()),
      expect: () => [
        isA<SessionLoading>(),
        isA<SessionActive>().having((s) => s.session.id, 'id', 'sess1'),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'resumes existing draft instead of creating a new session',
      build: build,
      setUp: () {
        when(() => repo.getDraftSession('uid1')).thenAnswer((_) async => _session());
        when(() => repo.getSessionExercises('uid1', 'sess1'))
            .thenAnswer((_) async => [_sessionExercise()]);
      },
      act: (b) => b.add(SessionStarted()),
      expect: () => [
        isA<SessionLoading>(),
        isA<SessionActive>().having((s) => s.exercises.length, 'exercises', 1),
      ],
      verify: (_) => verifyNever(() => repo.createSession(any())),
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when already active',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      act: (b) => b.add(SessionStarted()),
      expect: () => [],
    );

    blocTest<SessionBloc, SessionState>(
      'emits [Loading, Error, Initial] on repository exception',
      build: build,
      setUp: () {
        when(() => repo.getDraftSession('uid1')).thenThrow(Exception('network'));
      },
      act: (b) => b.add(SessionStarted()),
      expect: () => [
        isA<SessionLoading>(),
        isA<SessionError>(),
        isA<SessionInitial>(),
      ],
    );
  });

  // ── SessionResumed ────────────────────────────────────────────────────────

  group('SessionResumed', () {
    blocTest<SessionBloc, SessionState>(
      'emits [Loading, Active] when draft exists',
      build: build,
      setUp: () {
        when(() => repo.getDraftSession('uid1')).thenAnswer((_) async => _session());
        when(() => repo.getSessionExercises('uid1', 'sess1'))
            .thenAnswer((_) async => []);
      },
      act: (b) => b.add(const SessionResumed()),
      expect: () => [isA<SessionLoading>(), isA<SessionActive>()],
    );

    blocTest<SessionBloc, SessionState>(
      'emits [Loading, Initial] when no draft exists',
      build: build,
      setUp: () {
        when(() => repo.getDraftSession('uid1')).thenAnswer((_) async => null);
      },
      act: (b) => b.add(const SessionResumed()),
      expect: () => [isA<SessionLoading>(), isA<SessionInitial>()],
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when already active',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      act: (b) => b.add(const SessionResumed()),
      expect: () => [],
    );

    blocTest<SessionBloc, SessionState>(
      'falls back to Initial on exception (offline resilience)',
      build: build,
      setUp: () {
        when(() => repo.getDraftSession('uid1')).thenThrow(Exception('offline'));
      },
      act: (b) => b.add(const SessionResumed()),
      expect: () => [isA<SessionLoading>(), isA<SessionInitial>()],
    );
  });

  // ── SessionExerciseAdded ──────────────────────────────────────────────────

  group('SessionExerciseAdded', () {
    blocTest<SessionBloc, SessionState>(
      'appends exercise and assigns correct orderIndex',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.addExerciseToSession('uid1', 'sess1', any(),
            sessionStartedAt: any(named: 'sessionStartedAt')))
            .thenAnswer((_) async => _sessionExercise(id: 'se1', orderIndex: 0));
      },
      act: (b) => b.add(SessionExerciseAdded(_exercise())),
      expect: () => [
        isA<SessionActive>().having((s) => s.exercises.length, 'count', 1),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'orderIndex equals current exercise count before adding',
      build: build,
      seed: () => SessionActive(
        session: _session(),
        exercises: [_sessionExercise(id: 'se0', orderIndex: 0)],
        pendingPRs: const {},
      ),
      setUp: () {
        when(() => repo.addExerciseToSession('uid1', 'sess1', any(),
            sessionStartedAt: any(named: 'sessionStartedAt')))
            .thenAnswer((invocation) async {
          final ex = invocation.positionalArguments[2] as SessionExercise;
          return ex.copyWith(); // echo back
        });
      },
      act: (b) => b.add(SessionExerciseAdded(_exercise())),
      expect: () => [
        isA<SessionActive>().having((s) => s.exercises.last.orderIndex, 'orderIndex', 1),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'enforces 10-exercise limit',
      build: build,
      seed: () => SessionActive(
        session: _session(),
        exercises: List.generate(10, (i) => _sessionExercise(id: 'se$i', orderIndex: i)),
        pendingPRs: const {},
      ),
      act: (b) => b.add(SessionExerciseAdded(_exercise())),
      expect: () => [],
      verify: (_) => verifyNever(() => repo.addExerciseToSession(any(), any(), any(),
          sessionStartedAt: any(named: 'sessionStartedAt'))),
    );

    blocTest<SessionBloc, SessionState>(
      'passes the session start time through for history queries',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.addExerciseToSession('uid1', 'sess1', any(),
                sessionStartedAt: any(named: 'sessionStartedAt')))
            .thenAnswer((_) async => _sessionExercise());
      },
      act: (b) => b.add(SessionExerciseAdded(_exercise())),
      verify: (_) => verify(() => repo.addExerciseToSession('uid1', 'sess1', any(),
          sessionStartedAt: _now)).called(1),
    );

    blocTest<SessionBloc, SessionState>(
      'reports Error then restores Active when the write fails',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.addExerciseToSession('uid1', 'sess1', any(),
                sessionStartedAt: any(named: 'sessionStartedAt')))
            .thenThrow(Exception('write failed'));
      },
      act: (b) => b.add(SessionExerciseAdded(_exercise())),
      expect: () => [
        isA<SessionError>(),
        isA<SessionActive>().having((s) => s.exercises, 'exercises', isEmpty),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when state is not Active',
      build: build,
      act: (b) => b.add(SessionExerciseAdded(_exercise())),
      expect: () => [],
    );
  });

  // ── SessionFinished ───────────────────────────────────────────────────────

  group('SessionFinished', () {
    blocTest<SessionBloc, SessionState>(
      'emits [Finishing, Complete] on success',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.finishSession('uid1', 'sess1')).thenAnswer((_) async {});
      },
      act: (b) => b.add(SessionFinished()),
      expect: () => [isA<SessionFinishing>(), isA<SessionComplete>()],
    );

    blocTest<SessionBloc, SessionState>(
      'emits [Finishing, Error, Active] on repository failure so the user can retry',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.finishSession('uid1', 'sess1')).thenThrow(Exception('write failed'));
      },
      act: (b) => b.add(SessionFinished()),
      expect: () => [
        isA<SessionFinishing>(),
        isA<SessionError>(),
        isA<SessionActive>().having((s) => s.session.id, 'id', 'sess1'),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when state is not Active',
      build: build,
      act: (b) => b.add(SessionFinished()),
      expect: () => [],
    );
  });

  // ── SessionDiscarded ──────────────────────────────────────────────────────

  group('SessionDiscarded', () {
    blocTest<SessionBloc, SessionState>(
      'emits Initial after successful discard',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.discardSession('uid1', 'sess1')).thenAnswer((_) async {});
      },
      act: (b) => b.add(SessionDiscarded()),
      expect: () => [isA<SessionInitial>()],
    );

    blocTest<SessionBloc, SessionState>(
      'emits [Error, Active] on repository failure',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.discardSession('uid1', 'sess1')).thenThrow(Exception('delete failed'));
      },
      act: (b) => b.add(SessionDiscarded()),
      expect: () => [isA<SessionError>(), isA<SessionActive>()],
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when state is not Active',
      build: build,
      act: (b) => b.add(SessionDiscarded()),
      expect: () => [],
    );
  });

  // ── SessionExerciseSetsUpdated ────────────────────────────────────────────

  group('SessionExerciseSetsUpdated', () {
    blocTest<SessionBloc, SessionState>(
      'updates sets for matching exercise id synchronously',
      build: build,
      seed: () => SessionActive(
        session: _session(),
        exercises: [_sessionExercise(id: 'se1')],
        pendingPRs: const {},
      ),
      act: (b) => b.add(SessionExerciseSetsUpdated('se1', [_set()])),
      expect: () => [
        isA<SessionActive>().having(
          (s) => s.exercises.first.sets.length,
          'sets count',
          1,
        ),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'does not touch exercises with a different id',
      build: build,
      seed: () => SessionActive(
        session: _session(),
        exercises: [
          _sessionExercise(id: 'se1'),
          _sessionExercise(id: 'se2', orderIndex: 1),
        ],
        pendingPRs: const {},
      ),
      act: (b) => b.add(SessionExerciseSetsUpdated('se1', [_set()])),
      expect: () => [
        isA<SessionActive>().having(
          (s) => s.exercises.last.sets,
          'se2 sets unchanged',
          isEmpty,
        ),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when state is not Active',
      build: build,
      act: (b) => b.add(SessionExerciseSetsUpdated('se1', [_set()])),
      expect: () => [],
    );
  });

  // ── SessionNotesUpdated ───────────────────────────────────────────────────

  group('SessionNotesUpdated', () {
    blocTest<SessionBloc, SessionState>(
      'optimistically updates notes in state',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.updateSessionNotes('uid1', 'sess1', any()))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(const SessionNotesUpdated('great session')),
      expect: () => [
        isA<SessionActive>()
            .having((s) => s.session.notes, 'notes', 'great session'),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'state is still updated even if persist throws',
      build: build,
      seed: () => SessionActive(session: _session(), exercises: const [], pendingPRs: const {}),
      setUp: () {
        when(() => repo.updateSessionNotes('uid1', 'sess1', any()))
            .thenThrow(Exception('network'));
      },
      act: (b) => b.add(const SessionNotesUpdated('offline note')),
      expect: () => [
        isA<SessionActive>()
            .having((s) => s.session.notes, 'notes', 'offline note'),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'does nothing when state is not Active',
      build: build,
      act: (b) => b.add(const SessionNotesUpdated('ignored')),
      expect: () => [],
    );
  });

  // ── Property: state machine invariants ───────────────────────────────────

  group('State machine properties', () {
    test('SessionActive props includes session, exercises and pendingPRs', () {
      final active = SessionActive(
        session: _session(),
        exercises: [_sessionExercise()],
        pendingPRs: const {},
      );
      expect(active.props, containsAll([active.session, active.exercises, active.pendingPRs]));
    });

    test('SessionError carries the message in props', () {
      const err = SessionError('boom');
      expect(err.props, contains('boom'));
    });

    test('Two SessionActive with same data are equal', () {
      final a = SessionActive(session: _session(), exercises: const [], pendingPRs: const {});
      final b = SessionActive(session: _session(), exercises: const [], pendingPRs: const {});
      expect(a, equals(b));
    });

    test('SessionActive with different exercises are not equal', () {
      final a = SessionActive(session: _session(), exercises: const [], pendingPRs: const {});
      final b = SessionActive(
          session: _session(), exercises: [_sessionExercise()], pendingPRs: const {});
      expect(a, isNot(equals(b)));
    });
  });
}
