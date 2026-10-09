import '../payouts/payout_models.dart';
import '../widgets/ps_status_badge.dart';

// Mirrors the M1 API contract. Money is always integer minor units.

enum CircleInterval { weekly, fortnightly, monthly }

enum TurnRule { fixed, lottery, needBased }

enum CircleStatus { draft, active, completed }

enum CircleRole { organizer, member }

enum PaymentMethod { cash, bankTransfer, lankaqr, mobileWallet }

/// Who members pay each cycle.
enum CollectionMode {
  /// Every member pays this cycle's turn recipient.
  directToRecipient,

  /// Members pay the organizer, who hands the pot to the recipient.
  viaOrganizer,
}

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
    this.collectionMode = CollectionMode.directToRecipient,
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
  final CollectionMode collectionMode;

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
        collectionMode: _enum(CollectionMode.values, j['collectionMode'], CollectionMode.directToRecipient),
      );
}

class CircleMember {
  const CircleMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.isYou,
    this.payoutPosition,
    this.avatarUrl,
    this.payoutReady = false,
    this.payoutKinds = const [],
  });

  final String userId;
  final String displayName;
  final CircleRole role;
  final bool isYou;
  final int? payoutPosition;
  final String? avatarUrl;

  /// Has shared at least one way to be paid (kinds only, never details).
  final bool payoutReady;
  final List<PayoutKind> payoutKinds;

  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        role: _enum(CircleRole.values, j['role'], CircleRole.member),
        isYou: j['isYou'] as bool? ?? false,
        payoutPosition: j['payoutPosition'] == null ? null : _int(j['payoutPosition']),
        avatarUrl: j['avatarUrl'] as String?,
        payoutReady: (j['payout'] as Map?)?['ready'] as bool? ?? false,
        payoutKinds: [for (final k in (j['payout'] as Map?)?['kinds'] as List? ?? const []) PayoutKind.parse(k)],
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
    this.myPayout = const [],
    this.setup = const CircleSetup(),
    this.invitations = const [],
  });

  final CircleSummary summary;
  final List<CircleMember> members;
  final List<CycleInfo> cycles;
  final LotteryState lottery;
  final CurrentCycleDetail? current;

  /// My methods shared with this circle.
  final List<PayoutSummary> myPayout;
  final CircleSetup setup;

  /// Pending invitations (organizer only).
  final List<CircleInvite> invitations;

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
        myPayout: [for (final m in j['myPayout'] as List? ?? const []) PayoutSummary.fromJson(m as Map<String, dynamic>)],
        setup: j['setup'] == null ? const CircleSetup() : CircleSetup.fromJson(j['setup'] as Map<String, dynamic>),
        invitations: [for (final i in j['invitations'] as List? ?? const []) CircleInvite.fromJson(i as Map<String, dynamic>)],
      );
}

/// What still stands between a draft circle and its start.
class CircleSetup {
  const CircleSetup({
    this.seatsTotal = 0,
    this.seatsTaken = 0,
    this.pendingInvitations = 0,
    this.membersMissingPayout = const [],
    this.canStart = false,
  });

  final int seatsTotal;
  final int seatsTaken;
  final int pendingInvitations;
  final List<String> membersMissingPayout;
  final bool canStart;

  int get seatsOpen => (seatsTotal - seatsTaken - pendingInvitations).clamp(0, seatsTotal);

  factory CircleSetup.fromJson(Map<String, dynamic> j) => CircleSetup(
        seatsTotal: _int(j['seatsTotal'] ?? 0),
        seatsTaken: _int(j['seatsTaken'] ?? 0),
        pendingInvitations: _int(j['pendingInvitations'] ?? 0),
        membersMissingPayout: [for (final id in j['membersMissingPayout'] as List? ?? const []) id as String],
        canStart: j['canStart'] as bool? ?? false,
      );
}

/// Someone shown in invitation lists (public fields only).
class InvitePerson {
  const InvitePerson({required this.id, required this.fullName, this.username, this.avatarUrl});

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;

