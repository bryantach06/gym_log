import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/session_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepo;
  final ExerciseRepository _exerciseRepo;
  final SessionRepository _sessionRepo;
  late final StreamSubscription<User?> _authSub;

  AuthCubit(this._authRepo, this._exerciseRepo, this._sessionRepo)
      : super(AuthInitial()) {
    _authSub = _authRepo.authStateChanges.listen((user) {
      if (user != null) {
        emit(AuthAuthenticated(user));
        // Background, one-time: older history only appears in PRs/ghost rows
        // once this has run. Retried on next launch if it fails.
        _sessionRepo.backfillExerciseMetadata(user.uid).catchError((_) {});
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }

  @override
  Future<void> close() async {
    await _authSub.cancel();
    return super.close();
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final user = await _authRepo.signInWithGoogle();
      if (user != null) {
        await _exerciseRepo.seedIfEmpty(user.uid);
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_friendlyAuthError(e)));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await _authRepo.signInWithEmailAndPassword(email, password);
      if (user != null) {
        await _exerciseRepo.seedIfEmpty(user.uid);
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_friendlyAuthError(e)));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    emit(AuthUnauthenticated());
  }

  /// Maps Firebase Auth error codes to user-friendly messages.
  /// Uses the consolidated 'invalid-credential' code introduced in
  /// Firebase Auth SDK v9.6+ (replaces the deprecated 'user-not-found'
  /// and 'wrong-password' codes).
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }
}
