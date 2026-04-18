import 'package:music_room/core/error/failure.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';

/// Abstract repository for authentication operations
abstract class AuthRepository {
  Future<(LoginResponse?, Failure?)> login({
    required String identifier,
    required String password,
  });

  Future<(bool, Failure?)> sendOtp(String email);

  Future<(VerifyOtpResponse?, Failure?)> verifyOtp(
    String email,
    String code,
  );

  Future<(bool, Failure?)> sendPasswordResetOtp(String email);

  Future<(VerifyResetOtpResponse?, Failure?)> verifyPasswordResetOtp(
    String email,
    String code,
  );

  Future<(MessageResponse?, Failure?)> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  });

  Future<(RegisterResponse?, Failure?)> register({
    required String email,
    required String username,
    required String password,
    required String emailVerificationToken,
  });

  Future<(UserProfile?, Failure?)> getProfile();

  Future<void> logout();

  Future<bool> isAuthenticated();
}
