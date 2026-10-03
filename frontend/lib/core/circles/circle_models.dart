import '../widgets/ps_status_badge.dart';

// Mirrors the M1 API contract. Money is always integer minor units.

enum CircleInterval { weekly, fortnightly, monthly }

enum TurnRule { fixed, lottery, needBased }

enum CircleStatus { draft, active, completed }

enum CircleRole { organizer, member }

enum PaymentMethod { cash, bankTransfer, lankaqr, mobileWallet }

enum LedgerType {
  contributionRecorded,
  contributionVerified,
  correction,
  payout,
  memberAdded,
  memberRemoved,
  turnOrderSet,
  cycleClosed,
}

String _snake(String camel) => camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (_snake(v.name) == raw) return v;
  }
  return fallback;
}

String wireName(Enum e) => _snake(e.name);

ContributionStatus contributionStatusFrom(Object? raw) => switch (raw) {
      'verified' => ContributionStatus.verified,
      'recorded' => ContributionStatus.recorded,
      'overdue' => ContributionStatus.overdue,
      _ => ContributionStatus.due,
    };

DateTime? _ts(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
DateTime _date(Object? v) => DateTime.parse(v as String);
int _int(Object? v) => (v as num).toInt();

class Total {
  const Total({required this.count, required this.unitMinor, required this.totalMinor, required this.entryIds});

  final int count;
  final int unitMinor;
  final int totalMinor;
  final List<String> entryIds;

  factory Total.fromJson(Map<String, dynamic> j) => Total(
        count: _int(j['count']),
        unitMinor: _int(j['unitMinor']),
        totalMinor: _int(j['totalMinor']),
        entryIds: (j['entryIds'] as List? ?? const []).cast<String>(),
      );
}

class Recipient {
  const Recipient({required this.userId, required this.displayName, required this.isYou});

  final String userId;
  final String displayName;
  final bool isYou;

  factory Recipient.fromJson(Map<String, dynamic> j) => Recipient(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        isYou: j['isYou'] as bool? ?? false,
      );
}

class MyContribution {
  const MyContribution({
    required this.entryId,
    required this.reference,
    required this.method,
    required this.recordedAt,
    this.verifiedAt,
  });

  final String entryId;
  final String reference;
  final PaymentMethod? method;
  final DateTime recordedAt;
  final DateTime? verifiedAt;

  factory MyContribution.fromJson(Map<String, dynamic> j) => MyContribution(
        entryId: j['entryId'] as String,
        reference: j['reference'] as String,
        method: j['method'] == null ? null : _enum(PaymentMethod.values, j['method'], PaymentMethod.cash),
        recordedAt: _ts(j['recordedAt'])!,
        verifiedAt: _ts(j['verifiedAt']),
      );
}

class CurrentCycleSummary {
  const CurrentCycleSummary({
    required this.number,
    required this.dueDate,
    required this.myStatus,
    required this.recipient,
    this.myContribution,
  });

  final int number;
  final DateTime dueDate;
  final ContributionStatus myStatus;
  final Recipient? recipient;
  final MyContribution? myContribution;

  factory CurrentCycleSummary.fromJson(Map<String, dynamic> j) => CurrentCycleSummary(
        number: _int(j['number']),
        dueDate: _date(j['dueDate']),
        myStatus: contributionStatusFrom(j['myStatus']),
        recipient: j['recipient'] == null ? null : Recipient.fromJson(j['recipient'] as Map<String, dynamic>),
        myContribution: j['myContribution'] == null
            ? null
            : MyContribution.fromJson(j['myContribution'] as Map<String, dynamic>),
      );
}

class CircleSummary {
  const CircleSummary({
    required this.id,
    required this.name,
    required this.publicCode,
    required this.joinCode,
    required this.role,
    required this.status,
    required this.contributionMinor,
    required this.interval,
    required this.turnRule,
    required this.plannedCycles,
    required this.memberCount,
    required this.firstDueDate,
    this.myTurn,
    this.currentCycle,
  });

  final String id;
  final String name;
  final String publicCode;
  final String? joinCode;
  final CircleRole role;
  final CircleStatus status;
  final int contributionMinor;
  final CircleInterval interval;
  final TurnRule turnRule;
  final int plannedCycles;
  final int memberCount;
  final DateTime? firstDueDate;
  final int? myTurn;
  final CurrentCycleSummary? currentCycle;

  bool get isOrganizer => role == CircleRole.organizer;

  factory CircleSummary.fromJson(Map<String, dynamic> j) => CircleSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        publicCode: j['publicCode'] as String? ?? '',
        joinCode: j['joinCode'] as String?,
        role: _enum(CircleRole.values, j['role'], CircleRole.member),
        status: _enum(CircleStatus.values, j['status'], CircleStatus.draft),
        contributionMinor: _int(j['contributionMinor']),
        interval: _enum(CircleInterval.values, j['interval'], CircleInterval.monthly),
        turnRule: _enum(TurnRule.values, j['turnRule'], TurnRule.fixed),
        plannedCycles: _int(j['plannedCycles']),
        memberCount: _int(j['memberCount'] ?? 0),
        firstDueDate: j['firstDueDate'] == null ? null : _date(j['firstDueDate']),
        myTurn: j['myTurn'] == null ? null : _int(j['myTurn']),
        currentCycle: j['currentCycle'] == null
            ? null
            : CurrentCycleSummary.fromJson(j['currentCycle'] as Map<String, dynamic>),
      );
}

