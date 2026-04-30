import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/auth/presentation/pages/enter_new_password_page.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_text_input_field.dart';
import 'package:music_room/features/auth/presentation/widgets/otp_verification_modal.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();

  String? _emailError;
  String? _requestedEmail;
  bool _isOtpModalOpen = false;
  bool _hasNavigatedToResetPage = false;

  String get _trimmedEmail => _emailController.text.trim();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    final normalizedValue = value.trim();

    setState(() {
      if (normalizedValue.isEmpty) {
        _emailError = 'Email is required';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(normalizedValue)) {
        _emailError = 'Enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  Future<void> _handleRequestResetOtp() async {
    _validateEmail(_trimmedEmail);

    if (_emailError != null) {
      return;
    }

    _requestedEmail = _trimmedEmail;

    context.read<AuthBloc>().add(
      SendPasswordResetOtpRequested(email: _requestedEmail!),
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
        builder: (modalContext) {
          final requestedEmail = _requestedEmail ?? _trimmedEmail;
          return OtpVerificationModal(
            email: requestedEmail,
            onConfirm: (otpCode) {
              context.read<AuthBloc>().add(
                VerifyPasswordResetOtpRequested(
                  email: requestedEmail,
                  code: otpCode,
                ),
              );
            },
            onResend: () {
              context.read<AuthBloc>().add(
                SendPasswordResetOtpRequested(
                  email: requestedEmail,
                ),
              );
            },
          );
        },
      ).whenComplete(() {
        _isOtpModalOpen = false;
      }),
    );
  }

  void _closeOtpModalIfOpen() {
    if (_isOtpModalOpen && mounted) {
      unawaited(Navigator.of(context, rootNavigator: true).maybePop());
    }
    _isOtpModalOpen = false;
  }

  bool _shouldUseGenericForgotPasswordMessage(String failureMessage) {
    final normalizedMessage = failureMessage.toLowerCase();
    const enumerationIndicators = <String>[
      'not found',
      'does not exist',
      'no account',
      'unknown email',
      'user not found',
      'email not registered',
    ];

    return enumerationIndicators.any(normalizedMessage.contains);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordResetOtpLoading) {
          AppSnackbar.showInfo(
            context,
            'Sending reset OTP...',
            duration: const Duration(seconds: 1),
          );
        } else if (state is PasswordResetOtpSent) {
          AppSnackbar.showInfo(
            context,
            'If an account exists, an OTP has been sent to the email.',
          );
          _requestedEmail = state.email;
          if (!_isOtpModalOpen) {
            _showOtpVerificationModal();
          }
        } else if (state is PasswordResetOtpFailure) {
          final failureMessage = state.failure.message.trim();

          if (_shouldUseGenericForgotPasswordMessage(failureMessage)) {
            AppSnackbar.showInfo(
              context,
              'If an account exists, an OTP has been sent to the email.',
            );
            if ((_requestedEmail ?? '').isEmpty) {
              _requestedEmail = _trimmedEmail;
            }
            if (!_isOtpModalOpen) {
              _showOtpVerificationModal();
            }
          } else {
            AppSnackbar.showError(
              context,
              failureMessage.isNotEmpty
                  ? failureMessage
                  : 'Unable to send reset OTP. Please try again.',
            );
          }
        } else if (state is PasswordResetOtpVerified) {
          AppSnackbar.showSuccess(context, 'OTP verified successfully!');
          _closeOtpModalIfOpen();
          if (!_hasNavigatedToResetPage) {
            _hasNavigatedToResetPage = true;
            unawaited(
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => EnterNewPasswordPage(
                        email: state.email,
                        resetToken: state.passwordResetToken,
                      ),
                    ),
                  )
                  .then((_) {
                    if (mounted) {
                      _hasNavigatedToResetPage = false;
                    }
                  }),
            );
          }
        } else if (state is PasswordResetOtpVerificationFailure) {
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
                  title: 'Forgot password?',
                  subtitle:
                      'Enter your registered email address and '
                      'verify OTP to continue.',
                  bottomSpacing: 28,
                ),

                AuthTextInputField(
                  label: 'Email address',
                  icon: Icons.mail_outline,
                  placeholder: 'Email address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _validateEmail,
                  errorText: _emailError,
                ),

                const SizedBox(height: 24),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is PasswordResetOtpLoading;
                    return AppButton(
                      onPressed: isLoading ? null : _handleRequestResetOtp,
                      label: 'Send OTP',
                      isLoading: isLoading,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 18,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1A2432)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF2C405B)
                          : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'After OTP verification, you will be redirected to '
                          'enter a new password.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDarkMode
                                    ? const Color(0xFFC9D5E8)
                                    : const Color(0xFF1E3A5F),
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Center(
                  child: AppButton(
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Back to sign in',
                    foregroundColor: colorScheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
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
