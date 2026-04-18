import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_divider_with_text.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_text_input_field.dart';
import 'package:music_room/features/auth/presentation/widgets/social_login_button.dart';
import 'package:music_room/routes/route_names.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
  });

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Email or username is required';
      } else if (value.contains('@') &&
          !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
        _emailError = 'Enter a valid email or username';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
      } else {
        _passwordError = null;
      }
    });
  }

  void _handleSignIn() {
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_emailError == null && _passwordError == null) {
      context.read<AuthBloc>().add(
        LoginRequested(
          identifier: _emailController.text,
          password: _passwordController.text,
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is LoginLoading) {
          AppSnackbar.showInfo(
            context,
            'Signing in...',
            duration: const Duration(seconds: 1),
          );
        } else if (state is LoginSuccess) {
          AppSnackbar.showSuccess(context, 'Signed in successfully!');
          unawaited(
            Navigator.of(context).pushNamedAndRemoveUntil(
              RouteNames.home,
              (_) => false,
            ),
          );
        } else if (state is LoginFailure) {
          AppSnackbar.showError(context, state.failure.message);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthScreenHeader(
                  title: 'Welcome back',
                  subtitle: 'Sign in to your account',
                ),

                AuthTextInputField(
                  label: 'Email or username',
                  icon: Icons.mail_outline,
                  placeholder: 'Email or username',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _validateEmail,
                  errorText: _emailError,
                ),
                const SizedBox(height: 16),

                // Password Input
                AuthTextInputField(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  placeholder: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: _validatePassword,
                  errorText: _passwordError,
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _handleForgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is LoginLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AppButton(
                        onPressed: isLoading ? null : _handleSignIn,
                        label: 'Sign in',
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
                    // TODO(mtigunit): Implement Google login.
                  },
                ),
                const SizedBox(height: 24),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
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
                              RouteNames.signUp,
                            ),
                          );
                        },
                        child: Text(
                          'Sign up',
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
