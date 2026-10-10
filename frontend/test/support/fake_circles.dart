import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pay_and_save/core/api/api_exception.dart';
import 'package:pay_and_save/core/circles/circle_models.dart';
import 'package:pay_and_save/core/circles/circles_api.dart';

/// In-memory stand-in for the circles API. It produces contract-shaped JSON
/// and goes through the real fromJson parsers, so tests also pin the contract.
class FakeCirclesApi extends CirclesApi {
  FakeCirclesApi({this.seed = FakeSeed.none}) : super(Dio()) {
    switch (seed) {
      case FakeSeed.none:
        break;
      case FakeSeed.activeMember:
        _seedActive(meOrganizer: false);
      case FakeSeed.activeOrganizer:
        _seedActive(meOrganizer: true);
      case FakeSeed.draftFixedOrganizer:
        _seedDraft(rule: 'fixed');
      case FakeSeed.draftLotteryOrganizer:
        _seedDraft(rule: 'lottery');
    }
  }

  final FakeSeed seed;
  final calls = <String>[];

  /// No signal: writes fail the way a dropped connection does.
  bool offline = false;

  /// clientEntryId of every record attempt, including the ones that failed.
  final attempts = <String>[];

  /// Invitations addressed to me (raw API JSON).
  final invitations = <Map<String, dynamic>>[];

  /// What GET /pay-to returns; null = no open cycle.
  Map<String, dynamic>? payToJson;
  final invitable = <Map<String, dynamic>>[];
  int seatsLeft = 2;
  final _circles = <String, _C>{};
  int _ref = 1001;

  static const me = 'u-me';
  static const kamala = 'u-kamala';
  static const ruwan = 'u-ruwan';
  static const joinCode = 'K7P2QXMH';

  String _nextRef() => 'PS-${_ref++}';

  void _seedActive({required bool meOrganizer}) {
    final c = _C(
      id: 'c1',
      name: 'Friends Seettu',
      status: 'active',
      rule: 'fixed',
      organizer: meOrganizer ? me : kamala,
      members: [me, kamala, ruwan],
      names: {me: 'Nadeeshi Perera', kamala: 'Kamala Silva', ruwan: 'Ruwan Perera'},
      positions: {kamala: 1, me: 2, ruwan: 3},
    );
    c.cycles.addAll([
      for (var n = 1; n <= 3; n++) {'number': n, 'dueDate': '2026-1${n - 1}-30', 'status': 'open', 'recipientUserId': [kamala, me, ruwan][n - 1]},
    ]);
    final k = _entry(c, 'contribution_recorded', subject: kamala, actor: kamala, amount: 500000, cycle: 1, method: 'cash');
    _entry(c, 'contribution_verified', subject: kamala, actor: c.organizer, cycle: 1, target: k['id'] as String);
    _entry(c, 'contribution_recorded', subject: ruwan, actor: ruwan, amount: 500000, cycle: 1, method: 'bank_transfer', receipt: 'BOC-77812');
    // A past correction for me, to show the passbook rule.
    final wrong = _entry(c, 'contribution_recorded', subject: me, actor: me, amount: 500000, cycle: 1, method: 'mobile_wallet', provider: 'eZ Cash');
    _entry(c, 'correction', subject: me, actor: c.organizer, cycle: 1, amount: -500000, target: wrong['id'] as String, note: 'No transfer received');
    _circles[c.id] = c;
  }

  void _seedDraft({required String rule}) {
    final c = _C(
      id: 'c2',
      name: 'Office Seettu',
      status: 'draft',
      rule: rule,
      organizer: me,
      members: [me, kamala, ruwan],
      names: {me: 'Nadeeshi Perera', kamala: 'Kamala Silva', ruwan: 'Ruwan Perera'},
      positions: {},
      planned: 4,
    );
    _circles[c.id] = c;
  }

