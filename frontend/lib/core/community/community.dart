import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../auth/auth_controller.dart';

/// Where a circle stands on sharing totals with the community tier.
class CommunityConsent {
  const CommunityConsent({
    required this.shared,
    required this.mine,
    required this.granted,
    required this.needed,
    required this.largeEnough,
    required this.minimumMembers,
  });

  final bool shared;
  final bool mine;
  final int granted;
  final int needed;
  final bool largeEnough;
  final int minimumMembers;

  factory CommunityConsent.fromJson(Map<String, dynamic> j) => CommunityConsent(
        shared: j['shared'] as bool,
        mine: j['mine'] as bool,
        granted: (j['granted'] as num).toInt(),
        needed: (j['needed'] as num).toInt(),
        largeEnough: j['largeEnough'] as bool,
        minimumMembers: (j['minimumMembers'] as num).toInt(),
      );
}

enum DisputeCategory { paymentNotRecorded, paymentRejected, payoutNotReceived, other }

enum DisputeStatus { awaitingConsent, consented, resolved, declined }

const _categories = {
  'payment_not_recorded': DisputeCategory.paymentNotRecorded,
  'payment_rejected': DisputeCategory.paymentRejected,
  'payout_not_received': DisputeCategory.payoutNotReceived,
  'other': DisputeCategory.other,
};

const _statuses = {
  'awaiting_consent': DisputeStatus.awaitingConsent,
  'consented': DisputeStatus.consented,
  'resolved': DisputeStatus.resolved,
  'declined': DisputeStatus.declined,
};

String categoryWire(DisputeCategory c) => _categories.entries.firstWhere((e) => e.value == c).key;

class Dispute {
  const Dispute({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.raisedByYou,
    required this.references,
    required this.consentNeeded,
    required this.consentGranted,
    required this.myConsent,
    required this.views,
    this.resolutionNote,
  });

  final String id;
  final DisputeCategory category;
  final DisputeStatus status;
  final DateTime createdAt;
  final bool raisedByYou;
  final List<String> references;
  final int consentNeeded;
  final int consentGranted;

  /// null: my consent is not needed. false: I am being asked.
  final bool? myConsent;

  /// Each time an officer opened the evidence.
  final List<DateTime> views;
  final String? resolutionNote;

  bool get awaitingMe => status == DisputeStatus.awaitingConsent && myConsent == false;

  factory Dispute.fromJson(Map<String, dynamic> j) {
    final consent = j['consent'] as Map<String, dynamic>;
    return Dispute(
      id: j['id'] as String,
      category: _categories[j['category']] ?? DisputeCategory.other,
      status: _statuses[j['status']] ?? DisputeStatus.awaitingConsent,
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      raisedByYou: j['raisedByYou'] as bool? ?? false,
      references: [for (final e in j['entries'] as List) (e as Map)['reference'] as String],
      consentNeeded: (consent['needed'] as num).toInt(),
      consentGranted: (consent['granted'] as num).toInt(),
      myConsent: consent['mine'] as bool?,
      views: [for (final v in j['views'] as List? ?? const []) DateTime.parse(v as String).toLocal()],
      resolutionNote: j['resolutionNote'] as String?,
    );
  }
}

/// What an officer sees of a circle: a code and totals, never a name.
class CircleHealth {
  const CircleHealth({required this.circleCode, required this.members, required this.cyclesRun, this.onTimeRatePct});

  final String circleCode;
  final int members;
  final int cyclesRun;
  final int? onTimeRatePct;

  factory CircleHealth.fromJson(Map<String, dynamic> j) => CircleHealth(
        circleCode: j['circleCode'] as String,
        members: (j['members'] as num).toInt(),
        cyclesRun: (j['cyclesRun'] as num).toInt(),
        onTimeRatePct: (j['onTimeRatePct'] as num?)?.toInt(),
      );
}

class OfficerDispute {
  const OfficerDispute({
    required this.id,
    required this.circleCode,
    required this.category,
    required this.status,
    required this.entryCount,
    required this.createdAt,
  });

  final String id;
  final String circleCode;
  final DisputeCategory category;
  final DisputeStatus status;
  final int entryCount;
  final DateTime createdAt;