  factory InvitePerson.fromJson(Map<String, dynamic> j) => InvitePerson(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        username: j['username'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class CircleInvite {
  const CircleInvite({required this.id, required this.person, required this.invitedAt});

  final String id;
  final InvitePerson person;
  final DateTime invitedAt;

  factory CircleInvite.fromJson(Map<String, dynamic> j) => CircleInvite(
        id: j['id'] as String,
        person: InvitePerson.fromJson(j['person'] as Map<String, dynamic>),
        invitedAt: _ts(j['invitedAt'])!,
      );
}

enum InvitableState { available, invited, member }

class InvitablePal {
  const InvitablePal({required this.person, required this.state});

  final InvitePerson person;
  final InvitableState state;

  factory InvitablePal.fromJson(Map<String, dynamic> j) => InvitablePal(
        person: InvitePerson.fromJson(j),
        state: _enum(InvitableState.values, j['state'], InvitableState.available),
      );
}

/// An invitation to me, with everything needed to decide.
class MyInvitation {
  const MyInvitation({
    required this.id,
    required this.organizer,
    required this.invitedAt,
    required this.circleId,
    required this.name,
    required this.contributionMinor,
    required this.interval,
    required this.turnRule,
    required this.plannedCycles,
    required this.collectionMode,
    required this.memberCount,
    required this.seatsLeft,
    required this.payout,
    this.firstDueDate,
    this.message,
    this.palsInside = const [],
  });

  final String id;
  final InvitePerson organizer;
  final DateTime invitedAt;
  final String? message;
  final String circleId;
  final String name;
  final int contributionMinor;
  final CircleInterval interval;
  final TurnRule turnRule;
  final int plannedCycles;
  final CollectionMode collectionMode;
  final DateTime? firstDueDate;
  final int memberCount;
  final int seatsLeft;

  /// The pot each member receives on their turn, with its parts.
  final Total payout;
  final List<String> palsInside;

  factory MyInvitation.fromJson(Map<String, dynamic> j) {
    final c = j['circle'] as Map<String, dynamic>;
    return MyInvitation(
      id: j['id'] as String,
      organizer: InvitePerson.fromJson(j['organizer'] as Map<String, dynamic>),
      invitedAt: _ts(j['invitedAt'])!,
      message: j['message'] as String?,
      circleId: c['id'] as String,
      name: c['name'] as String,
      contributionMinor: _int(c['contributionMinor']),
      interval: _enum(CircleInterval.values, c['interval'], CircleInterval.monthly),
      turnRule: _enum(TurnRule.values, c['turnRule'], TurnRule.fixed),
      plannedCycles: _int(c['plannedCycles']),
      collectionMode: _enum(CollectionMode.values, c['collectionMode'], CollectionMode.directToRecipient),
      firstDueDate: c['firstDueDate'] == null ? null : _date(c['firstDueDate']),
      memberCount: _int(c['memberCount']),
      seatsLeft: _int(c['seatsLeft']),
      payout: Total.fromJson(c['payout'] as Map<String, dynamic>),
      palsInside: [for (final n in c['palsInside'] as List? ?? const []) n as String],
    );
  }
}

/// Who I pay this cycle and how.
class PayTo {
  const PayTo({
    required this.cycleNumber,
    required this.dueDate,
    required this.collectionMode,
    required this.youReceive,
    required this.payee,
    required this.amount,
    required this.reference,
    this.methods = const [],
  });

  final int cycleNumber;
  final DateTime dueDate;
  final CollectionMode collectionMode;
  final bool youReceive;
  final InvitePerson payee;
  final Total amount;

  /// Suggested note for the transfer so the payee can match it.
  final String reference;
  final List<PayoutMethod> methods;

  factory PayTo.fromJson(Map<String, dynamic> j) => PayTo(
        cycleNumber: _int(j['cycleNumber']),
        dueDate: _date(j['dueDate']),
        collectionMode: _enum(CollectionMode.values, j['collectionMode'], CollectionMode.directToRecipient),
        youReceive: j['youReceive'] as bool? ?? false,
        payee: InvitePerson.fromJson(j['payee'] as Map<String, dynamic>),
        amount: Total.fromJson(j['amount'] as Map<String, dynamic>),
        reference: j['reference'] as String? ?? '',
        methods: [for (final m in j['methods'] as List? ?? const []) PayoutMethod.fromJson(m as Map<String, dynamic>)],
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
