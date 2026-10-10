import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pay_and_save/core/api/api_exception.dart';
import 'package:pay_and_save/core/circles/circle_models.dart';
import 'package:pay_and_save/core/community/community.dart';
import 'package:pay_and_save/core/notifications/notifications.dart';
import 'package:pay_and_save/core/reminders/reminders.dart';
import 'package:pay_and_save/core/statements/statements.dart';

class FakeNotificationsApi extends NotificationsApi {
  FakeNotificationsApi() : super(Dio());

  List<AppNotification> items = [];
  int markedRead = 0;

  @override
  Future<Inbox> list() async => Inbox(items: items, unread: items.where((n) => !n.read).length);

  @override
  Future<void> markRead({List<String>? ids}) async {
    markedRead++;
    items = [
      for (final n in items)
        AppNotification(
          id: n.id,
          kind: n.kind,
          createdAt: n.createdAt,
          read: true,
          payload: n.payload,
          circleId: n.circleId,
          circleName: n.circleName,
        ),
    ];
  }
}

class FakeRemindersApi extends RemindersApi {
  FakeRemindersApi() : super(Dio());

  ReminderPreferences prefs = const ReminderPreferences(
    enabled: false,
    daysBefore: [],
    channels: [],
    suggestedDaysBefore: [3],
    emailVerified: false,
  );
  final nudged = <String>[];

  @override
  Future<ReminderPreferences> get(String circleId) async => prefs;

  @override
  Future<ReminderPreferences> set(
    String circleId, {
    required bool enabled,
    required List<int> daysBefore,
    required List<String> channels,
  }) async {
    return prefs = ReminderPreferences(
      enabled: enabled,
      daysBefore: daysBefore,
      channels: channels,
      suggestedDaysBefore: const [3],
      emailVerified: prefs.emailVerified,
    );
  }

  @override
  Future<void> nudge(String circleId, String userId) async => nudged.add(userId);
}

class FakeStatementsApi extends StatementsApi {
  FakeStatementsApi() : super(Dio());

  final issued = <Statement>[];
  bool nothingVerified = false;

  @override
  Future<List<Statement>> list(String circleId) async => issued.reversed.toList();

  @override
  Future<Statement> issue(String circleId) async {
    if (nothingVerified) throw ApiException(code: 'NOTHING_VERIFIED', statusCode: 409);
    final s = Statement(
      id: 's${issued.length + 1}',
      verificationCode: 'PS-ABCD-EFGH-JK${issued.length + 2}3',
      verifyUrl: 'https://api.example.lk/verify/PS-ABCD-EFGH-JK${issued.length + 2}3',
      issuedAt: DateTime(2026, 10, 10, 9, 30),
      contributions: const Total(count: 3, unitMinor: 500000, totalMinor: 1500000, entryIds: ['e1', 'e2', 'e3']),
      lines: [
        for (var i = 1; i <= 3; i++)
          StatementLine(reference: 'PS-100$i', cycleNumber: i, amountMinor: 500000, verifiedAt: DateTime(2026, i, 20)),
      ],
      chainHeadHash: 'a' * 64,
    );
    issued.add(s);
    return s;
  }

  @override
  Future<Uint8List> file(String statementId, {bool csv = false}) async => Uint8List.fromList([37, 80, 68, 70]);
}

class FakeCommunityApi extends CommunityApi {
  FakeCommunityApi() : super(Dio());

  CommunityConsent state = const CommunityConsent(
    shared: false,
    mine: false,
    granted: 2,
    needed: 5,
    largeEnough: true,
    minimumMembers: 5,
  );
  List<Dispute> list = [];
  final raised = <(String, DisputeCategory)>[];
  int evidenceViews = 0;
  String? resolvedNote;

  @override
  Future<CommunityConsent> consent(String circleId) async => state;

  @override
  Future<CommunityConsent> setConsent(String circleId, bool granted) async {
    return state = CommunityConsent(
      shared: false,
      mine: granted,
      granted: state.granted + (granted ? 1 : -1),
      needed: state.needed,
      largeEnough: state.largeEnough,
      minimumMembers: state.minimumMembers,
    );
  }

  @override
  Future<List<Dispute>> disputes(String circleId) async => list;

  Dispute _dispute(String id, DisputeStatus status, {bool? mine, String ref = 'PS-1021'}) => Dispute(
        id: id,
        category: DisputeCategory.paymentRejected,
        status: status,
        createdAt: DateTime(2026, 10, 9),
        raisedByYou: mine == true,
        references: [ref],
        consentNeeded: 2,
        consentGranted: status == DisputeStatus.awaitingConsent ? 1 : 2,
        myConsent: mine,
        views: const [],
      );

  void seedAwaitingMe() => list = [_dispute('d1', DisputeStatus.awaitingConsent, mine: false)];

  @override
  Future<Dispute> raise(String circleId, String entryId, DisputeCategory category) async {
    raised.add((entryId, category));
    return _dispute('d${raised.length}', DisputeStatus.awaitingConsent, mine: true);
  }

  @override
  Future<Dispute> respond(String circleId, String disputeId, bool granted) async {
    final d = _dispute(disputeId, granted ? DisputeStatus.consented : DisputeStatus.declined, mine: granted);
    list = [d];
    return d;
  }

  @override
  Future<List<CircleHealth>> overview() async =>
      const [CircleHealth(circleCode: 'RC-021', members: 6, cyclesRun: 6, onTimeRatePct: 83)];

  OfficerDispute get _officerDispute => OfficerDispute(
        id: 'd1',
        circleCode: 'RC-021',
        category: DisputeCategory.paymentRejected,
        status: resolvedNote == null ? DisputeStatus.consented : DisputeStatus.resolved,
        entryCount: 1,
        createdAt: DateTime(2026, 10, 9),
      );

  @override
  Future<List<OfficerDispute>> officerDisputes() async => [_officerDispute];

  @override
  Future<(OfficerDispute, List<EvidenceEntry>)> evidence(String disputeId) async {
    evidenceViews++;
    return (
      _officerDispute,
      [
        EvidenceEntry(
          reference: 'PS-1021',
          type: 'contribution_recorded',
          createdAt: DateTime(2026, 10, 1, 8),
          recordedBy: 'Member A',
          subject: 'Member A',
          hash: 'b' * 64,
          cycleNumber: 4,
          amountMinor: 450000,
          method: 'cash',
          status: 'corrected',
        ),
      ],
    );
  }

  @override
  Future<void> resolve(String disputeId, String note) async => resolvedNote = note;
}
