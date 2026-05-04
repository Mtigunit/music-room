import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/skeleton_box.dart';

class PlaylistPageSkeleton extends StatefulWidget {
  const PlaylistPageSkeleton({super.key});

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
        duration: const Duration(milliseconds: 1200),
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
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _PlaylistTileSkeleton(opacity: opacity);
          },
        );
      },
    );
  }
}

class _PlaylistTileSkeleton extends StatelessWidget {
  const _PlaylistTileSkeleton({required this.opacity});

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
