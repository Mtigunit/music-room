import 'package:equatable/equatable.dart';
import 'package:music_room/core/error/failure.dart';

/// Base class for all authentication states
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Checking if user is authenticated
class AuthChecking extends AuthState {
  const AuthChecking();
}

/// User is authenticated
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

/// User is not authenticated
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Login in progress
class LoginLoading extends AuthState {
  const LoginLoading();
}

/// Login successful
class LoginSuccess extends AuthState {
  const LoginSuccess({required this.accessToken});
  final String accessToken;

  @override
  List<Object?> get props => [accessToken];
}

/// Login failed
class LoginFailure extends AuthState {
  const LoginFailure({required this.failure});
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// OTP sending in progress
class OtpLoading extends AuthState {
  const OtpLoading();
}

/// OTP sent successfully
class OtpSent extends AuthState {
  const OtpSent({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}

/// OTP sending failed
class OtpFailure extends AuthState {
  const OtpFailure({required this.failure});
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// OTP verification in progress
class OtpVerifying extends AuthState {
  const OtpVerifying();
}

/// OTP verification successful
class OtpVerified extends AuthState {
  const OtpVerified({
    required this.emailVerificationToken,
    required this.email,
  });
  final String emailVerificationToken;
  final String email;

  @override
  List<Object?> get props => [emailVerificationToken, email];
}

/// OTP verification failed
class OtpVerificationFailure extends AuthState {
  const OtpVerificationFailure({required this.failure});
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// User registration in progress
class RegisterLoading extends AuthState {
  const RegisterLoading();
}

/// User registration successful
class RegisterSuccess extends AuthState {
  const RegisterSuccess({required this.accessToken});
  final String accessToken;

  @override
  List<Object?> get props => [accessToken];
}

/// User registration failed
class RegisterFailure extends AuthState {
  const RegisterFailure({required this.failure});
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Logout successful
class LogoutSuccess extends AuthState {
  const LogoutSuccess();
}
