import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { CryptoService } from '../common/crypto/crypto.service';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { Db, withTransaction } from '../database/transaction';
import { AddPayoutMethodDto } from './dto/payouts.dto';
import {
  PayoutDetails,
  PayoutKind,
  summarize,
  toPayoutDetails,
} from './payout-details';
import { MethodRow, PayoutsRepository } from './payouts.repository';

export const MAX_PAYOUT_METHODS = 10;
const FIELD = 'payout_details';

/** A member's own method, with full details (only ever sent to its owner). */
export interface PayoutMethod {
  id: string;
  kind: PayoutKind;
  summary: string;
  isDefault: boolean;
  details: PayoutDetails;
}

/** A method shared with a circle, as the payer sees it. */
export interface SharedPayoutMethod extends PayoutMethod {
  preferred: boolean;
}

/** Masked view used in circle setup. */
export interface PayoutSummary {
  id: string;
  kind: PayoutKind;
  summary: string;
  preferred: boolean;
}

@Injectable()
export class PayoutsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly repo: PayoutsRepository,
    private readonly crypto: CryptoService,
  ) {}

  private open(r: MethodRow): PayoutMethod {
    return {
      id: r.id,
      kind: r.kind,
      summary: r.summary,
      isDefault: r.is_default,
      details: JSON.parse(
        this.crypto.decryptPii(r.details_encrypted, FIELD),
      ) as PayoutDetails,
    };
  }

  async listMine(userId: string): Promise<{ methods: PayoutMethod[] }> {
    return {
      methods: (await this.repo.listMine(this.pool, userId)).map((r) =>
        this.open(r),
      ),
    };
  }

  /** The first method a member adds becomes their default automatically. */
  async add(
    userId: string,
    dto: AddPayoutMethodDto,
  ): Promise<{ methods: PayoutMethod[] }> {
    const details = toPayoutDetails(dto);
    await withTransaction(this.pool, async (tx) => {
      const count = await this.repo.countMine(tx, userId);
      if (count >= MAX_PAYOUT_METHODS)
        throw new AppException(
          409,
          'TOO_MANY_PAYOUT_METHODS',
          `Keep up to ${MAX_PAYOUT_METHODS} payment methods`,
        );
      const id = await this.repo.insert(tx, {
        userId,
        kind: details.kind,
        summary: summarize(details),
        details: this.crypto.encryptPii(JSON.stringify(details), FIELD),
      });
      if (count === 0 || dto.makeDefault)
        await this.repo.setDefault(tx, userId, id);
    });
    return this.listMine(userId);
  }

  async makeDefault(
    userId: string,
    methodId: string,
  ): Promise<{ methods: PayoutMethod[] }> {
    const ok = await withTransaction(this.pool, (tx) =>
      this.repo.setDefault(tx, userId, methodId),
    );
    if (!ok) throw notFound();
    return this.listMine(userId);
  }

  async remove(
    userId: string,
    methodId: string,
  ): Promise<{ methods: PayoutMethod[] }> {
    await withTransaction(this.pool, async (tx) => {
      const relying = await this.repo.circlesRelyingOn(tx, userId, methodId);
      if (relying.length > 0)
        throw new AppException(
          409,
          'PAYOUT_METHOD_IN_USE',
          'Share another method with these circles first',
          { circles: relying },
        );
      if (!(await this.repo.archive(tx, userId, methodId))) throw notFound();
    });
    return this.listMine(userId);
  }

  // ---------- used by the circles module ----------

  /** Shares the member's default method with a circle they just joined, if they have one. */
  async shareDefault(db: Db, circleId: string, userId: string): Promise<void> {
    const id = await this.repo.defaultMethodId(db, userId);
    if (id) await this.repo.replaceShares(db, circleId, userId, [id], id);
  }

  async share(
    db: Db,
    circleId: string,
    userId: string,
    methodIds: string[],
    preferredId: string,
  ): Promise<void> {
    if (!methodIds.includes(preferredId))
      throw new AppException(
        400,
        'INVALID_PREFERRED_METHOD',
        'The preferred method must be one of the shared methods',
      );
    if (!(await this.repo.ownsActive(db, userId, methodIds))) throw notFound();
    await this.repo.replaceShares(db, circleId, userId, methodIds, preferredId);
  }

  async mySharedSummaries(
    db: Db,
    circleId: string,
    userId: string,
  ): Promise<PayoutSummary[]> {
    return (await this.repo.shares(db, circleId, userId)).map((r) => ({
      id: r.id,
      kind: r.kind,
      summary: r.summary,
      preferred: r.preferred,
    }));
  }

  kindsByMember(db: Db, circleId: string) {
    return this.repo.kindsByMember(db, circleId);
  }

  /**
   * Full details of `ownerId`'s methods for one circle, shown to `viewerId`
   * because they have to pay them. Every reveal is logged.
   */
  async revealFor(
    db: Db,
    a: {
      circleId: string;
      viewerId: string;
      ownerId: string;
      cycleId: string | null;
    },
  ): Promise<SharedPayoutMethod[]> {
    const rows = await this.repo.shares(db, a.circleId, a.ownerId);
    if (rows.length > 0 && a.viewerId !== a.ownerId)
      await this.repo.logAccess(db, a);
    return rows.map((r) => ({ ...this.open(r), preferred: r.preferred }));
  }
}

const notFound = () =>
  new AppException(404, 'PAYOUT_METHOD_NOT_FOUND', 'Payment method not found');
