import 'package:drift/drift.dart';

import '../circles/circle_models.dart';
import 'outbox_store.dart';

/// The device database. One table, written with plain SQL so no generated
/// code is needed.
class OutboxDatabase extends GeneratedDatabase {
  OutboxDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => customStatement('''
          CREATE TABLE outbox (
            client_entry_id   TEXT PRIMARY KEY,
            user_id           TEXT NOT NULL,
            circle_id         TEXT NOT NULL,
            cycle_number      INTEGER NOT NULL,
            method            TEXT NOT NULL,
            provider          TEXT,
            receipt_reference TEXT,
            subject_user_id   TEXT,
            device_created_at TEXT NOT NULL,
            failure           TEXT
          )'''),
      );
}

class DriftOutboxStore implements OutboxStore {
  DriftOutboxStore(this._db);

  final OutboxDatabase _db;

  @override
  Future<List<PendingContribution>> all(String userId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM outbox WHERE user_id = ? ORDER BY device_created_at',
      variables: [Variable<String>(userId)],
    ).get();
    return [
      for (final r in rows)
        PendingContribution(
          clientEntryId: r.read<String>('client_entry_id'),
          userId: r.read<String>('user_id'),
          circleId: r.read<String>('circle_id'),
          cycleNumber: r.read<int>('cycle_number'),
          method: PaymentMethod.values.firstWhere((m) => wireName(m) == r.read<String>('method')),
          deviceCreatedAt: DateTime.parse(r.read<String>('device_created_at')),
          provider: r.readNullable<String>('provider'),
          receiptReference: r.readNullable<String>('receipt_reference'),
          subjectUserId: r.readNullable<String>('subject_user_id'),
          failure: r.readNullable<String>('failure'),
        ),
    ];
  }

  @override
  Future<void> put(PendingContribution p) => _db.customStatement(
        '''INSERT OR REPLACE INTO outbox
             (client_entry_id, user_id, circle_id, cycle_number, method, provider,
              receipt_reference, subject_user_id, device_created_at, failure)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          p.clientEntryId,
          p.userId,
          p.circleId,
          p.cycleNumber,
          wireName(p.method),
          p.provider,
          p.receiptReference,
          p.subjectUserId,
          p.deviceCreatedAt.toUtc().toIso8601String(),
          p.failure,
        ],
      );

  @override
  Future<void> remove(String clientEntryId) =>
      _db.customStatement('DELETE FROM outbox WHERE client_entry_id = ?', [clientEntryId]);
}
