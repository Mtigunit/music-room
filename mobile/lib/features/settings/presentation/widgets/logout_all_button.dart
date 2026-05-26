import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';

class LogoutAllButton extends StatelessWidget {
  const LogoutAllButton({required this.onLogout, super.key});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          current is LogoutLoading ||
          current is LogoutFailure ||
          current is LogoutSuccess ||
          current is AuthUnauthenticated,
      builder: (context, authState) {
        final isLogoutLoading = authState is LogoutLoading;

        return SizedBox(
          width: double.infinity,
          child: AppButton(
            onPressed: isLogoutLoading ? null : onLogout,
            isLoading: isLogoutLoading,
            label: 'Log out from all devices',
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      },
    );
  }
}
