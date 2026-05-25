import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_details_page.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/pages/settings_page.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_view.dart';
import 'package:music_room/routes/route_names.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.userId});

  final String? userId;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late final ProfileBloc _profileBloc;

  void refreshProfile() {
    _profileBloc.add(ProfileRefreshRequested(userId: widget.userId));
  }

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
          current is ProfileMutationFailure ||
          current is ProfilePasswordChangeSuccess ||
          current is ProfilePasswordChangeFailure ||
          current is ProfileGoogleLinkSuccess ||
          current is ProfileGoogleLinkFailure ||
          current is ProfileGoogleUnlinkSuccess ||
          current is ProfileGoogleUnlinkFailure,
      listener: (context, state) {
        if (state is ProfileMutationSuccess) {
          AppSnackbar.showSuccess(context, state.message);
        }
        if (state is ProfileMutationFailure) {
          AppSnackbar.showError(context, state.message);
        }
        if (state is ProfilePasswordChangeSuccess) {
          AppSnackbar.showSuccess(context, state.message);
        }
        if (state is ProfilePasswordChangeFailure) {
          AppSnackbar.showError(context, state.message);
        }
        if (state is ProfileGoogleLinkSuccess) {
          AppSnackbar.showSuccess(context, state.message);
        }
        if (state is ProfileGoogleLinkFailure) {
          AppSnackbar.showError(context, state.message);
        }
        if (state is ProfileGoogleUnlinkSuccess) {
          AppSnackbar.showSuccess(context, state.message);
        }
        if (state is ProfileGoogleUnlinkFailure) {
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

    final profileData = state.dataOrNull;
    if (profileData == null) {
      return const SizedBox.shrink();
    }

    final isBusy =
        state is ProfileMutationInProgress ||
        state is ProfilePasswordChangeInProgress ||
        state is ProfileGoogleLinkInProgress ||
        state is ProfileGoogleUnlinkInProgress;
    final googleAccountMessage = switch (state) {
      ProfileGoogleLinkFailure(:final message) => message,
      ProfileGoogleUnlinkFailure(:final message) => message,
      _ => null,
    };

    return ProfileView(
      data: profileData,
      isBusy: isBusy,
      busyLabel: state is ProfileMutationInProgress ? state.message : null,
      onFollowProfile: profileData.profile.isSelf
          ? null
          : () => _handleFollowAction(context, profileData.profile),
      onEditProfile: profileData.profile.isSelf
          ? () => _openSettingsPage(context)
          : null,
      onChangeAvatar: profileData.profile.isSelf
          ? () => _pickAndUploadAvatar(context)
          : null,
      onGoogleAccountAction: profileData.profile.isSelf
          ? () => _handleGoogleAccountAction(context, profileData.profile)
          : null,
      googleAccountMessage: googleAccountMessage,
      onLogout: profileData.profile.isSelf
          ? () => _confirmLogout(context)
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

  Future<void> _openSettingsPage(BuildContext context) async {
    try {
      final saved = await Navigator.of(context).pushNamed(RouteNames.settings);
      if (saved == true && context.mounted) {
        context.read<ProfileBloc>().add(
          ProfileRefreshRequested(userId: userId),
        );
      }
    } on Exception {
      if (!context.mounted) {
        return;
      }
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => SettingsPage(userId: userId),
        ),
      );

      if (saved == true && context.mounted) {
        context.read<ProfileBloc>().add(
          ProfileRefreshRequested(userId: userId),
        );
      }
    }
  }

  void _handleFollowAction(
    BuildContext context,
    UserProfileEntity profile,
  ) {
    final bloc = context.read<ProfileBloc>();
    final isFollowing = profile.isFriend || profile.isFollowing;

    if (isFollowing) {
      bloc.add(ProfileUnfollowRequested(userId: profile.id));
      return;
    }

    bloc.add(ProfileFollowRequested(userId: profile.id));
  }

  Future<void> _handleGoogleAccountAction(
    BuildContext context,
    UserProfileEntity profile,
  ) async {
    final bloc = context.read<ProfileBloc>();

    if (profile.googleLinkStatus == GoogleLinkStatus.linked) {
      final confirmed = await showAppConfirmationDialog(
        context: context,
        title: 'Unlink Google Account?',
        message:
            'This will remove the Google connection from your account.\n\n'
            'You can link it again later from this screen.',
        confirmLabel: 'Remove Link',
        cancelLabel: 'Keep Linked',
        icon: Icons.link_off_rounded,
        variant: ConfirmationDialogVariant.destructive,
      );

      if (confirmed == true && context.mounted) {
        bloc.add(const ProfileGoogleUnlinkRequested());
      }

      return;
    }

    bloc.add(const ProfileGoogleLinkRequested());
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Log Out?',
      message: 'Are you sure you want to log out of your account?',
      confirmLabel: 'Log Out',
      cancelLabel: 'Stay signed in',
      icon: Icons.logout_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final avatar = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );

    if (avatar == null) {
      return;
    }

    final bytes = await avatar.readAsBytes();

    if (!context.mounted) {
      return;
    }

    context.read<ProfileBloc>().add(
      ProfileAvatarUploadRequested(
        bytes: bytes,
        fileName: avatar.name,
      ),
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
