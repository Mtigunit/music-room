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
  final TextEditingController _identifierController = TextEditingController();

  String? _identifierError;
  bool _isOtpModalOpen = false;
  bool _hasNavigatedToResetPage = false;
  BuildContext? _otpModalContext;

  String get _trimmedIdentifier => _identifierController.text.trim();

  String _sanitizeIdentifier(String value) => value.trim();

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _validateIdentifier(String value) {
    final normalized = value.trim();
    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');

    setState(() {
      if (normalized.isEmpty) {
        _identifierError = 'Email or phone number is required';
      } else if (normalized.contains('@') &&
          !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(normalized)) {
        _identifierError = 'Enter a valid email address';
      } else if (!normalized.contains('@') &&
          (digitsOnly.length < 10 || digitsOnly.length > 15)) {
        _identifierError = 'Enter a valid phone number';
      } else {
        _identifierError = null;
      }
    });
  }

  Future<void> _handleRequestResetOtp() async {
    _validateIdentifier(_identifierController.text);

    if (_identifierError != null) {
      return;
    }

    context.read<AuthBloc>().add(
      SendPasswordResetOtpRequested(email: _trimmedIdentifier),
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
          _otpModalContext = modalContext;
          return OtpVerificationModal(
            email: _trimmedIdentifier,
            onConfirm: (otpCode) {
              context.read<AuthBloc>().add(
                VerifyPasswordResetOtpRequested(
                  email: _trimmedIdentifier,
                  code: otpCode,
                ),
              );
            },
            onResend: () {
              context.read<AuthBloc>().add(
                SendPasswordResetOtpRequested(
                  email: _trimmedIdentifier,
                ),
              );
            },
          );
        },
      ).whenComplete(() {
        _isOtpModalOpen = false;
        _otpModalContext = null;
      }),
    );
  }

  void _closeOtpModalIfOpen() {
    if (_isOtpModalOpen && _otpModalContext != null) {
      final modalNavigator = Navigator.of(_otpModalContext!);
      if (modalNavigator.canPop()) {
        modalNavigator.pop();
      }
    }
    _isOtpModalOpen = false;
    _otpModalContext = null;
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
          AppSnackbar.showSuccess(context, 'OTP sent to ${state.email}');
          if (!_isOtpModalOpen) {
            _showOtpVerificationModal();
          }
        } else if (state is PasswordResetOtpFailure) {
          AppSnackbar.showError(context, state.failure.message);
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
                        identifier: _sanitizeIdentifier(state.email),
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
                      'Enter your registered email or phone number and '
                      'verify OTP to continue.',
                  bottomSpacing: 28,
                ),

                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading =
                        state is PasswordResetOtpLoading ||
                        state is PasswordResetOtpVerifying;

                    return AuthTextInputField(
                      label: 'Email or phone number',
                      icon: Icons.mail_outline,
                      placeholder: 'Email or phone number',
                      controller: _identifierController,
                      onChanged: _validateIdentifier,
                      errorText: _identifierError,
                      suffixWidget: GestureDetector(
                        onTap: isLoading ? null : _handleRequestResetOtp,
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
                                  'Send OTP',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is PasswordResetOtpLoading;
                    return AppButton(
                      onPressed: isLoading ? null : _handleRequestResetOtp,
                      label: 'Request OTP',
                      isLoading: isLoading,
                      borderRadius: 16,
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
                          'create a new password.',
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
