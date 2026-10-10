import '../circles/circle_models.dart';

/// A payment recorded on this phone that the server has not confirmed yet.
/// [clientEntryId] is reused on every retry, so the server stores it once.
class PendingContribution {
  const PendingContribution({
    required this.clientEntryId,
    required this.userId,
    required this.circleId,
    required this.cycleNumber,
    required this.method,
    required this.deviceCreatedAt,
    this.provider,
    this.receiptReference,
    this.subjectUserId,
    this.failure,
  });

  final String clientEntryId;

  /// Who recorded it on this phone; another account never sees or sends it.
  final String userId;
  final String circleId;
  final int cycleNumber;
  final PaymentMethod method;
  final DateTime deviceCreatedAt;
  final String? provider;
  final String? receiptReference;

  /// Set when an organizer recorded cash for someone else.
  final String? subjectUserId;

  /// Server's refusal code once it has answered and will not accept this.
  final String? failure;

  bool get isMine => subjectUserId == null;

  PendingContribution failed(String code) => PendingContribution(
        clientEntryId: clientEntryId,
        userId: userId,
        circleId: circleId,
        cycleNumber: cycleNumber,
        method: method,
        deviceCreatedAt: deviceCreatedAt,
        provider: provider,
        receiptReference: receiptReference,
        subjectUserId: subjectUserId,
        failure: code,
      );
}

/// Where the outbox lives. On phones this is SQLite, so it survives the app
/// being closed.
abstract class OutboxStore {
  Future<List<PendingContribution>> all(String userId);
  Future<void> put(PendingContribution p);
  Future<void> remove(String clientEntryId);
}

class MemoryOutboxStore implements OutboxStore {
  final _rows = <String, PendingContribution>{};

  @override
  Future<List<PendingContribution>> all(String userId) async =>
      _rows.values.where((p) => p.userId == userId).toList()..sort((a, b) => a.deviceCreatedAt.compareTo(b.deviceCreatedAt));

  @override
  Future<void> put(PendingContribution p) async => _rows[p.clientEntryId] = p;

  @override
  Future<void> remove(String clientEntryId) async => _rows.remove(clientEntryId);
}
