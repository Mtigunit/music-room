import 'package:flutter/material.dart';
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
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _fullNameError;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;

  bool _emailVerified = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateFullName(String value) {
    setState(() {
      if (value.isEmpty) {
        _fullNameError = 'Full name is required';
      } else {
        _fullNameError = null;
      }
    });
  }

  void _validateUsername(String value) {
    setState(() {
      if (value.isEmpty) {
        _usernameError = 'Username is required';
      } else if (value.length < 3) {
        _usernameError = 'At least 3 characters';
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
      } else {
        _passwordError = null;
      }
    });
  }

  Future<void> _showOtpVerificationModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => OtpVerificationModal(
        email: _emailController.text,
        onConfirm: (otpCode) {
          // Validate OTP code (in demo, any code except 000000 works)
          if (otpCode != '000000') {
            setState(() {
              _emailVerified = true;
            });
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully!'),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid verification code'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        onResend: () {
          // Handle resend logic
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code resent'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleVerifyEmail() async {
    _validateEmail(_emailController.text);
    if (_emailError == null && _emailController.text.isNotEmpty) {
      await _showOtpVerificationModal();
    }
  }

  void _handleCreateAccount() {
    _validateFullName(_fullNameController.text);
    _validateUsername(_usernameController.text);
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_fullNameError == null &&
        _usernameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _emailVerified) {
      // Handle account creation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              Icons.arrow_back,
              color: isDarkMode ? Colors.white : Colors.black87,
              size: 25,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Create account',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join the Music Room community',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Full Name Input
              AuthTextInputField(
                label: 'Full name',
                icon: Icons.person_outline,
                placeholder: 'Full name',
                controller: _fullNameController,
                onChanged: _validateFullName,
                errorText: _fullNameError,
              ),
              const SizedBox(height: 16),

              // Username Input
              AuthTextInputField(
                label: 'Username',
                icon: Icons.alternate_email,
                placeholder: 'username',
                controller: _usernameController,
                onChanged: _validateUsername,
                errorText: _usernameError,
              ),
              const SizedBox(height: 16),

              // Email Input with Verify Button
              AuthTextInputField(
                label: 'Email address',
                icon: Icons.mail_outline,
                placeholder: 'Email address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _validateEmail,
                errorText: _emailError,
                suffixWidget: GestureDetector(
                  onTap: _handleVerifyEmail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _emailVerified ? 'Verified' : 'Verify',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _emailVerified
                            ? Colors.green
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password Input
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

              // Create Account Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _handleCreateAccount,
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Divider with "or continue with"
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Social Login Buttons
              SocialLoginButton(
                provider: SocialProvider.google,
                onPressed: () {
                  // Handle Google login
                },
              ),
              const SizedBox(height: 12),
              SocialLoginButton(
                provider: SocialProvider.facebook,
                onPressed: () {
                  // Handle Facebook login
                },
              ),
              const SizedBox(height: 24),

              // Sign In Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
    );
  }
}
