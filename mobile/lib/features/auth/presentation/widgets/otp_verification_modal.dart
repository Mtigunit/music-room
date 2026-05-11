import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/widgets/app_button.dart';

class OtpVerificationModal extends StatefulWidget {
  const OtpVerificationModal({
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onResend,
    super.key,
    this.destination,
    this.confirmLabel = 'Confirm',
  });

  final String title;
  final String message;
  final String? destination;
  final void Function(String otpCode) onConfirm;
  final VoidCallback onResend;
  final String confirmLabel;

  @override
  State<OtpVerificationModal> createState() => _OtpVerificationModalState();
}

class _OtpVerificationModalState extends State<OtpVerificationModal> {
  static const int _otpLength = AppConfig.otpLength;
  static const int _initialResendSeconds = AppConfig.otpResendTimeoutSeconds;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late Timer _timer;
  int _remainingSeconds = _initialResendSeconds;
  bool _canResend = false;

  int get _lastOtpIndex => _otpLength - 1;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startTimer();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        return;
      }

      setState(() {
        _canResend = true;
      });
      timer.cancel();
    });
  }

  void _handleResend() {
    if (!_canResend) {
      return;
    }

    widget.onResend();
    setState(() {
      _remainingSeconds = _initialResendSeconds;
      _canResend = false;
    });
    _startTimer();
  }

  void _onOtpDigitChanged(String value, int index) {
    if (value.length > 1) {
      _applyPastedOtp(value, index);
      return;
    }

    if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (index < _lastOtpIndex) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
  }

  void _applyPastedOtp(String value, int startIndex) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return;
    }

    var writeIndex = startIndex;
    for (final digit in digits.split('')) {
      if (writeIndex > _lastOtpIndex) {
        break;
      }
      _controllers[writeIndex].text = digit;
      writeIndex++;
    }

    if (writeIndex <= _lastOtpIndex) {
      _focusNodes[writeIndex].requestFocus();
    } else {
      _focusNodes[_lastOtpIndex].unfocus();
    }
  }

  String get _otpValue =>
      _controllers.map((controller) => controller.text).join();

  bool get _isOtpComplete => _otpValue.length == _otpLength;

  void _handleConfirm() {
    final otp = _otpValue;
    if (otp.length == _otpLength) {
      widget.onConfirm(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = isDarkMode ? const Color(0xFF151827) : Colors.white;
    final secondaryText = isDarkMode
        ? const Color(0xFF7E8394)
        : const Color(0xFF6F7585);
    final mutedText = isDarkMode
        ? const Color(0xFF555B6B)
        : const Color(0xFF8A90A1);
    final inputFill = isDarkMode
        ? const Color(0xFF202434)
        : const Color(0xFFF2F4F9);
    final inputBorder = isDarkMode
        ? const Color(0xFF3A3F54)
        : const Color(0xFFD7DBE6);
    final disabledButton = isDarkMode
        ? const Color(0xFF2C3040)
        : const Color(0xFFE4E7F1);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.fromLTRB(24, 10, 24, 20 + keyboardHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                child: Container(
                  width: 58,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF3B3F50)
                        : const Color(0xFFD0D5E3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 44 / 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode
                            ? const Color(0xFF282C3C)
                            : const Color(0xFFE8EBF3),
                      ),
                      child: Icon(Icons.close, color: mutedText, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: [
                    TextSpan(
                      text: '${widget.message}\n',
                      style: TextStyle(
                        color: secondaryText,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.destination != null)
                      TextSpan(
                        text: widget.destination,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  _otpLength,
                  (index) => SizedBox(
                    width: 50,
                    height: 68,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      maxLength: _otpLength,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        _onOtpDigitChanged(value, index);
                        setState(() {});
                      },
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputFill,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Resend in $_remainingSeconds s',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_canResend)
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed: _handleResend,
                      label: 'Resend',
                      foregroundColor: colorScheme.primary,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: AppButton(
                  onPressed: _isOtpComplete ? _handleConfirm : null,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: disabledButton,
                  disabledForegroundColor: mutedText,
                  borderRadius: 20,
                  label: widget.confirmLabel,
                  textStyle: const TextStyle(
                    fontSize: 34 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
