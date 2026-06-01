import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/settings/domain/entities/settings_update_request.dart';
import 'package:music_room/features/settings/presentation/state/settings_bloc.dart';
import 'package:music_room/features/settings/presentation/state/settings_event.dart';
import 'package:music_room/features/settings/presentation/state/settings_state.dart';
import 'package:music_room/features/settings/presentation/widgets/profile_edit_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsBloc _settingsBloc;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _settingsBloc = InjectionContainer().createSettingsBloc()
      ..add(const SettingsRequested());
  }

  @override
  void dispose() {
    unawaited(_settingsBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final formMaxWidth = viewportWidth >= 1200
        ? 1200.0
        : viewportWidth >= 768
        ? 700.0
        : double.infinity;

    return PopScope(
      canPop: !_isSaving,
      child: BlocProvider<SettingsBloc>.value(
        value: _settingsBloc,
        child: BlocListener<SettingsBloc, SettingsState>(
          listenWhen: (previous, current) =>
              current is SettingsMutationSuccess ||
              current is SettingsMutationFailure ||
              current is SettingsPasswordChangeSuccess ||
              current is SettingsPasswordChangeFailure ||
              current is SettingsGoogleLinkSuccess ||
              current is SettingsGoogleLinkFailure ||
              current is SettingsGoogleUnlinkSuccess ||
              current is SettingsGoogleUnlinkFailure,
          listener: (context, state) {
            if (state is SettingsMutationSuccess) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showSuccess(context, state.message);
              if (mounted) {
                Navigator.of(context).pop(true);
              }
              return;
            }

            if (state is SettingsMutationFailure) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showError(context, state.message);
              return;
            }

            if (state is SettingsPasswordChangeSuccess) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showSuccess(context, state.message);
              if (mounted) {
                Navigator.of(context).pop(true);
              }
              return;
            }

            if (state is SettingsPasswordChangeFailure) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showError(context, state.message);
              return;
            }

            if (state is SettingsGoogleLinkSuccess) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showSuccess(context, state.message);
              if (mounted) {
                Navigator.of(context).pop(true);
              }
              return;
            }

            if (state is SettingsGoogleLinkFailure) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showError(context, state.message);
              return;
            }

            if (state is SettingsGoogleUnlinkSuccess) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showSuccess(context, state.message);
              if (mounted) {
                Navigator.of(context).pop(true);
              }
              return;
            }

            if (state is SettingsGoogleUnlinkFailure) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showError(context, state.message);
            }
          },
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              if (state is SettingsInitial || state is SettingsLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (state is SettingsError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              context.read<SettingsBloc>().add(
                                const SettingsRequested(),
                              );
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (state.dataOrNull == null) {
                return const Scaffold(body: SizedBox.shrink());
              }

              return Scaffold(
                body: SizedBox.expand(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: formMaxWidth),
                        child: _SettingsContent(
                          isSaving: _isSaving,
                          onSaveRequested: _handleSaveRequested,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSaveRequested(SettingsUpdateRequest request) {
    if (_isSaving) {
      return;
    }

    final currentProfile = _settingsBloc.state.dataOrNull?.profile;
    if (currentProfile == null) {
      return;
    }

    if (!request.hasChanges(currentUsername: currentProfile.username)) {
      AppSnackbar.showInfo(context, 'No profile changes to save.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _settingsBloc.add(SettingsSaveSubmitted(request: request));
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.isSaving,
    required this.onSaveRequested,
  });

  final bool isSaving;
  final ValueChanged<SettingsUpdateRequest> onSaveRequested;

  @override
  Widget build(BuildContext context) {
    final profileState = context.watch<SettingsBloc>().state;
    final profileData = profileState.dataOrNull;
    if (profileData == null) {
      return const SizedBox.shrink();
    }

    return ProfileEditSheet(
      profile: profileData.profile,
      showDragHandle: false,
      isSaving: isSaving,
      onSaveRequested: onSaveRequested,
    );
  }
}