  Map<String, dynamic> _entry(
    _C c,
    String type, {
    required String subject,
    required String actor,
    int? amount,
    int? cycle,
    String? method,
    String? provider,
    String? receipt,
    String? target,
    String? note,
  }) {
    final e = <String, dynamic>{
      'id': 'e${c.ledger.length + 1}-${c.id}',
      'seq': c.ledger.length + 1,
      'type': type,
      'reference': _nextRef(),
      'cycleNumber': cycle,
      'subjectUserId': subject,
      'subjectName': c.names[subject],
      'actorUserId': actor,
      'actorName': c.names[actor],
      'amountMinor': amount,
      'method': method,
      'provider': provider,
      'receiptReference': receipt,
      'targetEntryId': target,
      'note': note,
      'createdAt': DateTime.utc(2026, 9, 28, 9, c.ledger.length).toIso8601String(),
      'prevHash': '0' * 64,
      'hash': 'f' * 64,
    };
    c.ledger.add(e);
    return e;
  }

  String _statusOf(_C c, String entryId) {
    if (c.ledger.any((x) => x['type'] == 'correction' && x['targetEntryId'] == entryId)) return 'corrected';
    if (c.ledger.any((x) => x['type'] == 'contribution_verified' && x['targetEntryId'] == entryId)) return 'verified';
    return 'recorded';
  }

  Map<String, dynamic>? _liveContribution(_C c, String user, int cycle) {
    for (final e in c.ledger.reversed) {
      if (e['type'] == 'contribution_recorded' &&
          e['subjectUserId'] == user &&
          e['cycleNumber'] == cycle &&
          _statusOf(c, e['id'] as String) != 'corrected') {
        return e;
      }
    }
    return null;
  }

  Map<String, dynamic> _withStatus(_C c, Map<String, dynamic> e) =>
      {...e, 'status': e['type'] == 'contribution_recorded' ? _statusOf(c, e['id'] as String) : null};

  Map<String, dynamic> _json(_C c) {
    final open = c.cycles.where((x) => x['status'] == 'open').toList();
    final cur = open.isEmpty || c.status != 'active' ? null : open.first;
    final n = cur?['number'] as int?;
    String statusFor(String u) {
      if (n == null) return 'due';
      final e = _liveContribution(c, u, n);
      return e == null ? 'due' : _statusOf(c, e['id'] as String);
    }

    List<String> idsWith(String s) => [
          for (final u in c.members)
            if (n != null && statusFor(u) == s) _liveContribution(c, u, n)!['id'] as String,
        ];
    final verified = idsWith('verified');
    final awaiting = idsWith('recorded');
    final unpaid = [for (final u in c.members) if (statusFor(u) == 'due') u];
    final myC = n == null ? null : _liveContribution(c, me, n);

    return {
      'id': c.id,
      'name': c.name,
      'publicCode': 'RC-1${c.id.substring(1)}',
      'joinCode': joinCode,
      'role': c.organizer == me ? 'organizer' : 'member',
      'status': c.status,
      'contributionMinor': 500000,
      'interval': 'monthly',
      'turnRule': c.rule,
      'plannedCycles': c.planned ?? c.members.length,
      'memberCount': c.members.length,
      'firstDueDate': '2026-10-30',
      'myTurn': c.positions[me],
      'currentCycle': cur == null
          ? null
          : {
              'number': n,
              'dueDate': cur['dueDate'],
              'myStatus': statusFor(me),
              'myContribution': myC == null
                  ? null
                  : {
                      'entryId': myC['id'],
                      'reference': myC['reference'],
                      'method': myC['method'],
                      'recordedAt': myC['createdAt'],
                      'verifiedAt': statusFor(me) == 'verified' ? myC['createdAt'] : null,
                    },
              'recipient': {
                'userId': cur['recipientUserId'],
                'displayName': c.names[cur['recipientUserId']],
                'isYou': cur['recipientUserId'] == me,
              },
            },
      'members': [
        for (final u in c.members)
          {
            'userId': u,
            'displayName': c.names[u],
            'role': u == c.organizer ? 'organizer' : 'member',
            'payoutPosition': c.positions[u],
            'isYou': u == me,
            'joinedCycle': 1,
            'payout': {'ready': true, 'kinds': ['cash']},
          },
      ],
      'myPayout': [
        {'id': 'pm1', 'kind': 'cash', 'summary': 'Cash in person', 'preferred': true},
      ],
      'setup': {
        'seatsTotal': c.planned ?? c.members.length,
        'seatsTaken': c.members.length,
        'pendingInvitations': 0,
        'membersMissingPayout': <String>[],
        'canStart': c.status == 'draft' && c.members.length >= 2,
      },
      'invitations': <Object>[],
      'cycles': c.cycles,
      'lottery': {'commitment': c.commitment, 'seed': c.status == 'draft' ? null : c.seed},
      'current': cur == null
          ? null
          : {
              'number': n,
              'dueDate': cur['dueDate'],
              'members': [
                for (final u in c.members)
                  {
                    'userId': u,
                    'displayName': c.names[u],
                    'status': statusFor(u),
                    'contributionEntryId': _liveContribution(c, u, n!)?['id'],
                    'reference': _liveContribution(c, u, n)?['reference'],
                    'method': _liveContribution(c, u, n)?['method'],
                    'recordedAt': _liveContribution(c, u, n)?['createdAt'],
                    'verifiedAt': null,
                  },
              ],
              'totals': {
                'verified': {'count': verified.length, 'unitMinor': 500000, 'totalMinor': verified.length * 500000, 'entryIds': verified},
                'awaiting': {'count': awaiting.length, 'unitMinor': 500000, 'totalMinor': awaiting.length * 500000, 'entryIds': awaiting},
                'unpaid': {'count': unpaid.length, 'userIds': unpaid},
                'membersDue': c.members.length,
                'expectedMinor': c.members.length * 500000,
              },
            },
    };
  }

