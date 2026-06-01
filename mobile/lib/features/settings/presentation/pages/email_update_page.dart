import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/widgets/otp_verification_modal.dart';

class EmailUpdatePage extends StatefulWidget {
  const EmailUpdatePage({super.key});

  @override
  State<EmailUpdatePage> createState() => _EmailUpdatePageState();
}

class _EmailUpdatePageState extends State<EmailUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isOtpModalOpen = false;
  String? _requestedEmail;
  String? _requestedPassword;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: _buildRequestForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: FormInputDecoration.build(
              theme,
              labelText: null,
              hintText: 'new.address@example.com',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter a new email';
              final email = v.trim();
              final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!regex.hasMatch(email)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: FormInputDecoration.build(
              theme,
              labelText: null,
              hintText: 'Current password',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              if (v.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _isLoading ? null : _submitRequest,
              isLoading: _isLoading,
              label: 'Send OTP',
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repo = InjectionContainer().settingsRepository;
    try {
      await repo.requestEmailUpdate(
        newEmail: _emailController.text.trim(),
        password: _passwordController.text,
      );

      _requestedEmail = _emailController.text.trim();
      _requestedPassword = _passwordController.text;
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'OTP sent to your new email.');
      _showOtpVerificationModal();
      setState(() => _isLoading = false);
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      AppSnackbar.showError(context, _mapRequestError(e));
    } on Object catch (_) {
      setState(() => _isLoading = false);
      AppSnackbar.showError(
        context,
        'Unable to start the email update. Please try again.',
      );
    }
  }

  void _showOtpVerificationModal() {
    if (_isOtpModalOpen) {
      return;
    }

    final requestedEmail = _requestedEmail;
    final requestedPassword = _requestedPassword;
    if (requestedEmail == null || requestedPassword == null) {
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
          return OtpVerificationModal(
            title: 'Verify email update',
            message: 'We sent a 6-digit code to',
            destination: requestedEmail,
            confirmLabel: 'Verify',
            onConfirm: (otpCode) async {
              final repo = InjectionContainer().settingsRepository;
              try {
                await repo.verifyEmailUpdate(code: otpCode);
                if (!modalContext.mounted) return;
                if (!mounted) return;

                Navigator.of(modalContext).pop();
                AppSnackbar.showSuccess(context, 'Email updated');
                Navigator.of(context).pop(true);
              } on DioException catch (e) {
                if (mounted) {
                  AppSnackbar.showError(context, _mapVerifyError(e));
                }
              } on Object catch (_) {
                if (mounted) {
                  AppSnackbar.showError(
                    context,
                    'Unable to verify the code. Please try again.',
                  );
                }
              }
            },
            onResend: () {
              final repo = InjectionContainer().settingsRepository;
              unawaited(
                repo
                    .requestEmailUpdate(
                      newEmail: requestedEmail,
                      password: requestedPassword,
                    )
                    .catchError((Object error) {
                      if (mounted && error is DioException) {
                        AppSnackbar.showError(
                          context,
                          _mapRequestError(error),
                        );
                      }
                    }),
              );
            },
          );
        },
      ).whenComplete(() {
        _isOtpModalOpen = false;
      }),
    );
  }

  String _mapRequestError(DioException error) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractErrorMessage(error.response?.data);

    return switch (statusCode) {
      400 =>
        serverMessage ??
            'Unable to request the email update. '
                'Check your password and try again.',
      401 => 'Invalid current password. Please enter the correct password.',
      404 => serverMessage ?? 'Your account could not be found.',
      409 => serverMessage ?? 'This email address is already in use.',
      429 =>
        serverMessage ??
            'Too many OTP requests. Please wait a moment and try again.',
      500 =>
        'The server could not process the request. Please try again later.',
      _ =>
        serverMessage ??
            'Unable to request the email update. Please try again.',
    };
  }

  String _mapVerifyError(DioException error) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractErrorMessage(error.response?.data);

    return switch (statusCode) {
      400 =>
        serverMessage ?? 'Invalid or expired OTP. Please request a new code.',
      404 => serverMessage ?? 'Your account could not be found.',
      429 => serverMessage ?? 'Too many attempts. Please wait and try again.',
      500 => 'The server could not verify the code. Please try again later.',
      _ => serverMessage ?? 'Unable to verify the code. Please try again.',
    };
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final error = responseData['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }

      final details = responseData['details'];
      if (details is String && details.trim().isNotEmpty) {
        return details.trim();
      }
    }

    return null;
  }
}
