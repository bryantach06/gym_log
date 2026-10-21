import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gym_log/blocs/session_history/session_history_cubit.dart';
import 'package:gym_log/models/workout_session.dart';
import 'package:gym_log/repositories/session_repository.dart';

class MockSessionRepository extends Mock implements SessionRepository {}

// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Object?> {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _start = DateTime(2024, 1, 1);

WorkoutSession _session(String id) =>
    WorkoutSession(id: id, startedAt: _start, status: 'finished');

List<WorkoutSession> _sessions(int count, {int offset = 0}) =>
    List.generate(count, (i) => _session('s${offset + i}'));

typedef _Page = ({List<WorkoutSession> sessions, DocumentSnapshot? lastDoc});

_Page _page(int count, {int offset = 0, DocumentSnapshot? lastDoc}) =>
    (sessions: _sessions(count, offset: offset), lastDoc: lastDoc);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockSessionRepository repo;
  final cursor1 = FakeDocumentSnapshot();
  final cursor2 = FakeDocumentSnapshot();

  setUpAll(() {
    registerFallbackValue(FakeDocumentSnapshot());
  });

  setUp(() {
    repo = MockSessionRepository();
  });

  SessionHistoryCubit build() => SessionHistoryCubit(repo, 'uid1');

  void stubFirstPage(Future<_Page> Function() answer) =>
      when(() => repo.getFinishedSessions('uid1', startAfter: null, limit: 20))
          .thenAnswer((_) => answer());

  void stubNextPage(DocumentSnapshot after, Future<_Page> Function() answer) =>
      when(() => repo.getFinishedSessions('uid1', startAfter: after, limit: 20))
          .thenAnswer((_) => answer());

  // ── loadInitial ───────────────────────────────────────────────────────────

  group('loadInitial', () {
    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'emits [Loading, Loaded] with sessions and hasMore=false when fewer than 20',
      build: build,
      setUp: () => stubFirstPage(() async => _page(5)),
      act: (c) => c.loadInitial(),
      expect: () => [
        isA<SessionHistoryLoading>(),
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions.length, 'count', 5)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'emits Loaded with hasMore=true when exactly 20 sessions returned',
      build: build,
      setUp: () => stubFirstPage(() async => _page(20, lastDoc: cursor1)),
      act: (c) => c.loadInitial(),
      expect: () => [
        isA<SessionHistoryLoading>(),
        isA<SessionHistoryLoaded>()
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.sessions.length, 'count', 20),
      ],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'emits [Loading, Loaded] with empty list when no sessions',
      build: build,
      setUp: () => stubFirstPage(() async => _page(0)),
      act: (c) => c.loadInitial(),
      expect: () => [
        isA<SessionHistoryLoading>(),
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions, 'sessions', isEmpty)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'emits [Loading, Error] on repository exception',
      build: build,
      setUp: () => stubFirstPage(() async => throw Exception('firestore down')),
      act: (c) => c.loadInitial(),
      expect: () => [isA<SessionHistoryLoading>(), isA<SessionHistoryError>()],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'resets state on consecutive loadInitial calls',
      build: build,
      setUp: () => stubFirstPage(() async => _page(3)),
      act: (c) async {
        await c.loadInitial();
        await c.loadInitial();
      },
      expect: () => [
        isA<SessionHistoryLoading>(),
        isA<SessionHistoryLoaded>(),
        isA<SessionHistoryLoading>(),
        isA<SessionHistoryLoaded>(),
      ],
    );
  });

  // ── loadMore ──────────────────────────────────────────────────────────────

  group('loadMore', () {
    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'appends next page and sets hasMore=false when fewer than 20 returned',
      build: build,
      setUp: () {
        stubFirstPage(() async => _page(20, lastDoc: cursor1));
        stubNextPage(cursor1, () async => _page(5, offset: 20, lastDoc: cursor2));
      },
      act: (c) async {
        await c.loadInitial();
        await c.loadMore();
      },
      skip: 2,
      expect: () => [
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions.length, 'total', 25)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'uses the cursor returned by each page, without extra cursor queries',
      build: build,
      setUp: () {
        stubFirstPage(() async => _page(20, lastDoc: cursor1));
        stubNextPage(cursor1, () async => _page(20, offset: 20, lastDoc: cursor2));
        stubNextPage(cursor2, () async => _page(1, offset: 40));
      },
      act: (c) async {
        await c.loadInitial();
        await c.loadMore();
        await c.loadMore();
      },
      skip: 2,
      expect: () => [
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions.length, 'total', 40)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions.length, 'total', 41)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
      verify: (_) {
        verify(() => repo.getFinishedSessions('uid1', startAfter: cursor1, limit: 20))
            .called(1);
        verify(() => repo.getFinishedSessions('uid1', startAfter: cursor2, limit: 20))
            .called(1);
      },
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'does nothing when hasMore is false',
      build: build,
      seed: () => SessionHistoryLoaded(sessions: _sessions(5), hasMore: false),
      act: (c) => c.loadMore(),
      expect: () => [],
      verify: (_) => verifyNever(() => repo.getFinishedSessions(any(),
          startAfter: any(named: 'startAfter'), limit: any(named: 'limit'))),
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'does nothing when state is not Loaded',
      build: build,
      act: (c) => c.loadMore(),
      expect: () => [],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'emits Error on repository exception during pagination',
      build: build,
      setUp: () {
        stubFirstPage(() async => _page(20, lastDoc: cursor1));
        stubNextPage(cursor1, () async => throw Exception('pagination failed'));
      },
      act: (c) async {
        await c.loadInitial();
        await c.loadMore();
      },
      skip: 2,
      expect: () => [isA<SessionHistoryError>()],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'preserves existing sessions when page returns empty list',
      build: build,
      setUp: () {
        stubFirstPage(() async => _page(20, lastDoc: cursor1));
        stubNextPage(cursor1, () async => _page(0));
      },
      act: (c) async {
        await c.loadInitial();
        await c.loadMore();
      },
      skip: 2,
      expect: () => [
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions.length, 'total', 20)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );
  });

  // ── deleteSession ─────────────────────────────────────────────────────────

  group('deleteSession', () {
    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'removes the session from the list on success',
      build: build,
      seed: () => SessionHistoryLoaded(sessions: _sessions(3), hasMore: false),
      setUp: () {
        when(() => repo.discardSession('uid1', 's1')).thenAnswer((_) async {});
      },
      act: (c) async => expect(await c.deleteSession('s1'), isTrue),
      expect: () => [
        isA<SessionHistoryLoaded>()
            .having((s) => s.sessions.map((x) => x.id), 'ids', ['s0', 's2']),
      ],
    );

    blocTest<SessionHistoryCubit, SessionHistoryState>(
      'returns false and leaves the list unchanged on failure',
      build: build,
      seed: () => SessionHistoryLoaded(sessions: _sessions(3), hasMore: false),
      setUp: () {
        when(() => repo.discardSession('uid1', 's1'))
            .thenThrow(Exception('delete failed'));
      },
      act: (c) async => expect(await c.deleteSession('s1'), isFalse),
      expect: () => [],
    );
  });

  // ── Property: state equality ──────────────────────────────────────────────

  group('SessionHistoryState properties', () {
    test('SessionHistoryLoaded with same data are equal', () {
      final a = SessionHistoryLoaded(sessions: _sessions(3), hasMore: false);
      final b = SessionHistoryLoaded(sessions: _sessions(3), hasMore: false);
      expect(a, equals(b));
    });

    test('SessionHistoryLoaded differs when hasMore differs', () {
      final a = SessionHistoryLoaded(sessions: _sessions(3), hasMore: false);
      final b = SessionHistoryLoaded(sessions: _sessions(3), hasMore: true);
      expect(a, isNot(equals(b)));
    });

    test('SessionHistoryLoaded differs when sessions list differs', () {
      final a = SessionHistoryLoaded(sessions: _sessions(2), hasMore: false);
      final b = SessionHistoryLoaded(sessions: _sessions(3), hasMore: false);
      expect(a, isNot(equals(b)));
    });

    test('SessionHistoryError carries message in props', () {
      const err = SessionHistoryError('boom');
      expect(err.props, contains('boom'));
    });
  });
}
