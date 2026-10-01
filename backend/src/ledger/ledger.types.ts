export const PAYMENT_METHODS = [
  'cash',
  'bank_transfer',
  'lankaqr',
  'mobile_wallet',
] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export type LedgerEntryType =
  | 'contribution_recorded'
  | 'contribution_verified'
  | 'correction'
  | 'payout'
  | 'member_added'
  | 'member_removed'
  | 'turn_order_set'
  | 'cycle_closed';

export interface AppendInput {
  circleId: string;
  type: LedgerEntryType;
  actorUserId: string;
  cycleId?: string | null;
  subjectUserId?: string | null;
  amountMinor?: number | null;
  method?: PaymentMethod | null;
  provider?: string | null;
  receiptReference?: string | null;
  targetEntryId?: string | null;
  note?: string | null;
  payload?: Record<string, unknown>;
  clientEntryId?: string;
  deviceCreatedAt?: string | null;
}

export type EntryStatus = 'recorded' | 'verified' | 'corrected';

export interface LedgerEntry {
  id: string;
  seq: number;
  type: LedgerEntryType;
  reference: string;
  cycleNumber: number | null;
  subjectUserId: string | null;
  subjectName: string | null;
  actorUserId: string;
  actorName: string;
  amountMinor: number | null;
  method: PaymentMethod | null;
  provider: string | null;
  receiptReference: string | null;
  targetEntryId: string | null;
  note: string | null;
  createdAt: string;
  prevHash: string;
  hash: string;
  status: EntryStatus | null;
}

export interface ContributionRef {
  id: string;
  cycleId: string;
  subjectUserId: string;
  actorUserId: string;
  amountMinor: number;
  verified: boolean;
  corrected: boolean;
}
