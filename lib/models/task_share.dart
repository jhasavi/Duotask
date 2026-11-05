import 'package:intl/intl.dart';

/// How the recipient of a share link has responded.
enum ShareResponse {
  pending,
  accepted,
  declined,
  done;

  static ShareResponse parse(Object? value) => ShareResponse.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ShareResponse.pending,
      );
}

/// A link that sends one task to someone who doesn't have DuoTask.
///
/// Rows live in `task_shares` (migration 20261016000001). The recipient
/// opens `<app>/t/<token>`, a lightweight page outside the Flutter app, and
/// can accept, decline or mark the task done without an account.
class TaskShare {
  final String id;
  final String token;
  final String taskId;
  final String createdById;
  final String? recipientName;
  final ShareResponse response;
  final DateTime? respondedAt;
  final DateTime? firstOpenedAt;
  final int openCount;
  final String? claimedById;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  const TaskShare({
    required this.id,
    required this.token,
    required this.taskId,
    required this.createdById,
    this.recipientName,
    this.response = ShareResponse.pending,
    this.respondedAt,
    this.firstOpenedAt,
    this.openCount = 0,
    this.claimedById,
    required this.expiresAt,
    this.revokedAt,
    required this.createdAt,
  });

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.parse(json[key] as String).toLocal();

    return TaskShare(
      id: json['id'] as String,
      token: json['token'] as String,
      taskId: json['task_id'] as String,
      createdById: json['created_by_id'] as String,
      recipientName: json['recipient_name'] as String?,
      response: ShareResponse.parse(json['response']),
      respondedAt: date('responded_at'),
      firstOpenedAt: date('first_opened_at'),
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      claimedById: json['claimed_by_id'] as String?,
      expiresAt: date('expires_at')!,
      revokedAt: date('revoked_at'),
      createdAt: date('created_at')!,
    );
  }

  bool get isRevoked => revokedAt != null;
  bool isExpired([DateTime? now]) => expiresAt.isBefore(now ?? DateTime.now());
  bool isLive([DateTime? now]) => !isRevoked && !isExpired(now);

  /// Whether the recipient has done anything with the link yet.
  bool get hasActivity =>
      firstOpenedAt != null ||
      response != ShareResponse.pending ||
      claimedById != null;

  /// One line for the sender: where the link stands.
  String statusLine([DateTime? now]) {
    final who = (recipientName?.trim().isNotEmpty ?? false)
        ? recipientName!
        : 'Your contact';
    if (isRevoked) return 'Link turned off';
    if (isExpired(now)) return 'Link expired';
    if (claimedById != null) return '$who joined DuoTask';
    switch (response) {
      case ShareResponse.done:
        return '$who marked it done';
      case ShareResponse.accepted:
        return "$who said they'll do it";
      case ShareResponse.declined:
        return "$who can't do it";
      case ShareResponse.pending:
        return firstOpenedAt != null
            ? '$who opened the link'
            : 'Link ready, not opened yet';
    }
  }

  /// Public URL of the recipient page.
  static Uri buildUrl(String appBaseUrl, String token) {
    final base = appBaseUrl.endsWith('/')
        ? appBaseUrl.substring(0, appBaseUrl.length - 1)
        : appBaseUrl;
    return Uri.parse('$base/t/$token');
  }

  /// The message the sender pastes into WhatsApp, a text or an email.
  static String buildMessage({
    required String taskTitle,
    required Uri url,
    String? recipientName,
    DateTime? dueDate,
  }) {
    final hi = (recipientName?.trim().isNotEmpty ?? false)
        ? 'Hi ${recipientName!.trim()}! '
        : '';
    final due = dueDate == null
        ? ''
        : ' (due ${DateFormat('EEE MMM d, h:mm a').format(dueDate.toLocal())})';
    return '$hi'
        'Could you take care of this? "$taskTitle"$due\n'
        "Tap to say you've got it or mark it done, no app needed: $url";
  }

  /// Tokens are URL-safe base64; anything else is not worth a request.
  static bool isValidToken(String? token) =>
      token != null && RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(token);
}

/// What `claim_task_share` reports after a recipient signs up from a link.
class ShareClaimResult {
  final bool paired;
  final String? senderName;
  final String taskId;

  const ShareClaimResult({
    required this.paired,
    required this.senderName,
    required this.taskId,
  });

  factory ShareClaimResult.fromJson(Map<String, dynamic> json) =>
      ShareClaimResult(
        paired: json['paired'] == true,
        senderName: json['sender_name'] as String?,
        taskId: json['task_id'] as String,
      );
}

/// What a link shows before sign-up, for the auth screen's invite banner.
class SharedTaskPreview {
  final String title;
  final String? senderName;

  const SharedTaskPreview({required this.title, this.senderName});

  factory SharedTaskPreview.fromJson(Map<String, dynamic> json) =>
      SharedTaskPreview(
        title: json['title'] as String,
        senderName: json['sender_name'] as String?,
      );
}
