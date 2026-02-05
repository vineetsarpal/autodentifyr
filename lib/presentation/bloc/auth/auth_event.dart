part of 'auth_bloc.dart';

@immutable
abstract class AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final User? user;
  AuthUserChanged(this.user);
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignUpRequested(this.email, this.password);
}

class AuthLogoutRequested extends AuthEvent {}
