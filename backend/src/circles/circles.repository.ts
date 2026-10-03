import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { Db, toInt } from '../database/transaction';
import type { PaymentMethod } from '../ledger/ledger.types';
import type { MemberRole } from './circle-role.guard';
import type { CircleInterval } from './domain/schedule';
import type { TurnRule } from './dto/circles.dto';

export type CircleStatus = 'draft' | 'active' | 'completed';
export type MemberCycleStatus = 'due' | 'overdue' | 'recorded' | 'verified';

export interface CircleRecord {
  id: string;
  publicCode: string;
  joinCode: string | null;
  name: string;
  contributionMinor: number;
  interval: CircleInterval;
  turnRule: TurnRule;
  plannedCycles: number;
  status: CircleStatus;
  firstDueDate: string | null;
  lotteryCommitment: string | null;
  lotterySeed: string | null;
  lotteryCommittedAt: Date | null;
  lotteryRevealedAt: Date | null;
  createdAt: Date;
}

export interface MemberRecord {
  userId: string;
  displayName: string;
  role: MemberRole;
  payoutPosition: number | null;
  joinedCycle: number;
}

export interface CycleRecord {
  id: string;
  number: number;
  dueDate: string;
  status: 'open' | 'closed';
  payoutUserId: string | null;
  closedAt: Date | null;
}

export interface MemberStatusRecord {
  userId: string;
  displayName: string;
  status: MemberCycleStatus;
  contributionId: string | null;
  reference: string | null;
  method: PaymentMethod | null;
  recordedAt: Date | null;
  verifiedAt: Date | null;
}

export interface CycleTotalsRecord {
  membersDue: number;
  unitMinor: number;
  expectedMinor: number;
  verifiedCount: number;
  verifiedTotalMinor: number;
  verifiedIds: string[];
  awaitingCount: number;
  awaitingTotalMinor: number;
  awaitingIds: string[];
  unpaidCount: number;
  unpaidUserIds: string[];
}

interface CircleRow {
  id: string;
  public_code: string;
  join_code: string | null;
  name: string;
  contribution_minor: string;
  interval: CircleInterval;
  turn_rule: TurnRule;
  planned_cycles: number;
  status: CircleStatus;
  first_due_date: string | null;
  lottery_commitment: string | null;
  lottery_seed: string | null;
  lottery_committed_at: Date | null;
  lottery_revealed_at: Date | null;
  created_at: Date;
}

const CIRCLE_COLUMNS = `id, public_code, join_code, name, contribution_minor, interval, turn_rule,
  planned_cycles, status, first_due_date::text AS first_due_date, lottery_commitment, lottery_seed,
  lottery_committed_at, lottery_revealed_at, created_at`;

const toCircle = (r: CircleRow): CircleRecord => ({
  id: r.id,
  publicCode: r.public_code,
  joinCode: r.join_code,
  name: r.name,
  contributionMinor: toInt(r.contribution_minor),
  interval: r.interval,
  turnRule: r.turn_rule,
  plannedCycles: r.planned_cycles,
  status: r.status,
  firstDueDate: r.first_due_date,
  lotteryCommitment: r.lottery_commitment,
  lotterySeed: r.lottery_seed,
  lotteryCommittedAt: r.lottery_committed_at,
  lotteryRevealedAt: r.lottery_revealed_at,
  createdAt: r.created_at,
});

export interface NewCircle {
  joinCode: string;
  name: string;
  contributionMinor: number;
  interval: CircleInterval;
  turnRule: TurnRule;
  plannedCycles: number;
  firstDueDate: string;
  createdBy: string;
}

@Injectable()
export class CirclesRepository {
  async get(db: Db, id: string): Promise<CircleRecord | null> {
    const { rows } = await db.query<CircleRow>(
      `SELECT ${CIRCLE_COLUMNS} FROM circles WHERE id = $1`,
      [id],
    );
    return rows[0] ? toCircle(rows[0]) : null;
  }

  /** Row lock that serialises every write to one circle. */
  async lock(tx: PoolClient, id: string): Promise<CircleRecord | null> {
    const { rows } = await tx.query<CircleRow>(
      `SELECT ${CIRCLE_COLUMNS} FROM circles WHERE id = $1 FOR UPDATE`,
      [id],
    );
    return rows[0] ? toCircle(rows[0]) : null;
  }

  async lockByJoinCode(
    tx: PoolClient,
    joinCode: string,
  ): Promise<CircleRecord | null> {
    const { rows } = await tx.query<CircleRow>(
      `SELECT ${CIRCLE_COLUMNS} FROM circles WHERE join_code = $1 FOR UPDATE`,
      [joinCode],
    );
    return rows[0] ? toCircle(rows[0]) : null;
  }

