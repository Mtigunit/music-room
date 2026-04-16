import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_divider_with_text.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_text_input_field.dart';
import 'package:music_room/features/auth/presentation/widgets/otp_verification_modal.dart';
import 'package:music_room/features/auth/presentation/widgets/social_login_button.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    required this.onSwitchToSignIn,
    super.key,
  });

  final VoidCallback onSwitchToSignIn;

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
  bool _isOtpModalOpen = false;

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
          email: _emailController.text,
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

    if (_emailVerificationToken == null) {
      AppSnackbar.showError(
        context,
        'Please verify your email before creating an account.',
      );
      return;
    }

    context.read<AuthBloc>().add(
      RegisterRequested(
        email: _emailController.text,
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
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (_) => OtpVerificationModal(
          email: _emailController.text,
          onConfirm: (otpCode) {
            context.read<AuthBloc>().add(
              VerifyOtpRequested(
                email: _emailController.text,
                code: otpCode,
              ),
            );
          },
          onResend: () {
            context.read<AuthBloc>().add(
              SendOtpRequested(
                email: _emailController.text,
              ),
            );
          },
        ),
      ).whenComplete(() {
        _isOtpModalOpen = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
          _isOtpModalOpen = false;
          Navigator.of(context).pop(); // Close OTP modal
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
        } else if (state is RegisterFailure) {
          AppSnackbar.showError(context, state.failure.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    final isLoading = state is OtpLoading;
                    final isVerified =
                        state is OtpVerified || _emailVerificationToken != null;

                    return AuthTextInputField(
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      placeholder: 'Email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: _validateEmail,
                      errorText: _emailError,
                      enabled: !isVerified,
                      suffixWidget: GestureDetector(
                        onTap: isLoading || isVerified
                            ? null
                            : _handleVerifyEmail,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: isLoading
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
                    final isLoading = state is RegisterLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AppButton(
                        onPressed: isLoading ? null : _handleCreateAccount,
                        label: 'Create Account',
                        isLoading: isLoading,
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
                  onPressed: () {
                    // TODO(mtigunit): Implement Google signup.
                  },
                ),
                const SizedBox(height: 12),
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
                        onTap: widget.onSwitchToSignIn,
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
