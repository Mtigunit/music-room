import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/auth/domain/repositories/auth_repository.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';

/// BLoC for managing authentication state and events
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required ApiClient apiClient,
  }) : _authRepository = authRepository,
       super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<LoginRequested>(_onLoginRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<SendOtpRequested>(_onSendOtpRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<SendPasswordResetOtpRequested>(_onSendPasswordResetOtpRequested);
    on<VerifyPasswordResetOtpRequested>(_onVerifyPasswordResetOtpRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionExpiredRequested>(_onSessionExpiredRequested);

    _sessionExpiredSubscription = apiClient.sessionExpired.listen((_) {
      add(const SessionExpiredRequested());
    });
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  @override
  Future<void> close() async {
    await _sessionExpiredSubscription.cancel();
    return super.close();
  }

  /// Handle Google OAuth login request
  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const GoogleLoginLoading());

    final (response, failure) = await _authRepository.loginWithGoogle();

    if (response != null) {
      emit(
        GoogleLoginSuccess(
          accessToken: response.accessToken,
          user: response.user,
        ),
      );
      emit(
        AuthAuthenticated(
          accessToken: response.accessToken,
          user: response.user,
        ),
      );
    } else {
      emit(GoogleLoginFailure(failure: failure!));
    }
  }

  /// Check if user is authenticated on app start
  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthChecking());
    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final accessToken = await _authRepository.getStoredAccessToken();
        if (accessToken == null || accessToken.isEmpty) {
          emit(const AuthUnauthenticated());
          return;
        }

        final storedUser = await _authRepository.getStoredUserProfile();
        if (storedUser != null) {
          emit(
            AuthAuthenticated(
              accessToken: accessToken,
              user: storedUser,
            ),
          );
          return;
        }

        final (profile, _) = await _authRepository.getProfile();
        if (profile != null) {
          emit(
            AuthAuthenticated(
              accessToken: accessToken,
              user: profile,
            ),
          );
          return;
        }

        await _authRepository.logout();
        emit(const AuthUnauthenticated());
      } else {
        emit(const AuthUnauthenticated());
      }
    } on Exception {
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle login request
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const LoginLoading());
    final (response, failure) = await _authRepository.login(
      identifier: event.identifier,
      password: event.password,
    );

    if (response != null) {
      emit(
        LoginSuccess(
          accessToken: response.accessToken,
          user: response.user,
        ),
      );
      emit(
        AuthAuthenticated(
          accessToken: response.accessToken,
          user: response.user,
        ),
      );
    } else {
      emit(LoginFailure(failure: failure!));
    }
  }

  /// Handle OTP sending request
  Future<void> _onSendOtpRequested(
    SendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const OtpLoading());
    final (success, failure) = await _authRepository.sendOtp(event.email);

    if (success) {
      emit(OtpSent(email: event.email));
    } else {
      emit(OtpFailure(failure: failure!));
    }
  }

  /// Handle OTP verification request
  Future<void> _onVerifyOtpRequested(
    VerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const OtpVerifying());
    final (response, failure) = await _authRepository.verifyOtp(
      event.email,
      event.code,
    );

    if (response != null) {
      emit(
        OtpVerified(
          emailVerificationToken: response.emailVerificationToken,
          email: event.email,
        ),
      );
    } else {
      emit(OtpVerificationFailure(failure: failure!));
    }
  }

  /// Handle password-reset OTP sending request
  Future<void> _onSendPasswordResetOtpRequested(
    SendPasswordResetOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PasswordResetOtpLoading());
    final (success, failure) = await _authRepository.sendPasswordResetOtp(
      event.email,
    );

    if (success) {
      emit(PasswordResetOtpSent(email: event.email));
    } else {
      emit(PasswordResetOtpFailure(failure: failure!));
    }
  }

  /// Handle password-reset OTP verification request
  Future<void> _onVerifyPasswordResetOtpRequested(
    VerifyPasswordResetOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const PasswordResetOtpVerifying());
    final (response, failure) = await _authRepository.verifyPasswordResetOtp(
      event.email,
      event.code,
    );

    if (response != null) {
      emit(
        PasswordResetOtpVerified(
          passwordResetToken: response.passwordResetToken,
          email: event.email,
        ),
      );
    } else {
      emit(PasswordResetOtpVerificationFailure(failure: failure!));
    }
  }

  /// Handle password reset submission request
  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const ResetPasswordLoading());
    final (response, failure) = await _authRepository.resetPassword(
      email: event.email,
      resetToken: event.resetToken,
      newPassword: event.newPassword,
    );

    if (response != null) {
      emit(ResetPasswordSuccess(message: response.message));
    } else {
      emit(ResetPasswordFailure(failure: failure!));
    }
  }

  /// Handle user registration request
  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const RegisterLoading());
    final (response, failure) = await _authRepository.register(
      email: event.email,
      username: event.username,
      password: event.password,
      emailVerificationToken: event.emailVerificationToken,
    );

    if (response != null) {
      emit(
        RegisterSuccess(
          accessToken: response.accessToken,
          user: response.user,
        ),
      );
      emit(
        AuthAuthenticated(
          accessToken: response.accessToken,
          user: response.user,
        ),
      );
    } else {
      emit(RegisterFailure(failure: failure!));
    }
  }

  /// Handle logout request
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const LogoutSuccess());
    emit(const AuthUnauthenticated());
  }

  /// Handle session expiration (token expired during active use)
  Future<void> _onSessionExpiredRequested(
    SessionExpiredRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthUnauthenticated());
  }
}
