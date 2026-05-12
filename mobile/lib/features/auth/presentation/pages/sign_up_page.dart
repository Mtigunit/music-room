import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_divider_with_text.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_page_layout.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_text_input_field.dart';
import 'package:music_room/features/auth/presentation/widgets/show_otp_modal.dart';
import 'package:music_room/features/auth/presentation/widgets/social_login_button.dart';
import 'package:music_room/routes/route_names.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
  });

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _usernameError;
  String? _emailError;
  String? _passwordError;

  String? _emailVerificationToken;
  String? _verifiedEmail;
  bool _isOtpModalOpen = false;

  String get _trimmedEmail => _emailController.text.trim();

  String _sanitizeEmail(String value) => value.trim();

  bool get _isEmailVerified {
    if (_emailVerificationToken == null || _verifiedEmail == null) {
      return false;
    }
    return _verifiedEmail == _trimmedEmail;
  }

  void _clearEmailVerification() {
    _emailVerificationToken = null;
    _verifiedEmail = null;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateUsername(String value) {
    setState(() {
      if (value.isEmpty) {
        _usernameError = 'Username is required';
      } else if (value.length < 3) {
        _usernameError = 'At least 3 characters';
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
        _usernameError = 'Only letters, numbers, and underscores';
      } else {
        _usernameError = null;
      }
    });
  }

  void _validateEmail(String value) {
    setState(() {
      if (_verifiedEmail != null && _sanitizeEmail(value) != _verifiedEmail) {
        _clearEmailVerification();
      }

      if (value.isEmpty) {
        _emailError = 'Email is required';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
        _emailError = 'Enter a valid email';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
      } else if (value.length < 8) {
        _passwordError = 'At least 8 characters';
      } else if (!RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])',
      ).hasMatch(value)) {
        _passwordError =
            'Must include uppercase, lowercase, number, and special character';
      } else {
        _passwordError = null;
      }
    });
  }

  Future<void> _handleVerifyEmail() async {
    _validateEmail(_emailController.text);
    if (_emailError == null) {
      context.read<AuthBloc>().add(
        SendOtpRequested(
          email: _trimmedEmail,
        ),
      );
    }
  }

  void _handleCreateAccount() {
    _validateUsername(_usernameController.text);
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_usernameError != null ||
        _emailError != null ||
        _passwordError != null) {
      return;
    }

    if (!_isEmailVerified) {
      AppSnackbar.showError(
        context,
        'Please verify your email before creating an account.',
      );
      return;
    }

    context.read<AuthBloc>().add(
      RegisterRequested(
        email: _trimmedEmail,
        username: _usernameController.text,
        password: _passwordController.text,
        emailVerificationToken: _emailVerificationToken!,
      ),
    );
  }

  void _showOtpVerificationModal() {
    if (_isOtpModalOpen) {
      return;
    }

    _isOtpModalOpen = true;

    unawaited(
      showOtpModal(
        context: context,
        title: 'Verify your email',
        message: 'We sent a 6-digit code to',
        destination: _trimmedEmail,
        onConfirm: (otpCode) {
          context.read<AuthBloc>().add(
            VerifyOtpRequested(
              email: _trimmedEmail,
              code: otpCode,
            ),
          );
        },
        onResend: () {
          context.read<AuthBloc>().add(
            SendOtpRequested(
              email: _trimmedEmail,
            ),
          );
        },
      ).whenComplete(() {
        _isOtpModalOpen = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final isRegisterLoading = authState is RegisterLoading;
    final isGoogleLoading = authState is GoogleLoginLoading;
    final isOtpLoading = authState is OtpLoading;
    final isAnyLoading = isRegisterLoading || isGoogleLoading || isOtpLoading;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is OtpLoading) {
          AppSnackbar.showInfo(
            context,
            'Sending OTP...',
            duration: const Duration(seconds: 1),
          );
        } else if (state is OtpSent) {
          AppSnackbar.showSuccess(context, 'OTP sent to ${state.email}');
          if (!_isOtpModalOpen) {
            _showOtpVerificationModal();
          }
        } else if (state is OtpFailure) {
          AppSnackbar.showError(context, state.failure.message);
        } else if (state is OtpVerifying) {
          // Show loading while verifying
        } else if (state is OtpVerified) {
          AppSnackbar.showSuccess(context, 'Email verified successfully!');
          _emailVerificationToken = state.emailVerificationToken;
          _verifiedEmail = _sanitizeEmail(state.email);
          if (_isOtpModalOpen && mounted) {
            unawaited(
              Navigator.of(context, rootNavigator: true).maybePop(),
            );
          }
          _isOtpModalOpen = false;
        } else if (state is OtpVerificationFailure) {
          AppSnackbar.showError(context, state.failure.message);
        } else if (state is RegisterLoading) {
          AppSnackbar.showInfo(
            context,
            'Creating account...',
            duration: const Duration(seconds: 1),
          );
        } else if (state is RegisterSuccess) {
          AppSnackbar.showSuccess(context, 'Account created successfully!');
          unawaited(
            Navigator.of(context).pushNamedAndRemoveUntil(
              RouteNames.completeProfile,
              (_) => false,
            ),
          );
        } else if (state is RegisterFailure) {
          AppSnackbar.showError(context, state.failure.message);
        } else if (state is GoogleLoginLoading) {
          AppSnackbar.showInfo(
            context,
            'Creating account with Google...',
            duration: const Duration(seconds: 1),
          );
        } else if (state is GoogleLoginSuccess) {
          AppSnackbar.showSuccess(context, 'Account created with Google!');
          unawaited(
            Navigator.of(context).pushNamedAndRemoveUntil(
              RouteNames.completeProfile,
              (_) => false,
            ),
          );
        } else if (state is GoogleLoginFailure) {
          AppSnackbar.showError(context, state.failure.message);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: AuthPageLayout(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthScreenHeader(
                  title: 'Create account',
                  subtitle: 'Join the Music Room community',
                ),

                AuthTextInputField(
                  label: 'Username',
                  icon: Icons.alternate_email,
                  placeholder: 'username',
                  controller: _usernameController,
                  onChanged: _validateUsername,
                  errorText: _usernameError,
                ),
                const SizedBox(height: 16),

                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isVerified = _isEmailVerified;

                    return AuthTextInputField(
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      placeholder: 'Email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: _validateEmail,
                      errorText: _emailError,
                      enabled: !isVerified && !isAnyLoading,
                      suffixWidget: GestureDetector(
                        onTap: isOtpLoading || isVerified || isAnyLoading
                            ? null
                            : _handleVerifyEmail,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: isOtpLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Text(
                                  isVerified ? '✓ Verified' : 'Verify',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isVerified
                                        ? Colors.green
                                        : colorScheme.primary,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                AuthTextInputField(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  placeholder: 'Password (min. 8 chars)',
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: _validatePassword,
                  errorText: _passwordError,
                ),
                const SizedBox(height: 32),

                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AppButton(
                        onPressed: isAnyLoading ? null : _handleCreateAccount,
                        label: 'Create Account',
                        isLoading: isRegisterLoading,
                        foregroundColor: Colors.white,
                        borderRadius: 16,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                const AuthDividerWithText(text: 'or continue with'),
                const SizedBox(height: 16),

                SocialLoginButton(
                  provider: SocialProvider.google,
                  isLoading: isGoogleLoading,
                  isEnabled: !isAnyLoading,
                  onPressed: () {
                    if (isAnyLoading) {
                      return;
                    }

                    context.read<AuthBloc>().add(const GoogleLoginRequested());
                  },
                ),
                const SizedBox(height: 24),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          unawaited(
                            Navigator.of(context).pushReplacementNamed(
                              RouteNames.auth,
                            ),
                          );
                        },
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
