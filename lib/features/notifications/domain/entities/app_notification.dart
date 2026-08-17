import '../../../../core/utils/db_parsing.dart';

/// An in-app notification (`public.notifications`). Named `AppNotification` to
/// avoid clashing with Flutter's `Notification`. The [title]/[body] are
/// denormalized copies (rendered server-side from a template), so the client
/// never needs template access.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String profileId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  /// Optional in-app deep-link target carried in [data] (e.g. an order route).
  String? get route {
    final v = data['route'];
    return v is String && v.isNotEmpty ? v : null;
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    return AppNotification(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : const {},
      readAt: parseTimestamp(map['read_at']),
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}
