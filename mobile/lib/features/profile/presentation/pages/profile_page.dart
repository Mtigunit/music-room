import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.userId,
    this.showBackButton = false,
  });

  final String? userId;
  final bool showBackButton;

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
      child: _ProfilePageBody(
        userId: widget.userId,
        showBackButton: widget.showBackButton,
      ),
    );
  }
}

class _ProfilePageBody extends StatelessWidget {
  const _ProfilePageBody({required this.showBackButton, this.userId});

  final String? userId;
  final bool showBackButton;

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

    final profileData = state.dataOrNull;
    if (profileData == null) {
      return const SizedBox.shrink();
    }

    final isBusy = state is ProfileMutationInProgress;

    return ProfileView(
      data: profileData,
      isBusy: isBusy,
      showBackButton: showBackButton,
      busyLabel: state is ProfileMutationInProgress ? state.message : null,
      onFollowProfile: profileData.profile.isSelf
          ? null
          : () => _handleFollowAction(context, profileData.profile),
      onOpenRoom: (room) {
        context.go('/events/${room.id}');
      },
      onOpenPlaylist: (playlist) {
        context.go('/playlists/${playlist.id}');
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
