import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PoolClient } from 'pg';
import { Db, toInt, toIntOrNull } from '../database/transaction';
import {
  AppendInput,
  ContributionRef,
  EntryStatus,
  LedgerEntry,
  LedgerEntryType,
  PaymentMethod,
} from './ledger.types';

interface EntryRow {
  id: string;
  seq: string;
  entry_type: LedgerEntryType;
  reference: string;
  cycle_number: number | null;
  subject_user_id: string | null;
  subject_name: string | null;
  actor_user_id: string;
  actor_name: string;
  amount_minor: string | null;
  method: PaymentMethod | null;
  method_provider: string | null;
  receipt_reference: string | null;
  target_entry_id: string | null;
  note: string | null;
  created_at: Date;
  prev_hash: string;
  hash: string;
  status: EntryStatus | null;
}

const ENTRY_SELECT = `
  SELECT e.id, e.seq, e.entry_type, e.reference, cy.number AS cycle_number,
         e.subject_user_id, su.display_name AS subject_name,
         e.actor_user_id, au.display_name AS actor_name,
         e.amount_minor, e.method, e.method_provider, e.receipt_reference,
         e.target_entry_id, e.note, e.created_at, e.prev_hash, e.hash,
         CASE
           WHEN e.entry_type <> 'contribution_recorded' THEN NULL
           WHEN EXISTS (SELECT 1 FROM ledger_entries c
                        WHERE c.target_entry_id = e.id AND c.entry_type = 'correction') THEN 'corrected'
           WHEN EXISTS (SELECT 1 FROM ledger_entries v
                        WHERE v.target_entry_id = e.id AND v.entry_type = 'contribution_verified') THEN 'verified'
           ELSE 'recorded'
         END AS status
  FROM ledger_entries e
  LEFT JOIN cycles cy ON cy.id = e.cycle_id
  LEFT JOIN users su ON su.id = e.subject_user_id
  JOIN users au ON au.id = e.actor_user_id`;

const toEntry = (r: EntryRow): LedgerEntry => ({
  id: r.id,
  seq: toInt(r.seq),
  type: r.entry_type,
  reference: r.reference,
  cycleNumber: r.cycle_number,
  subjectUserId: r.subject_user_id,
  subjectName: r.subject_name,
  actorUserId: r.actor_user_id,
  actorName: r.actor_name,
  amountMinor: toIntOrNull(r.amount_minor),
  method: r.method,
  provider: r.method_provider,
  receiptReference: r.receipt_reference,
  targetEntryId: r.target_entry_id,
  note: r.note,
  createdAt: r.created_at.toISOString(),
  prevHash: r.prev_hash,
  hash: r.hash,
  status: r.status,
});

/** The only code path that inserts into ledger_entries (AGENTS rule 3). */
@Injectable()
export class LedgerService {
  /** Appends one entry inside the caller's transaction; returns its id. */
  async append(tx: PoolClient, input: AppendInput): Promise<string> {
    const { rows } = await tx.query<{ id: string }>(
      `INSERT INTO ledger_entries
         (circle_id, cycle_id, subject_user_id, actor_user_id, entry_type, amount_minor,
          method, method_provider, receipt_reference, reference, target_entry_id, note,
          payload, client_entry_id, device_created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'PS-' || nextval('ledger_reference_seq'),
               $10, $11, $12::jsonb, $13, $14)
       RETURNING id`,
      [
        input.circleId,
        input.cycleId ?? null,
        input.subjectUserId ?? null,
        input.actorUserId,
        input.type,
        input.amountMinor ?? null,
        input.method ?? null,
        input.provider ?? null,
        input.receiptReference ?? null,
        input.targetEntryId ?? null,
        input.note ?? null,
        JSON.stringify(input.payload ?? {}),
        input.clientEntryId ?? randomUUID(),
        input.deviceCreatedAt ?? null,
      ],
    );
    return rows[0].id;
  }

  async getEntry(db: Db, circleId: string, id: string): Promise<LedgerEntry> {
    const { rows } = await db.query<EntryRow>(
      `${ENTRY_SELECT} WHERE e.circle_id = $1 AND e.id = $2`,
      [circleId, id],
    );
    if (!rows[0]) throw new Error(`ledger entry ${id} not found`);
    return toEntry(rows[0]);
  }

  /** Newest first. With `mineFor`, only entries about that user or targeting one. */
  async listEntries(
    db: Db,
    circleId: string,
    mineFor?: string,
  ): Promise<LedgerEntry[]> {
    const params: unknown[] = [circleId];
    let where = 'e.circle_id = $1';
    if (mineFor) {
      params.push(mineFor);
      where += ` AND (e.subject_user_id = $2 OR EXISTS (
        SELECT 1 FROM ledger_entries t WHERE t.id = e.target_entry_id AND t.subject_user_id = $2))`;
    }
    const { rows } = await db.query<EntryRow>(
      `${ENTRY_SELECT} WHERE ${where} ORDER BY e.seq DESC`,
      params,
    );
    return rows.map(toEntry);
  }

  async findByClientEntryId(
    db: Db,
    circleId: string,
    clientEntryId: string,
  ): Promise<{
    id: string;
    type: LedgerEntryType;
    actorUserId: string;
  } | null> {
    const { rows } = await db.query<{
      id: string;
      entry_type: LedgerEntryType;
      actor_user_id: string;
    }>(
      `SELECT id, entry_type, actor_user_id FROM ledger_entries
       WHERE circle_id = $1 AND client_entry_id = $2`,
      [circleId, clientEntryId],
    );
    const r = rows[0];
    return r
      ? { id: r.id, type: r.entry_type, actorUserId: r.actor_user_id }
      : null;
  }

  async findContribution(
    db: Db,
    circleId: string,
    entryId: string,
  ): Promise<ContributionRef | null> {
    const { rows } = await db.query<{
      id: string;
      cycle_id: string;
      subject_user_id: string;
      actor_user_id: string;
      amount_minor: string;
      verified: boolean;
      corrected: boolean;
    }>(
      `SELECT e.id, e.cycle_id, e.subject_user_id, e.actor_user_id, e.amount_minor,
              EXISTS (SELECT 1 FROM ledger_entries v WHERE v.target_entry_id = e.id
                        AND v.entry_type = 'contribution_verified') AS verified,
              EXISTS (SELECT 1 FROM ledger_entries c WHERE c.target_entry_id = e.id
                        AND c.entry_type = 'correction') AS corrected
       FROM ledger_entries e
       WHERE e.circle_id = $1 AND e.id = $2 AND e.entry_type = 'contribution_recorded'`,
      [circleId, entryId],
    );
    const r = rows[0];
    if (!r) return null;
    return {
      id: r.id,
      cycleId: r.cycle_id,
      subjectUserId: r.subject_user_id,
      actorUserId: r.actor_user_id,
      amountMinor: toInt(r.amount_minor),
      verified: r.verified,
      corrected: r.corrected,
    };
  }
}
