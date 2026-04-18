import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_text_input_field.dart';
import 'package:music_room/routes/route_names.dart';

class EnterNewPasswordPage extends StatefulWidget {
  const EnterNewPasswordPage({
    required this.identifier,
    required this.resetToken,
    super.key,
  });

  final String identifier;
  final String resetToken;

  @override
  State<EnterNewPasswordPage> createState() => _EnterNewPasswordPageState();
}

class _EnterNewPasswordPageState extends State<EnterNewPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateNewPassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _newPasswordError = 'New password is required';
      } else if (value.length < 8) {
        _newPasswordError = 'At least 8 characters';
      } else if (!RegExp('(?=.*[a-z])').hasMatch(value)) {
        _newPasswordError = 'Must include at least one lowercase letter';
      } else if (!RegExp('(?=.*[A-Z])').hasMatch(value)) {
        _newPasswordError = 'Must include at least one uppercase letter';
      } else if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
        _newPasswordError = 'Must include at least one number';
      } else if (!RegExp(r'(?=.*[@$!%*?&._-])').hasMatch(value)) {
        _newPasswordError = 'Must include at least one special character';
      } else {
        _newPasswordError = null;
      }

      if (_confirmPasswordController.text.isNotEmpty) {
        if (_confirmPasswordController.text != value) {
          _confirmPasswordError = 'Passwords do not match';
        } else {
          _confirmPasswordError = null;
        }
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _confirmPasswordError = 'Confirm your new password';
      } else if (value != _newPasswordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _handleSubmit() {
    _validateNewPassword(_newPasswordController.text);
    _validateConfirmPassword(_confirmPasswordController.text);

    if (_newPasswordError != null || _confirmPasswordError != null) {
      return;
    }

    context.read<AuthBloc>().add(
      ResetPasswordRequested(
        email: widget.identifier,
        resetToken: widget.resetToken,
        newPassword: _newPasswordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ResetPasswordLoading) {
          AppSnackbar.showInfo(
            context,
            'Resetting password...',
            duration: const Duration(seconds: 1),
          );
        } else if (state is ResetPasswordSuccess) {
          AppSnackbar.showSuccess(context, state.message);
          unawaited(
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(RouteNames.auth, (_) => false),
          );
        } else if (state is ResetPasswordFailure) {
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
                  title: 'Enter new password',
                  subtitle:
                      'Set a new password to complete your reset request.',
                  bottomSpacing: 28,
                ),
                AuthTextInputField(
                  label: 'New password',
                  icon: Icons.lock_outline,
                  placeholder: 'New password (min. 8 chars)',
                  controller: _newPasswordController,
                  obscureText: true,
                  onChanged: _validateNewPassword,
                  errorText: _newPasswordError,
                ),
                const SizedBox(height: 16),
                AuthTextInputField(
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  placeholder: 'Confirm new password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  onChanged: _validateConfirmPassword,
                  errorText: _confirmPasswordError,
                ),
                const SizedBox(height: 24),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is ResetPasswordLoading;
                    return AppButton(
                      onPressed: isLoading ? null : _handleSubmit,
                      label: 'Reset password',
                      isLoading: isLoading,
                      borderRadius: 16,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
