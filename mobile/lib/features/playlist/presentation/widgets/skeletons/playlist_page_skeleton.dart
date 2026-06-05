import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/core/widgets/skeleton_box.dart';

class PlaylistPageSkeleton extends StatefulWidget {
  const PlaylistPageSkeleton({
    super.key,
    this.screenSize = ScreenSize.compact,
  });

  final ScreenSize screenSize;

  @override
  State<PlaylistPageSkeleton> createState() => _PlaylistPageSkeletonState();
}

class _PlaylistPageSkeletonState extends State<PlaylistPageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    unawaited(
      (_controller = AnimationController(
        vsync: this,
        duration: const Duration(
          milliseconds: 1200,
        ),
      )).repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.55 + (_controller.value * 0.35);

        if (widget.screenSize == ScreenSize.compact) {
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              120,
            ),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => _PlaylistTileSkeleton(
              opacity: opacity,
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            40,
            12,
            40,
            40,
          ),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.screenSize == ScreenSize.expanded ? 3 : 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemBuilder: (_, _) => _PlaylistGridSkeleton(
            opacity: opacity,
          ),
        );
      },
    );
  }
}

class _PlaylistTileSkeleton extends StatelessWidget {
  const _PlaylistTileSkeleton({
    required this.opacity,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            SkeletonBox(
              opacity: opacity,
              width: 64,
              height: 64,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SkeletonBox(
                          opacity: opacity,
                          height: 16,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SkeletonBox(
                        opacity: opacity,
                        width: 68,
                        height: 24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SkeletonBox(
                    opacity: opacity,
                    width: 180,
                    height: 14,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SkeletonBox(
                        opacity: opacity,
                        width: 54,
                        height: 22,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      SkeletonBox(
                        opacity: opacity,
                        width: 72,
                        height: 22,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistGridSkeleton extends StatelessWidget {
  const _PlaylistGridSkeleton({
    required this.opacity,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SkeletonBox(
                opacity: opacity,
                width: double.infinity,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    opacity: opacity,
                    height: 18,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(8),
                  ),

                  const SizedBox(height: 10),

                  SkeletonBox(
                    opacity: opacity,
                    height: 14,
                    width: 140,
                    borderRadius: BorderRadius.circular(8),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      SkeletonBox(
                        opacity: opacity,
                        width: 54,
                        height: 24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(width: 8),
                      SkeletonBox(
                        opacity: opacity,
                        width: 72,
                        height: 24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
