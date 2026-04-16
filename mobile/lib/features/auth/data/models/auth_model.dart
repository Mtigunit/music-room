import 'package:json_annotation/json_annotation.dart';

part 'auth_model.g.dart';

/// Response model for /auth/send-otp endpoint
@JsonSerializable()
class SendOtpResponse {

  SendOtpResponse({required this.message});

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) =>
      _$SendOtpResponseFromJson(json);
  final String message;

  Map<String, dynamic> toJson() => _$SendOtpResponseToJson(this);
}

/// Response model for /auth/verify-otp endpoint
@JsonSerializable()
class VerifyOtpResponse {

  VerifyOtpResponse({required this.emailVerificationToken});

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) =>
      _$VerifyOtpResponseFromJson(json);
  final String emailVerificationToken;

  Map<String, dynamic> toJson() => _$VerifyOtpResponseToJson(this);
}

/// Response model for /auth/register endpoint
@JsonSerializable()
class RegisterResponse {

  RegisterResponse({required this.accessToken});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      _$RegisterResponseFromJson(json);
  @JsonKey(name: 'access_token')
  final String accessToken;

  Map<String, dynamic> toJson() => _$RegisterResponseToJson(this);
}

/// Response model for /auth/login endpoint
@JsonSerializable()
class LoginResponse {

  LoginResponse({required this.accessToken});

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
  @JsonKey(name: 'access_token')
  final String accessToken;

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

/// Response model for /auth/profile endpoint
@JsonSerializable()
class UserProfile {

  UserProfile({
    required this.id,
    required this.email,
    this.username,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
  final String id;
  final String email;
  final String? username;

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