class CircleMember {
  const CircleMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.isYou,
    this.payoutPosition,
  });

  final String userId;
  final String displayName;
  final CircleRole role;
  final bool isYou;
  final int? payoutPosition;

  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        role: _enum(CircleRole.values, j['role'], CircleRole.member),
        isYou: j['isYou'] as bool? ?? false,
        payoutPosition: j['payoutPosition'] == null ? null : _int(j['payoutPosition']),
      );
}

class CycleInfo {
  const CycleInfo({required this.number, required this.dueDate, required this.closed, this.recipientUserId});

  final int number;
  final DateTime dueDate;
  final bool closed;
  final String? recipientUserId;

  factory CycleInfo.fromJson(Map<String, dynamic> j) => CycleInfo(
        number: _int(j['number']),
        dueDate: _date(j['dueDate']),
        closed: j['status'] == 'closed',
        recipientUserId: j['recipientUserId'] as String?,
      );
}

class CycleMemberStatus {
  const CycleMemberStatus({
    required this.userId,
    required this.displayName,
    required this.status,
    this.contributionEntryId,
    this.reference,
    this.method,
    this.recordedAt,
    this.verifiedAt,
  });

  final String userId;
  final String displayName;
  final ContributionStatus status;
  final String? contributionEntryId;
  final String? reference;
  final PaymentMethod? method;
  final DateTime? recordedAt;
  final DateTime? verifiedAt;

  factory CycleMemberStatus.fromJson(Map<String, dynamic> j) => CycleMemberStatus(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        status: contributionStatusFrom(j['status']),
        contributionEntryId: j['contributionEntryId'] as String?,
        reference: j['reference'] as String?,
        method: j['method'] == null ? null : _enum(PaymentMethod.values, j['method'], PaymentMethod.cash),
        recordedAt: _ts(j['recordedAt']),
        verifiedAt: _ts(j['verifiedAt']),
      );
}

class CycleTotals {
  const CycleTotals({
    required this.verified,
    required this.awaiting,
    required this.unpaidCount,
    required this.unpaidUserIds,
    required this.membersDue,
    required this.expectedMinor,
  });

  final Total verified;
  final Total awaiting;
  final int unpaidCount;
  final List<String> unpaidUserIds;
  final int membersDue;
  final int expectedMinor;

  factory CycleTotals.fromJson(Map<String, dynamic> j) {
    final unpaid = j['unpaid'] as Map<String, dynamic>? ?? const {};
    return CycleTotals(
      verified: Total.fromJson(j['verified'] as Map<String, dynamic>),
      awaiting: Total.fromJson(j['awaiting'] as Map<String, dynamic>),
      unpaidCount: _int(unpaid['count'] ?? 0),
      unpaidUserIds: (unpaid['userIds'] as List? ?? const []).cast<String>(),
      membersDue: _int(j['membersDue']),
      expectedMinor: _int(j['expectedMinor']),
    );
  }
}

class CurrentCycleDetail {
  const CurrentCycleDetail({required this.number, required this.dueDate, required this.members, required this.totals});

  final int number;
  final DateTime dueDate;
  final List<CycleMemberStatus> members;
  final CycleTotals totals;

  factory CurrentCycleDetail.fromJson(Map<String, dynamic> j) => CurrentCycleDetail(
        number: _int(j['number']),
        dueDate: _date(j['dueDate']),
        members: (j['members'] as List).map((m) => CycleMemberStatus.fromJson(m as Map<String, dynamic>)).toList(),
        totals: CycleTotals.fromJson(j['totals'] as Map<String, dynamic>),
      );
}