  CircleDetail _detailOf(String id) => CircleDetail.fromJson(_json(_circles[id]!));

  _C _get(String id) => _circles[id] ?? (throw ApiException(code: 'CIRCLE_NOT_FOUND', statusCode: 404));

  @override
  Future<List<CircleSummary>> list() async =>
      [for (final c in _circles.values) CircleSummary.fromJson(_json(c))];

  @override
  Future<CircleDetail> detail(String id) async => CircleDetail.fromJson(_json(_get(id)));

  @override
  Future<CircleDetail> create({
    required String name,
    required int contributionMinor,
    required CircleInterval interval,
    required TurnRule turnRule,
    required int plannedCycles,
    required DateTime firstDueDate,
    CollectionMode collectionMode = CollectionMode.directToRecipient,
  }) async {
    calls.add('create:$name:$contributionMinor:${wireName(interval)}:${wireName(turnRule)}:$plannedCycles:'
        '${DateFormat('yyyy-MM-dd').format(firstDueDate)}');
    final c = _C(
      id: 'c9',
      name: name,
      status: 'draft',
      rule: wireName(turnRule),
      organizer: me,
      members: [me],
      names: {me: 'Nadeeshi Perera'},
      positions: {},
      planned: plannedCycles,
    );
    _circles[c.id] = c;
    return _detailOf(c.id);
  }

  @override
  Future<CircleDetail> join(String code) async {
    calls.add('join:$code');
    if (code != joinCode) throw ApiException(code: 'INVALID_JOIN_CODE', statusCode: 404);
    final c = _C(
      id: 'c8',
      name: 'Temple Road Seettu',
      status: 'draft',
      rule: 'fixed',
      organizer: kamala,
      members: [kamala, me],
      names: {me: 'Nadeeshi Perera', kamala: 'Kamala Silva'},
      positions: {},
      planned: 5,
    );
    _circles[c.id] = c;
    return _detailOf(c.id);
  }

  @override
  Future<CircleDetail> setFirstDueDate(String id, DateTime date) async {
    calls.add('firstDue:${date.toIso8601String().substring(0, 10)}');
    return _detailOf(id);
  }

  @override
  Future<LedgerEntry> reverseVerification(String circleId, String entryId, String reason) async {
    calls.add('reverse:$entryId:$reason');
    return reject(circleId, entryId, reason);
  }

