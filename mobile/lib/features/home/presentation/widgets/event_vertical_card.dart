import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';

class EventVerticalCard extends StatelessWidget {
  const EventVerticalCard({
    required this.event,
    required this.onTap,
    this.width = 150,
    super.key,
  });

  final MyEventItemModel event;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.coverImage ?? event.firstTrack;
    final isLive = event.status == 'LIVE';
    final isUpcoming = event.status == 'UPCOMING';
    final isEnded = event.status == 'ENDED';

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildGradientFallback(),
                )
              else
                _buildGradientFallback(),

              // Dark Gradient Overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Status Badge (Top Left)
              Positioned(
                top: 12,
                left: 12,
                child: _buildStatusBadge(isLive, isUpcoming, isEnded),
              ),

              // Bottom Row (Title, Host and Listeners)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            event.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'by ${event.hostName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, h:mm a').format(event.startDate),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isUpcoming)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            event.membersCount.toString(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isLive, bool isUpcoming, bool isEnded) {
    Color bgColor;
    String text;

    if (isLive) {
      bgColor = const Color(0xFFFF4B6E);
      text = 'LIVE';
    } else if (isUpcoming) {
      bgColor = const Color(0xFF007AFF);
      text = 'UPCOMING';
    } else if (isEnded) {
      bgColor = Colors.black.withValues(alpha: 0.6);
      text = 'ENDED';
    } else {
      bgColor = Colors.grey.withValues(alpha: 0.6);
      text = 'UNKNOWN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C3AED),
            Color(0xFF4F46E5),
          ],
        ),
      ),
    );
  }
}
