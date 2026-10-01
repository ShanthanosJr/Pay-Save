import { createHash } from 'node:crypto';
import {
  generateJoinCode,
  JOIN_CODE_ALPHABET,
  normalizeJoinCode,
} from './join-code';
import { lotteryCommitment, lotteryOrder, newLotterySeed } from './lottery';
import {
  addMonthsClamped,
  dueDateFor,
  isValidDate,
  localDate,
} from './schedule';

describe('due dates', () => {
  it('weekly and fortnightly add whole weeks', () => {
    expect(dueDateFor('2026-10-30', 'weekly', 1)).toBe('2026-10-30');
    expect(dueDateFor('2026-10-30', 'weekly', 2)).toBe('2026-11-06');
    expect(dueDateFor('2026-12-29', 'weekly', 2)).toBe('2027-01-05');
    expect(dueDateFor('2026-10-30', 'fortnightly', 3)).toBe('2026-11-27');
  });

  it('monthly keeps the day of month, clamped to month end', () => {
    expect(dueDateFor('2026-10-15', 'monthly', 4)).toBe('2027-01-15');
    expect(dueDateFor('2027-01-31', 'monthly', 2)).toBe('2027-02-28');
    expect(dueDateFor('2028-01-31', 'monthly', 2)).toBe('2028-02-29');
    expect(dueDateFor('2027-01-31', 'monthly', 3)).toBe('2027-03-31');
    expect(dueDateFor('2026-08-31', 'monthly', 2)).toBe('2026-09-30');
    expect(dueDateFor('2026-11-30', 'monthly', 4)).toBe('2027-02-28');
    expect(addMonthsClamped('2026-12-31', 14)).toBe('2028-02-29');
  });

  it('validates calendar dates', () => {
    expect(isValidDate('2026-02-28')).toBe(true);
    expect(isValidDate('2026-02-29')).toBe(false);
    expect(isValidDate('2026-13-01')).toBe(false);
    expect(isValidDate('26-01-01')).toBe(false);
  });

  it('uses the Sri Lanka calendar date', () => {
    expect(localDate(new Date('2026-09-30T18:29:00Z'))).toBe('2026-09-30');
    expect(localDate(new Date('2026-09-30T18:31:00Z'))).toBe('2026-10-01');
  });
});

describe('lottery', () => {
  const ids = [
    '6f1c1f0e-0000-4000-8000-000000000001',
    '6f1c1f0e-0000-4000-8000-000000000002',
    '6f1c1f0e-0000-4000-8000-000000000003',
    '6f1c1f0e-0000-4000-8000-000000000004',
  ];
  const seed = 'a'.repeat(64);

  it('commitment is sha256(seed) hex', () => {
    expect(lotteryCommitment(seed)).toBe(
      createHash('sha256').update(seed).digest('hex'),
    );
    const s = newLotterySeed();
    expect(s.seed).toMatch(/^[0-9a-f]{64}$/);
    expect(s.commitment).toBe(lotteryCommitment(s.seed));
  });

  it('order is deterministic, independent of input order, and a permutation', () => {
    const a = lotteryOrder(seed, ids);
    const b = lotteryOrder(seed, [...ids].reverse());
    expect(a).toEqual(b);
    expect([...a].sort()).toEqual([...ids].sort());
    const keys = a.map((id) =>
      createHash('sha256').update(`${seed}:${id}`).digest('hex'),
    );
    expect(keys).toEqual([...keys].sort());
  });

  it('a different seed gives a different order (for these inputs)', () => {
    expect(lotteryOrder('b'.repeat(64), ids)).not.toEqual(
      lotteryOrder(seed, ids),
    );
  });
});

describe('join codes', () => {
  it('generates 8 chars from the unambiguous alphabet', () => {
    for (let i = 0; i < 200; i++) {
      const code = generateJoinCode();
      expect(code).toHaveLength(8);
      for (const ch of code) expect(JOIN_CODE_ALPHABET).toContain(ch);
    }
  });

  it('normalises case, spaces and dashes', () => {
    expect(normalizeJoinCode(' k7p2-qxmh ')).toBe('K7P2QXMH');
    expect(normalizeJoinCode('K7P2 QXMH')).toBe('K7P2QXMH');
    expect(normalizeJoinCode('k7-p2 -qx mh')).toBe('K7P2QXMH');
  });

  it('rejects impossible codes', () => {
    expect(normalizeJoinCode('K7P2QXM')).toBeNull();
    expect(normalizeJoinCode('K7P2QXMHX')).toBeNull();
    expect(normalizeJoinCode('K7P2QXM0')).toBeNull();
    expect(normalizeJoinCode('K7P2QXMI')).toBeNull();
    expect(normalizeJoinCode('')).toBeNull();
  });
});