  /** Returns null when the join code is already taken. */
  async insert(tx: PoolClient, c: NewCircle): Promise<string | null> {
    const { rows } = await tx.query<{ id: string }>(
      `INSERT INTO circles (public_code, join_code, name, contribution_minor, interval, turn_rule,
                            planned_cycles, first_due_date, created_by)
       VALUES ('RC-' || nextval('circle_public_code_seq'), $1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (join_code) DO NOTHING
       RETURNING id`,
      [
        c.joinCode,
        c.name,
        c.contributionMinor,
        c.interval,
        c.turnRule,
        c.plannedCycles,
        c.firstDueDate,
        c.createdBy,
      ],
    );
    return rows[0]?.id ?? null;
  }

  async addMember(
    tx: PoolClient,
    circleId: string,
    userId: string,
    role: MemberRole,
  ): Promise<void> {
    await tx.query(
      `INSERT INTO circle_members (circle_id, user_id, role, joined_cycle)
       VALUES ($1, $2, $3, 1)`,
      [circleId, userId, role],
    );
  }

  async circleIdsFor(db: Db, userId: string): Promise<string[]> {
    const { rows } = await db.query<{ id: string }>(
      `SELECT c.id FROM circles c
       JOIN circle_members m ON m.circle_id = c.id
       WHERE m.user_id = $1 AND m.left_cycle IS NULL
       ORDER BY CASE c.status WHEN 'active' THEN 0 WHEN 'draft' THEN 1 ELSE 2 END,
                c.created_at DESC, c.id`,
      [userId],
    );
    return rows.map((r) => r.id);
  }

  /** Sorted by payout position (nulls last), then join order. */
  async members(db: Db, circleId: string): Promise<MemberRecord[]> {
    const { rows } = await db.query<{
      user_id: string;
      display_name: string;
      role: MemberRole;
      payout_position: number | null;
      joined_cycle: number;
    }>(
      `SELECT m.user_id, u.display_name, m.role, m.payout_position, m.joined_cycle
       FROM circle_members m JOIN users u ON u.id = m.user_id
       WHERE m.circle_id = $1 AND m.left_cycle IS NULL
       ORDER BY m.payout_position NULLS LAST, m.joined_at, m.user_id`,
      [circleId],
    );
    return rows.map((r) => ({
      userId: r.user_id,
      displayName: r.display_name,
      role: r.role,
      payoutPosition: r.payout_position,
      joinedCycle: r.joined_cycle,
    }));
  }

  async cycles(db: Db, circleId: string): Promise<CycleRecord[]> {
    const { rows } = await db.query<{
      id: string;
      number: number;
      due_date: string;
      status: 'open' | 'closed';
      payout_user_id: string | null;
      closed_at: Date | null;
    }>(
      `SELECT id, number, due_date::text AS due_date, status, payout_user_id, closed_at
       FROM cycles WHERE circle_id = $1 ORDER BY number`,
      [circleId],
    );
    return rows.map((r) => ({
      id: r.id,
      number: r.number,
      dueDate: r.due_date,
      status: r.status,
      payoutUserId: r.payout_user_id,
      closedAt: r.closed_at,
    }));
  }

  async setLotteryCommitment(
    tx: PoolClient,
    circleId: string,
    seed: string,
    commitment: string,
    at: Date,
  ): Promise<void> {
    await tx.query(
      `UPDATE circles SET lottery_seed = $2, lottery_commitment = $3, lottery_committed_at = $4
       WHERE id = $1`,
      [circleId, seed, commitment, at],
    );
  }

  async activate(
    tx: PoolClient,
    circleId: string,
    order: string[],
    dueDates: string[],
    at: Date,
    revealLottery: boolean,
  ): Promise<void> {
    await tx.query(
      `UPDATE circles SET status = 'active', planned_cycles = $2, started_at = $3,
              lottery_revealed_at = CASE WHEN $4 THEN $3 ELSE lottery_revealed_at END
       WHERE id = $1`,
      [circleId, order.length, at, revealLottery],
    );
    await tx.query(
      `UPDATE circle_members m SET payout_position = o.pos
       FROM unnest($2::uuid[]) WITH ORDINALITY AS o(user_id, pos)
       WHERE m.circle_id = $1 AND m.user_id = o.user_id`,
      [circleId, order],
    );
    await tx.query(
      `INSERT INTO cycles (circle_id, number, due_date, payout_user_id)
       SELECT $1, o.pos, d.due, o.user_id
       FROM unnest($2::uuid[]) WITH ORDINALITY AS o(user_id, pos)
       JOIN unnest($3::date[]) WITH ORDINALITY AS d(due, pos) ON d.pos = o.pos`,
      [circleId, order, dueDates],
    );
  }

  async closeCycle(tx: PoolClient, cycleId: string, at: Date): Promise<void> {
    await tx.query(
      `UPDATE cycles SET status = 'closed', closed_at = $2 WHERE id = $1`,
      [cycleId, at],
    );
  }

