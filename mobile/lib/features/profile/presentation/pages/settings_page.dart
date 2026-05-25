import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_edit_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.userId});

  final String? userId;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ProfileBloc _profileBloc;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profileBloc = InjectionContainer().createProfileBloc()
      ..add(ProfileRequested(userId: widget.userId));
  }

  @override
  void dispose() {
    unawaited(_profileBloc.close());
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
      child: BlocProvider<ProfileBloc>.value(
        value: _profileBloc,
        child: BlocListener<ProfileBloc, ProfileState>(
          listenWhen: (previous, current) =>
              current is ProfileMutationSuccess ||
              current is ProfileMutationFailure,
          listener: (context, state) {
            if (!_isSaving) {
              return;
            }

            if (state is ProfileMutationSuccess) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showSuccess(context, state.message);
              if (mounted) {
                Navigator.of(context).pop(true);
              }
              return;
            }

            if (state is ProfileMutationFailure) {
              setState(() {
                _isSaving = false;
              });
              AppSnackbar.showError(context, state.message);
            }
          },
          child: BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileInitial || state is ProfileLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (state is ProfileError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        state.message,
                        textAlign: TextAlign.center,
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

  void _handleSaveRequested(ProfileUpdateRequest request) {
    if (_isSaving) {
      return;
    }

    final currentProfile = _profileBloc.state.dataOrNull?.profile;
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

    _profileBloc.add(ProfileEditSubmitted(request: request));
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.isSaving,
    required this.onSaveRequested,
  });

  final bool isSaving;
  final ValueChanged<ProfileUpdateRequest> onSaveRequested;

  @override
  Widget build(BuildContext context) {
    final profileState = context.watch<ProfileBloc>().state;
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
