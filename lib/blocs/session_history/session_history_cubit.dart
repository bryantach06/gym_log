import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/workout_session.dart';
import '../../repositories/session_repository.dart';

part 'session_history_state.dart';

class SessionHistoryCubit extends Cubit<SessionHistoryState> {
  final SessionRepository _repo;
  final String _uid;
  DocumentSnapshot? _lastDoc;

  SessionHistoryCubit(this._repo, this._uid) : super(SessionHistoryInitial());

  static const _pageSize = 20;

  Future<void> loadInitial() async {
    emit(SessionHistoryLoading());
    try {
      _lastDoc = null;
      final page = await _repo.getFinishedSessions(_uid, limit: _pageSize);
      _lastDoc = page.lastDoc;
      emit(SessionHistoryLoaded(
        sessions: page.sessions,
        hasMore: page.sessions.length == _pageSize,
      ));
    } catch (e) {
      emit(SessionHistoryError(e.toString()));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! SessionHistoryLoaded || !current.hasMore) return;
    try {
      final page = await _repo.getFinishedSessions(
        _uid,
        startAfter: _lastDoc,
        limit: _pageSize,
      );
      if (page.lastDoc != null) _lastDoc = page.lastDoc;
      emit(SessionHistoryLoaded(
        sessions: [...current.sessions, ...page.sessions],
        hasMore: page.sessions.length == _pageSize,
      ));
    } catch (e) {
      emit(SessionHistoryError(e.toString()));
    }
  }

  /// Deletes a finished session. Returns false if the delete failed, leaving
  /// the list unchanged so the caller can report it.
  Future<bool> deleteSession(String sessionId) async {
    try {
      await _repo.discardSession(_uid, sessionId);
    } catch (_) {
      return false;
    }
    final current = state;
    if (current is SessionHistoryLoaded) {
      emit(SessionHistoryLoaded(
        sessions: current.sessions.where((s) => s.id != sessionId).toList(),
        hasMore: current.hasMore,
      ));
    }
    return true;
  }
}
