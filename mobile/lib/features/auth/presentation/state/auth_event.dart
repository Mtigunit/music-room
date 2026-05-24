import 'package:equatable/equatable.dart';

/// Base class for all authentication events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event to check if user is authenticated on app start
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Event to login with email/username and password
class LoginRequested extends AuthEvent {
  const LoginRequested({
    required this.identifier,
    required this.password,
  });
  final String identifier;
  final String password;

  @override
  List<Object?> get props => [identifier, password];
}

/// Event to login with Google OAuth
class GoogleLoginRequested extends AuthEvent {
  const GoogleLoginRequested();
}

/// Web variant of Google login that receives an ID token produced by the
/// browser Google Sign-In flow and sends it to the backend.
class GoogleLoginRequestedWeb extends AuthEvent {
  const GoogleLoginRequestedWeb({
    required this.idToken,
  });

  final String idToken;

  @override
  List<Object?> get props => [idToken];
}

/// Event to request OTP code to be sent to email
class SendOtpRequested extends AuthEvent {
  const SendOtpRequested({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}

/// Event to verify OTP code and get email verification token
class VerifyOtpRequested extends AuthEvent {
  const VerifyOtpRequested({
    required this.email,
    required this.code,
  });
  final String email;
  final String code;

  @override
  List<Object?> get props => [email, code];
}

/// Event to request password reset OTP code
class SendPasswordResetOtpRequested extends AuthEvent {
  const SendPasswordResetOtpRequested({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}

/// Event to verify password reset OTP code and receive reset token
class VerifyPasswordResetOtpRequested extends AuthEvent {
  const VerifyPasswordResetOtpRequested({
    required this.email,
    required this.code,
  });
  final String email;
  final String code;

  @override
  List<Object?> get props => [email, code];
}

/// Event to reset password with a verified reset token
class ResetPasswordRequested extends AuthEvent {
  const ResetPasswordRequested({
    required this.email,
    required this.resetToken,
    required this.newPassword,
  });
  final String email;
  final String resetToken;
  final String newPassword;

  @override
  List<Object?> get props => [email, resetToken, newPassword];
}

/// Event to register a new user
class RegisterRequested extends AuthEvent {
  const RegisterRequested({
    required this.email,
    required this.username,
    required this.password,
    required this.emailVerificationToken,
  });
  final String email;
  final String username;
  final String password;
  final String emailVerificationToken;

  @override
  List<Object?> get props => [
    email,
    username,
    password,
    emailVerificationToken,
  ];
}

/// Event to logout
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// Event to log out from all devices, including the current session.
class LogoutFromAllDevicesRequested extends AuthEvent {
  const LogoutFromAllDevicesRequested();
}

/// Event triggered when session expires (token invalid/expired)
class SessionExpiredRequested extends AuthEvent {
  const SessionExpiredRequested();
}
