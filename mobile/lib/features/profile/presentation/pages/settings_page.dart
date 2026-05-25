import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_edit_sheet.dart';

ProfilePageData? _profileDataFromState(ProfileState state) {
  if (state is ProfileLoaded) {
    return state.data;
  }
  if (state is ProfileMutationInProgress) {
    return state.data;
  }
  if (state is ProfileMutationSuccess) {
    return state.data;
  }
  if (state is ProfileMutationFailure) {
    return state.data;
  }
  if (state is ProfilePasswordChangeInProgress) {
    return state.data;
  }
  if (state is ProfilePasswordChangeSuccess) {
    return state.data;
  }
  if (state is ProfilePasswordChangeFailure) {
    return state.data;
  }
  if (state is ProfileGoogleLinkInProgress) {
    return state.data;
  }
  if (state is ProfileGoogleLinkSuccess) {
    return state.data;
  }
  if (state is ProfileGoogleLinkFailure) {
    return state.data;
  }
  if (state is ProfileGoogleUnlinkInProgress) {
    return state.data;
  }
  if (state is ProfileGoogleUnlinkSuccess) {
    return state.data;
  }
  if (state is ProfileGoogleUnlinkFailure) {
    return state.data;
  }
  return null;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.userId});

  final String? userId;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ProfileBloc _profileBloc;

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
    return BlocProvider<ProfileBloc>.value(
      value: _profileBloc,
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

          if (_profileDataFromState(state) == null) {
            return const Scaffold(body: SizedBox.shrink());
          }

          return Scaffold(
            body: SizedBox.expand(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: const _SettingsContent(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final profileState = context.watch<ProfileBloc>().state;
    final profileData = _profileDataFromState(profileState);
    if (profileData == null) {
      return const SizedBox.shrink();
    }

    return ProfileEditSheet(
      profile: profileData.profile,
      showDragHandle: false,
    );
  }
}
