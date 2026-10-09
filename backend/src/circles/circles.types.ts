import type { PaymentMethod } from '../ledger/ledger.types';
import type { MemberRole } from './circle-role.guard';
import type { PayoutKind } from '../payouts/payout-details';
import type {
  PayoutSummary,
  SharedPayoutMethod,
} from '../payouts/payouts.service';
import type {
  CircleStatus,
  CollectionMode,
  MemberCycleStatus,
} from './circles.repository';
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
  collectionMode: CollectionMode;
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
    avatarUrl: string | null;
    role: MemberRole;
    payoutPosition: number | null;
    isYou: boolean;
    joinedCycle: number;
    /** Kinds only; never details. Ready = at least one way to pay them. */
    payout: { ready: boolean; kinds: PayoutKind[] };
  }[];
  /** My methods shared with this circle (masked). */
  myPayout: PayoutSummary[];
  setup: {
    seatsTotal: number;
    seatsTaken: number;
    pendingInvitations: number;
    membersMissingPayout: string[];
    canStart: boolean;
  };
  /** Organizer only; empty for members. */
  invitations: {
    id: string;
    invitedAt: string;
    person: InvitePerson;
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

export interface InvitePerson {
  id: string;
  fullName: string;
  username: string | null;
  avatarUrl: string | null;
}

export interface InvitablePal extends InvitePerson {
  state: 'member' | 'invited' | 'available';
  invitationId: string | null;
}

export interface MyInvitation {
  id: string;
  message: string | null;
  invitedAt: string;
  organizer: InvitePerson;
  circle: {
    id: string;
    name: string;
    contributionMinor: number;
    interval: CircleInterval;
    turnRule: TurnRule;
    plannedCycles: number;
    collectionMode: CollectionMode;
    firstDueDate: string | null;
    memberCount: number;
    seatsLeft: number;
    /** The pot each member receives on their turn, with its arithmetic. */
    payout: Total;
    palsInside: string[];
  };
}

/** Who to pay this cycle and how, for the signed-in member. */
export interface PayTo {
  cycleNumber: number;
  dueDate: string;
  collectionMode: CollectionMode;
  /** You are the one being paid this cycle. */
  youReceive: boolean;
  payee: InvitePerson;
  /** What to send: one contribution, or the verified pot when the organizer hands it over. */
  amount: Total;
  /** Suggested text for the bank or wallet note, so the payee can match it. */
  reference: string;
  methods: SharedPayoutMethod[];
}
