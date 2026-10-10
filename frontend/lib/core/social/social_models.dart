/// Another member as the app may show them. The server never sends phone,
/// email, NIC or age for anyone but the signed-in user.
class Person {
  const Person({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.verified = false,
    this.isFollowing = false,
    this.followsYou = false,
    this.palStatus = PalStatus.none,
  });

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final bool verified;
  final bool isFollowing;
  final bool followsYou;
  final PalStatus palStatus;

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    id: j['id'] as String,
    fullName: j['fullName'] as String,
    username: j['username'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    verified: j['verified'] as bool? ?? false,
    isFollowing: j['isFollowing'] as bool? ?? false,
    followsYou: j['followsYou'] as bool? ?? false,
    palStatus: PalStatus.parse(j['palStatus']),
  );
}

/// My pal relation to someone. [outgoing] = I asked them, [incoming] = they asked me.
enum PalStatus {
  none,
  pals,
  outgoing,
  incoming;

  static PalStatus parse(Object? v) => switch (v) {
    'pals' => pals,
    'outgoing' => outgoing,
    'incoming' => incoming,
    _ => none,
  };
}

enum SuggestionReason { sharedCircle, mutualPals, followsYou, newMember }

class Suggestion {
  const Suggestion({required this.person, required this.reason, this.sharedCircles = 0, this.mutualCount = 0});

  final Person person;
  final SuggestionReason reason;
  final int sharedCircles;
  final int mutualCount;

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
    person: Person.fromJson(j),
    reason: switch (j['reason']) {
      'shared_circle' => SuggestionReason.sharedCircle,
      'mutual_pals' => SuggestionReason.mutualPals,
      'follows_you' => SuggestionReason.followsYou,
      _ => SuggestionReason.newMember,
    },
    sharedCircles: (j['sharedCircles'] as num?)?.toInt() ?? 0,
    mutualCount: (j['mutualCount'] as num?)?.toInt() ?? 0,
  );
}

class PublicProfile {
  const PublicProfile({
    required this.person,
    required this.memberSince,
    this.bio,
    this.city,
    this.followersCount = 0,
    this.followingCount = 0,
    this.palsCount = 0,
    this.sharedCircles = 0,
    this.isMe = false,
    this.blockedByMe = false,
  });

  final Person person;
  final String? bio;
  final String? city;
  final DateTime memberSince;
  final int followersCount;
  final int followingCount;
  final int palsCount;
  final int sharedCircles;
  final bool isMe;
  final bool blockedByMe;

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    person: Person.fromJson(j),
    bio: j['bio'] as String?,
    city: j['city'] as String?,
    memberSince: DateTime.parse(j['memberSince'] as String),
    followersCount: (j['followersCount'] as num?)?.toInt() ?? 0,
    followingCount: (j['followingCount'] as num?)?.toInt() ?? 0,
    palsCount: (j['palsCount'] as num?)?.toInt() ?? 0,
    sharedCircles: (j['sharedCircles'] as num?)?.toInt() ?? 0,
    isMe: j['isMe'] as bool? ?? false,
    blockedByMe: j['blockedByMe'] as bool? ?? false,
  );
}

enum MessageKind { text, image, video }

class MessageReaction {
  const MessageReaction({required this.emoji, required this.count, required this.mine});

  final String emoji;
  final int count;
  final bool mine;
}

class ChatMessage {
  const ChatMessage({
    required this.seq,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    required this.createdAt,
    this.id = '',
    this.kind = MessageKind.text,
    this.deleted = false,
    this.mediaUrl,
    this.mediaType,
    this.mediaSize = 0,
    this.starred = false,
    this.reactions = const [],
  });

  final String id;
  final int seq;
  final String senderId;
  final String clientMessageId;

  /// The text, or the caption of a photo or video.
  final String body;
  final DateTime createdAt;
  final MessageKind kind;

  /// Taken back by its sender; nothing of it is left.
  final bool deleted;

  /// Server-relative; fetched with the signed-in user's token.
  final String? mediaUrl;
  final String? mediaType;
  final int mediaSize;

  /// Starred by me (private to me).
  final bool starred;
  final List<MessageReaction> reactions;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final media = j['media'] as Map<String, dynamic>?;
    return ChatMessage(
      id: j['id'] as String? ?? '',
      seq: (j['seq'] as num).toInt(),
      senderId: j['senderId'] as String,
      clientMessageId: j['clientMessageId'] as String? ?? '',
      body: j['body'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      kind: switch (j['kind']) {
        'image' => MessageKind.image,
        'video' => MessageKind.video,
        _ => MessageKind.text,
      },
      deleted: j['deleted'] as bool? ?? false,
      mediaUrl: media?['url'] as String?,
      mediaType: media?['contentType'] as String?,
      mediaSize: (media?['size'] as num?)?.toInt() ?? 0,
      starred: j['starred'] as bool? ?? false,
      reactions: [
        for (final r in j['reactions'] as List? ?? const [])
          MessageReaction(
            emoji: (r as Map)['emoji'] as String,
            count: (r['count'] as num).toInt(),
            mine: r['mine'] as bool? ?? false,
          ),
      ],
    );
  }
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.unread,
    this.pinned = false,
    this.favourite = false,
  });

  final String id;
  final Person peer;
  final ChatMessage lastMessage;
  final int unread;

  /// Both are mine alone; the other person never sees them.
  final bool pinned;
  final bool favourite;

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
    id: j['id'] as String,
    peer: Person.fromJson(j['peer'] as Map<String, dynamic>),
    lastMessage: ChatMessage.fromJson(j['lastMessage'] as Map<String, dynamic>),
    unread: (j['unread'] as num?)?.toInt() ?? 0,
    pinned: j['pinned'] as bool? ?? false,
    favourite: j['favourite'] as bool? ?? false,
  );
}

class ChatThread {
  const ChatThread({required this.id, required this.peer, this.blocked = false});

  final String id;
  final Person peer;
  final bool blocked;

  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
    id: j['id'] as String,
    peer: Person.fromJson(j['peer'] as Map<String, dynamic>),
    blocked: j['blocked'] as bool? ?? false,
  );
}

class MessagePage {
  const MessagePage({required this.messages, required this.peerLastReadSeq});

  final List<ChatMessage> messages;
  final int peerLastReadSeq;

  factory MessagePage.fromJson(Map<String, dynamic> j) => MessagePage(
    messages: [for (final m in j['messages'] as List<dynamic>) ChatMessage.fromJson(m as Map<String, dynamic>)],
    peerLastReadSeq: (j['peerLastReadSeq'] as num?)?.toInt() ?? 0,
  );
}

class PalRequest {
  const PalRequest({required this.person, required this.requestedAt, this.mutualPals = 0});

  final Person person;
  final DateTime requestedAt;
  final int mutualPals;

  factory PalRequest.fromJson(Map<String, dynamic> j) => PalRequest(
    person: Person.fromJson(j),
    requestedAt: DateTime.parse(j['requestedAt'] as String).toLocal(),
    mutualPals: (j['mutualPals'] as num?)?.toInt() ?? 0,
  );
}

class PalRequests {
  const PalRequests({this.received = const [], this.sent = const []});

  final List<PalRequest> received;
  final List<PalRequest> sent;

  factory PalRequests.fromJson(Map<String, dynamic> j) => PalRequests(
    received: [for (final r in j['received'] as List<dynamic>) PalRequest.fromJson(r as Map<String, dynamic>)],
    sent: [for (final r in j['sent'] as List<dynamic>) PalRequest.fromJson(r as Map<String, dynamic>)],
  );
}