  @override
  Future<void> leave(String id) async {
    calls.add('leave:$id');
    _circles.remove(id);
  }

  @override
  Future<CircleDetail> removeMember(String id, String userId, {String? reason}) async {
    calls.add('remove:$userId:${reason ?? ''}');
    return _detailOf(id);
  }

  @override
  Future<CircleDetail> commitLottery(String id) async {
    calls.add('commit:$id');
    _get(id).commitment = 'a1b2' * 16;
    return _detailOf(id);
  }

  @override
  Future<CircleDetail> start(String id, {List<String>? order}) async {
    calls.add('start:$id:${order?.join(',') ?? 'lottery'}');
    final c = _get(id);
    final o = order ?? c.members;
    c.status = 'active';
    c.seed = c.commitment == null ? null : 'beef' * 16;
    for (var i = 0; i < o.length; i++) {
      c.positions[o[i]] = i + 1;
      c.cycles.add({'number': i + 1, 'dueDate': '2026-1${i % 3}-30', 'status': 'open', 'recipientUserId': o[i]});
    }
    return _detailOf(id);
  }

  @override
  Future<LedgerEntry> recordContribution(
    String circleId, {
    required int cycleNumber,
    required PaymentMethod method,
    required String clientEntryId,
    String? provider,
    String? receiptReference,
    String? subjectUserId,
    DateTime? deviceCreatedAt,
  }) async {
    attempts.add(clientEntryId);
    if (offline) throw ApiException(code: 'NETWORK');
    calls.add('record:${subjectUserId ?? me}:${wireName(method)}:${provider ?? ''}:${receiptReference ?? ''}');
    final c = _get(circleId);
    final subject = subjectUserId ?? me;
    if (_liveContribution(c, subject, cycleNumber) != null) {
      throw ApiException(code: 'ALREADY_RECORDED', statusCode: 409);
    }
    final e = _entry(c, 'contribution_recorded',
        subject: subject, actor: me, amount: 500000, cycle: cycleNumber, method: wireName(method), provider: provider, receipt: receiptReference);
    return LedgerEntry.fromJson(_withStatus(c, e));
  }

  @override
  Future<LedgerEntry> verify(String circleId, String entryId) async {
    calls.add('verify:$entryId');
    final c = _get(circleId);
    final target = c.ledger.firstWhere((e) => e['id'] == entryId);
    return LedgerEntry.fromJson(_withStatus(c, _entry(c, 'contribution_verified',
        subject: target['subjectUserId'] as String, actor: me, cycle: target['cycleNumber'] as int, target: entryId)));
  }

  @override
  Future<LedgerEntry> reject(String circleId, String entryId, String reason) async {
    calls.add('reject:$entryId:$reason');
    final c = _get(circleId);
    final target = c.ledger.firstWhere((e) => e['id'] == entryId);
    return LedgerEntry.fromJson(_withStatus(c, _entry(c, 'correction',
        subject: target['subjectUserId'] as String, actor: me, cycle: target['cycleNumber'] as int, amount: -500000, target: entryId, note: reason)));
  }

  @override
  Future<List<MyInvitation>> myInvitations() async => [for (final i in invitations) MyInvitation.fromJson(i)];

  @override
  Future<CircleDetail> acceptInvitation(String invitationId, {required List<String> methodIds, String? preferredId}) async {
    calls.add('accept:$invitationId:${methodIds.join(',')}:$preferredId');
    final inv = invitations.firstWhere((i) => i['id'] == invitationId);
    invitations.remove(inv);
    final circle = inv['circle'] as Map<String, dynamic>;
    final c = _C(
      id: circle['id'] as String,
      name: circle['name'] as String,
      rule: 'fixed',
      status: 'draft',
      organizer: 'u-org',
      members: ['u-org', me],
      names: {'u-org': 'Kamala Silva', me: 'Nadeeshi Perera'},
      positions: {},
      planned: circle['plannedCycles'] as int,
    );
    _circles[c.id] = c;
    return _detailOf(c.id);
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    calls.add('decline:$invitationId');
    invitations.removeWhere((i) => i['id'] == invitationId);
  }

