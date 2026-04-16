import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';
import 'package:music_room/features/auth/domain/repositories/auth_repository.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';

/// BLoC for managing authentication state and events
class AuthBloc extends Bloc<AuthEvent, AuthState> {

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<LoginRequested>(_onLoginRequested);
    on<SendOtpRequested>(_onSendOtpRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }
  final AuthRepository _authRepository;

  /// Check if user is authenticated on app start
  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthChecking());
    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        // User is already logged in, no need to show auth screens
        emit(
          AuthAuthenticated(
            userProfile: UserProfile(id: '', email: ''),
          ),
        );
      } else {
        // User needs to authenticate
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
      emit(LoginSuccess(accessToken: response.accessToken));
      // Emit authenticated state after successful login
      emit(
        AuthAuthenticated(
          userProfile: UserProfile(id: '', email: ''),
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
      emit(RegisterSuccess(accessToken: response.accessToken));
      // Emit authenticated state after successful registration
      emit(
        AuthAuthenticated(
          userProfile: UserProfile(
            id: '',
            email: event.email,
            username: event.username,
          ),
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
}