class LotteryState {
  const LotteryState({this.commitment, this.seed});

  final String? commitment;
  final String? seed;

  factory LotteryState.fromJson(Map<String, dynamic>? j) =>
      LotteryState(commitment: j?['commitment'] as String?, seed: j?['seed'] as String?);
}

class CircleDetail {
  const CircleDetail({
    required this.summary,
    required this.members,
    required this.cycles,
    required this.lottery,
    this.current,
  });

  final CircleSummary summary;
  final List<CircleMember> members;
  final List<CycleInfo> cycles;
  final LotteryState lottery;
  final CurrentCycleDetail? current;

  String get id => summary.id;
  CircleMember? get me => members.where((m) => m.isYou).firstOrNull;

  CircleMember? memberById(String id) => members.where((m) => m.userId == id).firstOrNull;

  factory CircleDetail.fromJson(Map<String, dynamic> j) => CircleDetail(
        summary: CircleSummary.fromJson(j),
        members: (j['members'] as List? ?? const [])
            .map((m) => CircleMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        cycles: (j['cycles'] as List? ?? const []).map((c) => CycleInfo.fromJson(c as Map<String, dynamic>)).toList(),
        lottery: LotteryState.fromJson(j['lottery'] as Map<String, dynamic>?),
        current: j['current'] == null ? null : CurrentCycleDetail.fromJson(j['current'] as Map<String, dynamic>),
      );
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.seq,
    required this.type,
    required this.reference,
    required this.actorName,
    required this.createdAt,
    required this.hash,
    this.cycleNumber,
    this.subjectUserId,
    this.subjectName,
    this.amountMinor,
    this.method,
    this.provider,
    this.receiptReference,
    this.targetEntryId,
    this.note,
    this.status,
  });

  final String id;
  final int seq;
  final LedgerType type;
  final String reference;
  final String actorName;
  final DateTime createdAt;
  final String hash;
  final int? cycleNumber;
  final String? subjectUserId;
  final String? subjectName;
  final int? amountMinor;
  final PaymentMethod? method;
  final String? provider;
  final String? receiptReference;
  final String? targetEntryId;
  final String? note;

  /// Only for contribution_recorded: 'recorded' | 'verified' | 'corrected'.
  final String? status;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as String,
        seq: _int(j['seq']),
        type: _enum(LedgerType.values, j['type'], LedgerType.contributionRecorded),
        reference: j['reference'] as String,
        actorName: j['actorName'] as String? ?? '',
        createdAt: _ts(j['createdAt'])!,
        hash: j['hash'] as String? ?? '',
        cycleNumber: j['cycleNumber'] == null ? null : _int(j['cycleNumber']),
        subjectUserId: j['subjectUserId'] as String?,
        subjectName: j['subjectName'] as String?,
        amountMinor: j['amountMinor'] == null ? null : _int(j['amountMinor']),
        method: j['method'] == null ? null : _enum(PaymentMethod.values, j['method'], PaymentMethod.cash),
        provider: j['provider'] as String?,
        receiptReference: j['receiptReference'] as String?,
        targetEntryId: j['targetEntryId'] as String?,
        note: j['note'] as String?,
        status: j['status'] as String?,
      );
}

class VerifyItem {
  const VerifyItem({
    required this.entryId,
    required this.reference,
    required this.cycleNumber,
    required this.subjectUserId,
    required this.subjectName,
    required this.amountMinor,
    required this.recordedAt,
    required this.actorName,
    this.method,
    this.provider,
    this.receiptReference,
  });

  final String entryId;
  final String reference;
  final int cycleNumber;
  final String subjectUserId;
  final String subjectName;
  final int amountMinor;
  final DateTime recordedAt;
  final String actorName;
  final PaymentMethod? method;
  final String? provider;
  final String? receiptReference;

  factory VerifyItem.fromJson(Map<String, dynamic> j) => VerifyItem(
        entryId: j['entryId'] as String,
        reference: j['reference'] as String,
        cycleNumber: _int(j['cycleNumber']),
        subjectUserId: j['subjectUserId'] as String,
        subjectName: j['subjectName'] as String,
        amountMinor: _int(j['amountMinor']),
        recordedAt: _ts(j['recordedAt'])!,
        actorName: j['actorName'] as String? ?? '',
        method: j['method'] == null ? null : _enum(PaymentMethod.values, j['method'], PaymentMethod.cash),
        provider: j['provider'] as String?,
        receiptReference: j['receiptReference'] as String?,
      );
}
