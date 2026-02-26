import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:autodentifyr/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  late StreamSubscription<User?> _userSubscription;

  AuthBloc(this._authService) : super(AuthInitial()) {
    // Listen to events
    on<AuthUserChanged>(_onUserChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);

    // Subscribe to Firebase Auth changes
    _userSubscription = _authService.user.listen((user) {
      add(AuthUserChanged(user));
    });
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthAuthenticated(event.user!));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithEmail(event.email, event.password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-email') {
        emit(AuthError('Invalid email or password. Please try again.'));
      } else {
        emit(AuthError(e.message ?? 'Login failed. Please try again.'));
      }
    } catch (e) {
      emit(AuthError('An unexpected error occurred. Please try again.'));
    }
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signUpWithEmail(event.email, event.password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        emit(AuthError('The password provided is too weak.'));
      } else if (e.code == 'email-already-in-use') {
        emit(AuthError('An account already exists for that email.'));
      } else if (e.code == 'invalid-email') {
        emit(AuthError('The email address is not valid.'));
      } else {
        emit(AuthError(e.message ?? 'Sign up failed. Please try again.'));
      }
    } catch (e) {
      emit(AuthError('An unexpected error occurred. Please try again.'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithGoogle();
    } on GoogleSignInException catch (e) {
      // User explicitly cancelled — silently return to the login screen
      if (e.code == GoogleSignInExceptionCode.canceled) {
        emit(AuthUnauthenticated());
      } else {
        emit(
          AuthError(
            e.description ?? 'Google sign-in failed. Please try again.',
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Google sign-in failed. Please try again.'));
    } catch (e) {
      emit(AuthError('Google sign-in failed. Please try again.'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.signOut();
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmail(event.email);
      emit(AuthPasswordResetEmailSent());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Password reset failed. Please try again.'));
    } catch (e) {
      emit(AuthError('An unexpected error occurred. Please try again.'));
    }
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
