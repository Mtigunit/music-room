class NotificationModel {
  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.payload,
    required this.isRead,
    required this.createdAt,
    this.message,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String?,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
    );
  }

  NotificationModel copyWithRead({required bool isRead}) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      message: message,
      payload: payload,
      isRead: isRead,
      createdAt: createdAt,
      readAt: readAt ?? DateTime.now(),
    );
  }

  final String id;
  final String type;
  final String title;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;
  final String? message;
  final DateTime? readAt;
}
