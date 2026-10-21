part of 'session_bloc.dart';

abstract class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

class SessionInitial extends SessionState {}

class SessionLoading extends SessionState {}

class SessionActive extends SessionState {
  final WorkoutSession session;
  final List<SessionExercise> exercises;
  final Map<String, PRData> pendingPRs;

  const SessionActive({
    required this.session,
    required this.exercises,
    required this.pendingPRs,
  });

  @override
  List<Object?> get props => [session, exercises, pendingPRs];
}

class SessionFinishing extends SessionState {}

class SessionComplete extends SessionState {}

class SessionError extends SessionState {
  final String message;
  const SessionError(this.message);
  @override
  List<Object?> get props => [message];
}