  factory OfficerDispute.fromJson(Map<String, dynamic> j) => OfficerDispute(
        id: j['id'] as String,
        circleCode: j['circleCode'] as String,
        category: _categories[j['category']] ?? DisputeCategory.other,
        status: _statuses[j['status']] ?? DisputeStatus.consented,
        entryCount: (j['entryCount'] as num).toInt(),
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );
}

class EvidenceEntry {
  const EvidenceEntry({
    required this.reference,
    required this.type,
    required this.createdAt,
    required this.recordedBy,
    required this.hash,
    this.cycleNumber,
    this.amountMinor,
    this.method,
    this.subject,
    this.status,
  });

  final String reference;
  final String type;
  final DateTime createdAt;

  /// "Member A": a label, never a name.
  final String recordedBy;
  final String hash;
  final int? cycleNumber;
  final int? amountMinor;
  final String? method;
  final String? subject;
  final String? status;

  factory EvidenceEntry.fromJson(Map<String, dynamic> j) => EvidenceEntry(
        reference: j['reference'] as String,
        type: j['type'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        recordedBy: j['recordedBy'] as String,
        hash: j['hash'] as String,
        cycleNumber: (j['cycleNumber'] as num?)?.toInt(),
        amountMinor: (j['amountMinor'] as num?)?.toInt(),
        method: j['method'] as String?,
        subject: j['subject'] as String?,
        status: j['status'] as String?,
      );
}

class CommunityApi {
  CommunityApi(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<CommunityConsent> consent(String circleId) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$circleId/community');
        return CommunityConsent.fromJson(r.data!);
      });

  Future<CommunityConsent> setConsent(String circleId, bool granted) => _call(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/circles/$circleId/community/consent',
          data: {'granted': granted},
        );
        return CommunityConsent.fromJson(r.data!);
      });

  Future<List<Dispute>> disputes(String circleId) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$circleId/disputes');
        return [for (final d in r.data!['disputes'] as List) Dispute.fromJson(d as Map<String, dynamic>)];
      });

  Future<Dispute> raise(String circleId, String entryId, DisputeCategory category) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/circles/$circleId/disputes',
          data: {
            'entryIds': [entryId],
            'category': categoryWire(category),
          },
        );
        return Dispute.fromJson(r.data!);
      });

  Future<Dispute> respond(String circleId, String disputeId, bool granted) => _call(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/circles/$circleId/disputes/$disputeId/consent',
          data: {'granted': granted},
        );
        return Dispute.fromJson(r.data!);
      });

  // ----- community officers only -----

  Future<List<CircleHealth>> overview() => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/community/overview');
        return [for (final c in r.data!['circles'] as List) CircleHealth.fromJson(c as Map<String, dynamic>)];
      });

  Future<List<OfficerDispute>> officerDisputes() => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/community/disputes');
        return [for (final d in r.data!['disputes'] as List) OfficerDispute.fromJson(d as Map<String, dynamic>)];
      });

  /// Each call is logged and the members concerned are told.
  Future<(OfficerDispute, List<EvidenceEntry>)> evidence(String disputeId) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/community/disputes/$disputeId/evidence');
        return (
          OfficerDispute.fromJson(r.data!['dispute'] as Map<String, dynamic>),
          [for (final e in r.data!['entries'] as List) EvidenceEntry.fromJson(e as Map<String, dynamic>)],
        );
      });

  Future<void> resolve(String disputeId, String note) => _call(() async {
        await _dio.post<void>('/community/disputes/$disputeId/resolve', data: {'note': note});
      });
}

final communityApiProvider = Provider<CommunityApi>((ref) => CommunityApi(ref.watch(apiClientProvider)));

final communityConsentProvider = FutureProvider.autoDispose.family<CommunityConsent, String>((ref, circleId) {
  ref.watch(authControllerProvider);
  return ref.watch(communityApiProvider).consent(circleId);
});

final disputesProvider = FutureProvider.autoDispose.family<List<Dispute>, String>((ref, circleId) {
  ref.watch(authControllerProvider);
  return ref.watch(communityApiProvider).disputes(circleId);
});

final communityOverviewProvider = FutureProvider.autoDispose<List<CircleHealth>>((ref) {
  ref.watch(authControllerProvider);
  return ref.watch(communityApiProvider).overview();
});

final officerDisputesProvider = FutureProvider.autoDispose<List<OfficerDispute>>((ref) {
  ref.watch(authControllerProvider);
  return ref.watch(communityApiProvider).officerDisputes();
});
