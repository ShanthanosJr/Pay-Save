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
  });

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final bool verified;
  final bool isFollowing;
  final bool followsYou;

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    id: j['id'] as String,
    fullName: j['fullName'] as String,
    username: j['username'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    verified: j['verified'] as bool? ?? false,
    isFollowing: j['isFollowing'] as bool? ?? false,
    followsYou: j['followsYou'] as bool? ?? false,
  );
}

enum SuggestionReason { sharedCircle, mutual, followsYou, newMember }

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
      'mutual' => SuggestionReason.mutual,
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
    sharedCircles: (j['sharedCircles'] as num?)?.toInt() ?? 0,
    isMe: j['isMe'] as bool? ?? false,
    blockedByMe: j['blockedByMe'] as bool? ?? false,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.seq,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    required this.createdAt,
  });

  final int seq;
  final String senderId;
  final String clientMessageId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    seq: (j['seq'] as num).toInt(),
    senderId: j['senderId'] as String,
    clientMessageId: j['clientMessageId'] as String? ?? '',
    body: j['body'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
  );
}

class ChatSummary {
  const ChatSummary({required this.id, required this.peer, required this.lastMessage, required this.unread});

  final String id;
  final Person peer;
  final ChatMessage lastMessage;
  final int unread;

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
    id: j['id'] as String,
    peer: Person.fromJson(j['peer'] as Map<String, dynamic>),
    lastMessage: ChatMessage.fromJson(j['lastMessage'] as Map<String, dynamic>),
    unread: (j['unread'] as num?)?.toInt() ?? 0,
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
