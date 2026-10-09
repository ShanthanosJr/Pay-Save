import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../api/api_exception.dart';
import 'circle_models.dart';

class CirclesApi {
  CirclesApi(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<CircleDetail> _detail(Future<Response<Map<String, dynamic>>> req) async =>
      CircleDetail.fromJson((await req).data!);

  Future<List<CircleSummary>> list() => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles');
        return (r.data!['circles'] as List).map((c) => CircleSummary.fromJson(c as Map<String, dynamic>)).toList();
      });

  Future<CircleDetail> detail(String id) => _call(() => _detail(_dio.get('/circles/$id')));

  Future<CircleDetail> create({
    required String name,
    required int contributionMinor,
    required CircleInterval interval,
    required TurnRule turnRule,
    required int plannedCycles,
    required DateTime firstDueDate,
    CollectionMode collectionMode = CollectionMode.directToRecipient,
  }) =>
      _call(() => _detail(_dio.post('/circles', data: {
            'collectionMode': wireName(collectionMode),
            'name': name,
            'contributionMinor': contributionMinor,
            'interval': wireName(interval),
            'turnRule': wireName(turnRule),
            'plannedCycles': plannedCycles,
            'firstDueDate': DateFormat('yyyy-MM-dd').format(firstDueDate),
          })));

  Future<CircleDetail> setCollectionMode(String id, CollectionMode mode) =>
      _call(() => _detail(_dio.patch('/circles/$id', data: {'collectionMode': wireName(mode)})));

  /// Which of my payment methods this circle may see.
  Future<CircleDetail> sharePayout(String id, List<String> methodIds, String preferredId) => _call(
        () => _detail(_dio.put('/circles/$id/payout-methods', data: {'methodIds': methodIds, 'preferredId': preferredId})),
      );

  /// Who I pay this cycle, with their full details (the server logs each view).
  Future<PayTo> payTo(String id) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$id/pay-to');
        return PayTo.fromJson(r.data!);
      });

  Future<(int, List<InvitablePal>)> invitablePals(String id) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$id/invitable-pals');
        return (
          _intOf(r.data!['seatsLeft']),
          [for (final p in r.data!['pals'] as List) InvitablePal.fromJson(p as Map<String, dynamic>)],
        );
      });

  Future<CircleDetail> invite(String id, List<String> userIds, {String? message}) => _call(
        () => _detail(_dio.post('/circles/$id/invitations', data: {'userIds': userIds, 'message': ?message})),
      );

  Future<CircleDetail> cancelInvitation(String id, String invitationId) =>
      _call(() => _detail(_dio.delete('/circles/$id/invitations/$invitationId')));

  Future<List<MyInvitation>> myInvitations() => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circle-invitations');
        return [for (final i in r.data!['invitations'] as List) MyInvitation.fromJson(i as Map<String, dynamic>)];
      });

  Future<CircleDetail> acceptInvitation(String invitationId, {required List<String> methodIds, String? preferredId}) =>
      _call(() => _detail(_dio.post(
            '/circle-invitations/$invitationId/accept',
            data: {'methodIds': methodIds, 'preferredId': ?preferredId},
          )));

  Future<void> declineInvitation(String invitationId) => _call(() async {
        await _dio.post<void>('/circle-invitations/$invitationId/decline');
      });

  Future<CircleDetail> join(String code) => _call(() => _detail(_dio.post('/circles/join', data: {'code': code})));

  Future<CircleDetail> commitLottery(String id) => _call(() => _detail(_dio.post('/circles/$id/lottery/commit')));

  Future<CircleDetail> start(String id, {List<String>? order}) =>
      _call(() => _detail(_dio.post('/circles/$id/start', data: {'order': ?order})));

  Future<LedgerEntry> recordContribution(
    String circleId, {
    required int cycleNumber,
    required PaymentMethod method,
    required String clientEntryId,
    String? provider,
    String? receiptReference,
    String? subjectUserId,
  }) =>
      _call(() async {
        final r = await _dio.post<Map<String, dynamic>>('/circles/$circleId/contributions', data: {
          'cycleNumber': cycleNumber,
          'method': wireName(method),
          'clientEntryId': clientEntryId,
          'deviceCreatedAt': DateTime.now().toUtc().toIso8601String(),
          'provider': ?provider,
          'receiptReference': ?receiptReference,
          'subjectUserId': ?subjectUserId,
        });
        return LedgerEntry.fromJson(r.data!['entry'] as Map<String, dynamic>);
      });

  Future<LedgerEntry> verify(String circleId, String entryId) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>('/circles/$circleId/contributions/$entryId/verify');
        return LedgerEntry.fromJson(r.data!['entry'] as Map<String, dynamic>);
      });

  Future<LedgerEntry> reject(String circleId, String entryId, String reason) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/circles/$circleId/contributions/$entryId/reject',
          data: {'reason': reason},
        );
        return LedgerEntry.fromJson(r.data!['entry'] as Map<String, dynamic>);
      });

  Future<List<VerifyItem>> verifyQueue(String circleId) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$circleId/verify-queue');
        return (r.data!['items'] as List).map((i) => VerifyItem.fromJson(i as Map<String, dynamic>)).toList();
      });

  Future<CircleDetail> closeCycle(String circleId, int cycleNumber, {required int acknowledgeUnpaid}) => _call(
        () => _detail(_dio.post(
          '/circles/$circleId/cycles/$cycleNumber/close',
          data: {'acknowledgeUnpaid': acknowledgeUnpaid},
        )),
      );

  Future<List<LedgerEntry>> ledger(String circleId, {bool all = false}) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/circles/$circleId/ledger',
          queryParameters: {'scope': all ? 'all' : 'mine'},
        );
        return (r.data!['entries'] as List).map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
      });
}

int _intOf(Object? v) => (v as num).toInt();