  async completeIfNoOpenCycles(
    tx: PoolClient,
    circleId: string,
  ): Promise<void> {
    await tx.query(
      `UPDATE circles SET status = 'completed'
       WHERE id = $1 AND NOT EXISTS (
         SELECT 1 FROM cycles WHERE circle_id = $1 AND status = 'open')`,
      [circleId],
    );
  }

  /** Per-member status for one cycle; ONLY from v_cycle_member_status (AGENTS rule 7). */
  async memberStatuses(db: Db, cycleId: string): Promise<MemberStatusRecord[]> {
    const { rows } = await db.query<{
      user_id: string;
      display_name: string;
      status: MemberCycleStatus;
      contribution_id: string | null;
      reference: string | null;
      method: PaymentMethod | null;
      recorded_at: Date | null;
      verified_at: Date | null;
    }>(
      `SELECT s.user_id, u.display_name, s.status, s.contribution_id, s.reference, e.method,
              s.recorded_at, s.verified_at
       FROM v_cycle_member_status s
       JOIN users u ON u.id = s.user_id
       JOIN circle_members m ON m.circle_id = s.circle_id AND m.user_id = s.user_id
       LEFT JOIN ledger_entries e ON e.id = s.contribution_id
       WHERE s.cycle_id = $1
       ORDER BY m.payout_position NULLS LAST, m.joined_at, m.user_id`,
      [cycleId],
    );
    return rows.map((r) => ({
      userId: r.user_id,
      displayName: r.display_name,
      status: r.status,
      contributionId: r.contribution_id,
      reference: r.reference,
      method: r.method,
      recordedAt: r.recorded_at,
      verifiedAt: r.verified_at,
    }));
  }

  async memberStatus(
    db: Db,
    cycleId: string,
    userId: string,
  ): Promise<{
    status: MemberCycleStatus;
    contributionId: string | null;
  } | null> {
    const { rows } = await db.query<{
      status: MemberCycleStatus;
      contribution_id: string | null;
    }>(
      `SELECT status, contribution_id FROM v_cycle_member_status
       WHERE cycle_id = $1 AND user_id = $2`,
      [cycleId, userId],
    );
    return rows[0]
      ? { status: rows[0].status, contributionId: rows[0].contribution_id }
      : null;
  }

  /** Totals with their parts, aggregated in SQL from v_cycle_member_status. */
  async cycleTotals(db: Db, cycleId: string): Promise<CycleTotalsRecord> {
    const { rows } = await db.query<{
      members_due: number;
      unit_minor: string;
      expected_minor: string;
      verified_count: number;
      verified_total_minor: string;
      verified_ids: string[];
      awaiting_count: number;
      awaiting_total_minor: string;
      awaiting_ids: string[];
      unpaid_count: number;
      unpaid_user_ids: string[];
    }>(
      `SELECT count(s.user_id)::int AS members_due,
              c.contribution_minor AS unit_minor,
              (count(s.user_id) * c.contribution_minor)::bigint AS expected_minor,
              count(*) FILTER (WHERE s.status = 'verified')::int AS verified_count,
              COALESCE(sum(s.amount_minor) FILTER (WHERE s.status = 'verified'), 0)::bigint
                AS verified_total_minor,
              COALESCE(array_agg(s.contribution_id::text ORDER BY s.recorded_at)
                FILTER (WHERE s.status = 'verified'), '{}') AS verified_ids,
              count(*) FILTER (WHERE s.status = 'recorded')::int AS awaiting_count,
              COALESCE(sum(s.amount_minor) FILTER (WHERE s.status = 'recorded'), 0)::bigint
                AS awaiting_total_minor,
              COALESCE(array_agg(s.contribution_id::text ORDER BY s.recorded_at)
                FILTER (WHERE s.status = 'recorded'), '{}') AS awaiting_ids,
              count(*) FILTER (WHERE s.status IN ('due', 'overdue'))::int AS unpaid_count,
              COALESCE(array_agg(s.user_id::text ORDER BY s.user_id)
                FILTER (WHERE s.status IN ('due', 'overdue')), '{}') AS unpaid_user_ids
       FROM cycles cy
       JOIN circles c ON c.id = cy.circle_id
       LEFT JOIN v_cycle_member_status s ON s.cycle_id = cy.id
       WHERE cy.id = $1
       GROUP BY c.contribution_minor`,
      [cycleId],
    );
    const r = rows[0];
    return {
      membersDue: r.members_due,
      unitMinor: toInt(r.unit_minor),
      expectedMinor: toInt(r.expected_minor),
      verifiedCount: r.verified_count,
      verifiedTotalMinor: toInt(r.verified_total_minor),
      verifiedIds: r.verified_ids,
      awaitingCount: r.awaiting_count,
      awaitingTotalMinor: toInt(r.awaiting_total_minor),
      awaitingIds: r.awaiting_ids,
      unpaidCount: r.unpaid_count,
      unpaidUserIds: r.unpaid_user_ids,
    };
  }
}
