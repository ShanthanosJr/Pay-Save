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
  }) =>
      _call(() => _detail(_dio.post('/circles', data: {
            'name': name,
            'contributionMinor': contributionMinor,
            'interval': wireName(interval),
            'turnRule': wireName(turnRule),
            'plannedCycles': plannedCycles,
            'firstDueDate': DateFormat('yyyy-MM-dd').format(firstDueDate),
          })));

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
