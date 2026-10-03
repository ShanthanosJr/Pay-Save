import { randomBytes } from 'node:crypto';
import { sha256Hex } from '../../common/crypto/hash';

export function newLotterySeed(): { seed: string; commitment: string } {
  const seed = randomBytes(32).toString('hex');
  return { seed, commitment: lotteryCommitment(seed) };
}

export function lotteryCommitment(seed: string): string {
  return sha256Hex(seed);
}

/** Members sorted by sha256(seed + ':' + userId) hex ascending. */
export function lotteryOrder(seed: string, userIds: string[]): string[] {
  return userIds
    .map((id) => ({ id, key: sha256Hex(`${seed}:${id}`) }))
    .sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0))
    .map((x) => x.id);
}
