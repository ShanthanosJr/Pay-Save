import type { PaymentMethod } from '../ledger/ledger.types';
import type { MemberRole } from './circle-role.guard';
import type { CircleStatus, MemberCycleStatus } from './circles.repository';
import type { CircleInterval } from './domain/schedule';
import type { TurnRule } from './dto/circles.dto';

export interface Total {
  count: number;
  unitMinor: number;
  totalMinor: number;
  entryIds: string[];
}

export interface MyContribution {
  entryId: string;
  reference: string | null;
  method: PaymentMethod | null;
  recordedAt: string | null;
  verifiedAt: string | null;
}

export interface CircleSummary {
  id: string;
  name: string;
  publicCode: string;
  joinCode: string | null;
  role: MemberRole;
  status: CircleStatus;
  contributionMinor: number;
  interval: CircleInterval;
  turnRule: TurnRule;
  plannedCycles: number;
  memberCount: number;
  firstDueDate: string | null;
  myTurn: number | null;
  currentCycle: null | {
    number: number;
    dueDate: string;
    myStatus: MemberCycleStatus | null;
    myContribution: MyContribution | null;
    recipient: { userId: string; displayName: string; isYou: boolean } | null;
  };
}

export interface CircleDetail extends CircleSummary {
  members: {
    userId: string;
    displayName: string;
    role: MemberRole;
    payoutPosition: number | null;
    isYou: boolean;
    joinedCycle: number;
  }[];
  cycles: {
    number: number;
    dueDate: string;
    status: 'open' | 'closed';
    recipientUserId: string | null;
    closedAt: string | null;
  }[];
  lottery: {
    commitment: string | null;
    seed: string | null;
    committedAt: string | null;
    revealedAt: string | null;
  };
  current: null | {
    number: number;
    dueDate: string;
    members: {
      userId: string;
      displayName: string;
      status: MemberCycleStatus;
      contributionEntryId: string | null;
      reference: string | null;
      method: PaymentMethod | null;
      recordedAt: string | null;
      verifiedAt: string | null;
    }[];
    totals: {
      verified: Total;
      awaiting: Total;
      unpaid: { count: number; userIds: string[] };
      membersDue: number;
      expectedMinor: number;
    };
  };
}