  @override
  Future<PayTo> payTo(String id) async {
    final j = payToJson;
    if (j == null) throw ApiException(code: 'NO_OPEN_CYCLE', statusCode: 409);
    return PayTo.fromJson(j);
  }

  @override
  Future<(int, List<InvitablePal>)> invitablePals(String id) async =>
      (seatsLeft, [for (final p in invitable) InvitablePal.fromJson(p)]);

  @override
  Future<CircleDetail> invite(String id, List<String> userIds, {String? message}) async {
    calls.add('invite:$id:${userIds.join(',')}:${message ?? ''}');
    return _detailOf(id);
  }

  @override
  Future<CircleDetail> sharePayout(String id, List<String> methodIds, String preferredId) async {
    calls.add('share:$id:${methodIds.join(',')}:$preferredId');
    return _detailOf(id);
  }

  @override
  Future<CircleDetail> setCollectionMode(String id, CollectionMode mode) async {
    calls.add('mode:$id:${wireName(mode)}');
    return _detailOf(id);
  }

  @override
  Future<List<VerifyItem>> verifyQueue(String circleId) async {
    final c = _get(circleId);
    return [
      for (final e in c.ledger)
        if (e['type'] == 'contribution_recorded' && _statusOf(c, e['id'] as String) == 'recorded')
          VerifyItem.fromJson({
            'entryId': e['id'],
            'reference': e['reference'],
            'cycleNumber': e['cycleNumber'],
            'subjectUserId': e['subjectUserId'],
            'subjectName': e['subjectName'],
            'amountMinor': e['amountMinor'],
            'method': e['method'],
            'provider': e['provider'],
            'receiptReference': e['receiptReference'],
            'recordedAt': e['createdAt'],
            'actorName': e['actorName'],
          }),
    ];
  }

  @override
  Future<CircleDetail> closeCycle(String circleId, int cycleNumber, {required int acknowledgeUnpaid}) async {
    calls.add('close:$cycleNumber:$acknowledgeUnpaid');
    final c = _get(circleId);
    final current = _json(c)['current'] as Map<String, dynamic>;
    final totals = current['totals'] as Map<String, dynamic>;
    if ((totals['awaiting'] as Map)['count'] != 0) throw ApiException(code: 'PENDING_VERIFICATIONS', statusCode: 409);
    if ((totals['unpaid'] as Map)['count'] != acknowledgeUnpaid) {
      throw ApiException(code: 'UNPAID_NOT_ACKNOWLEDGED', statusCode: 409);
    }
    c.cycles.firstWhere((x) => x['number'] == cycleNumber)['status'] = 'closed';
    return _detailOf(circleId);
  }

  @override
  Future<List<LedgerEntry>> ledger(String circleId, {bool all = false}) async {
    final c = _get(circleId);
    final ids = {for (final e in c.ledger) e['id']: e};
    bool mine(Map<String, dynamic> e) =>
        e['subjectUserId'] == me || (e['targetEntryId'] != null && ids[e['targetEntryId']]?['subjectUserId'] == me);
    return [
      for (final e in c.ledger.reversed)
        if (all || mine(e)) LedgerEntry.fromJson(_withStatus(c, e)),
    ];
  }

}

enum FakeSeed { none, activeMember, activeOrganizer, draftFixedOrganizer, draftLotteryOrganizer }

class _C {
  _C({
    required this.id,
    required this.name,
    required this.status,
    required this.rule,
    required this.organizer,
    required this.members,
    required this.names,
    required this.positions,
    this.planned,
  });

  final String id;
  final String name;
  String status;
  final String rule;
  final String organizer;
  final List<String> members;
  final Map<String, String> names;
  final Map<String, int> positions;
  final int? planned;
  final cycles = <Map<String, dynamic>>[];
  final ledger = <Map<String, dynamic>>[];
  String? commitment;
  String? seed;
}
