import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_details_page.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_edit_sheet.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_view.dart';
import 'package:music_room/routes/route_names.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.userId});

  final String? userId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      child: _ProfilePageBody(userId: widget.userId),
    );
  }
}

class _ProfilePageBody extends StatelessWidget {
  const _ProfilePageBody({this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (previous, current) =>
          current is ProfileMutationSuccess ||
          current is ProfileMutationFailure,
      listener: (context, state) {
        if (state is ProfileMutationSuccess) {
          AppSnackbar.showSuccess(context, state.message);
        }
        if (state is ProfileMutationFailure) {
          AppSnackbar.showError(context, state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProfileState state) {
    if (state is ProfileInitial || state is ProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ProfileError) {
      return _ProfileErrorView(
        message: state.message,
        onRetry: () {
          context.read<ProfileBloc>().add(
            ProfileRequested(userId: userId),
          );
        },
      );
    }

    final profileData = _profileDataFromState(state);
    if (profileData == null) {
      return const SizedBox.shrink();
    }

    final isBusy = state is ProfileMutationInProgress;

    return ProfileView(
      data: profileData,
      isBusy: isBusy,
      busyLabel: state is ProfileMutationInProgress ? state.message : null,
      onEditProfile: profileData.profile.isSelf
          ? () => _showEditSheet(context, profileData.profile)
          : null,
      onChangeAvatar: profileData.profile.isSelf
          ? () => _pickAndUploadAvatar(context)
          : null,
      onLogout: profileData.profile.isSelf
          ? () => context.read<AuthBloc>().add(const LogoutRequested())
          : null,
      onOpenRoom: (room) {
        unawaited(
          Navigator.of(context).pushNamed(
            RouteNames.preEvent,
            arguments: room.id,
          ),
        );
      },
      onOpenPlaylist: (playlist) {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlaylistDetailsPage(
                playlistId: playlist.id,
                playlistName: playlist.name,
              ),
            ),
          ),
        );
      },
      onRefresh: () async {
        final bloc = context.read<ProfileBloc>();
        final refreshComplete = bloc.stream
            .firstWhere(
              (nextState) =>
                  nextState is ProfileLoaded || nextState is ProfileError,
            )
            .timeout(const Duration(seconds: 20));
        bloc.add(ProfileRefreshRequested(userId: userId));
        try {
          await refreshComplete;
        } on TimeoutException {
          // Let the bloc state drive the visible error.
        }
      },
    );
  }

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
    return null;
  }

  Future<void> _showEditSheet(
    BuildContext context,
    UserProfileEntity profile,
  ) async {
    final request = await showModalBottomSheet<ProfileUpdateRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProfileEditSheet(profile: profile),
    );

    if (request == null || !context.mounted) {
      return;
    }

    if (request.toJson().isEmpty) {
      AppSnackbar.showInfo(context, 'No profile changes to save.');
      return;
    }

    context.read<ProfileBloc>().add(ProfileEditSubmitted(request: request));
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final avatar = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );

    if (avatar == null || !context.mounted) {
      return;
    }

    context.read<ProfileBloc>().add(
      ProfileAvatarUploadRequested(avatar: avatar),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
