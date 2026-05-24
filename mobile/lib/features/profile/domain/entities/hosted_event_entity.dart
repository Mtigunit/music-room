import 'package:equatable/equatable.dart';

class HostedEventEntity extends Equatable {
  const HostedEventEntity({
    required this.id,
    required this.name,
    required this.hostName,
    required this.hostId,
    required this.dateTime,
    required this.status,
    this.coverImageAsset,
    this.coverColorHex = 0xFF7C3AED,
    this.listenerCount = 0,
    this.genre = '',
  });

  final String id;
  final String name;
  final String hostName;
  final String hostId;
  final DateTime dateTime;
  final String status;
  final String? coverImageAsset;
  final int coverColorHex;
  final int listenerCount;
  final String genre;

  bool get isLive => status == 'LIVE';

  bool get isUpcoming => status == 'UPCOMING';

  bool get isEnded => status == 'ENDED';

  @override
  List<Object?> get props => [
    id,
    name,
    hostName,
    hostId,
    dateTime,
    status,
    coverImageAsset,
    coverColorHex,
    listenerCount,
    genre,
  ];
}
