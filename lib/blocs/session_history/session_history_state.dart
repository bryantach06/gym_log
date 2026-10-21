part of 'session_history_cubit.dart';

abstract class SessionHistoryState extends Equatable {
  const SessionHistoryState();
  @override
  List<Object?> get props => [];
}

class SessionHistoryInitial extends SessionHistoryState {}

class SessionHistoryLoading extends SessionHistoryState {}

class SessionHistoryLoaded extends SessionHistoryState {
  final List<WorkoutSession> sessions;
  final bool hasMore;

  const SessionHistoryLoaded({required this.sessions, required this.hasMore});

  @override
  List<Object?> get props => [sessions, hasMore];
}

class SessionHistoryError extends SessionHistoryState {
  final String message;
  const SessionHistoryError(this.message);
  @override
  List<Object?> get props => [message];
}
