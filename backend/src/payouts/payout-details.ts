import { AppException } from '../common/errors/app.exception';
import { tryNormalizePhone } from '../common/normalize/phone';

export const PAYOUT_KINDS = [
  'bank_transfer',
  'mobile_wallet',
  'lankaqr',
  'cash',
] as const;
export type PayoutKind = (typeof PAYOUT_KINDS)[number];

/** What is encrypted at rest. Only the owner and the person paying them see it. */
export type PayoutDetails =
  | {
      kind: 'bank_transfer';
      bankName: string;
      branch: string | null;
      accountName: string;
      accountNumber: string;
    }
  | {
      kind: 'mobile_wallet';
      provider: string;
      accountName: string;
      number: string;
    }
  | { kind: 'lankaqr'; merchantName: string; reference: string }
  | { kind: 'cash'; note: string | null };

export interface PayoutInput {
  kind: PayoutKind;
  bankName?: string;
  branch?: string;
  accountName?: string;
  accountNumber?: string;
  provider?: string;
  number?: string;
  merchantName?: string;
  reference?: string;
  note?: string;
}

const invalid = (field: string, message: string) =>
  new AppException(400, 'INVALID_PAYOUT_DETAILS', message, { field });

const text = (
  v: string | undefined,
  field: string,
  min: number,
  max: number,
): string => {
  const t = (v ?? '').trim().replace(/\s+/g, ' ');
  if (t.length < min || t.length > max)
    throw invalid(field, `${field} must be ${min}-${max} characters`);
  return t;
};

const optional = (v: string | undefined, field: string, max: number) => {
  const t = (v ?? '').trim();
  return t ? text(t, field, 1, max) : null;
};

/** Validates per kind and normalises (digits only, E.164 wallet numbers). */
export function toPayoutDetails(input: PayoutInput): PayoutDetails {
  switch (input.kind) {
    case 'bank_transfer': {
      const accountNumber = (input.accountNumber ?? '').replace(/[\s-]/g, '');
      if (!/^\d{6,20}$/.test(accountNumber))
        throw invalid('accountNumber', 'Account number must be 6-20 digits');
      return {
        kind: 'bank_transfer',
        bankName: text(input.bankName, 'bankName', 2, 60),
        branch: optional(input.branch, 'branch', 60),
        accountName: text(input.accountName, 'accountName', 2, 80),
        accountNumber,
      };
    }
    case 'mobile_wallet': {
      const number = tryNormalizePhone(input.number ?? '');
      if (!number) throw invalid('number', 'Enter a Sri Lankan mobile number');
      return {
        kind: 'mobile_wallet',
        provider: text(input.provider, 'provider', 2, 30),
        accountName: text(input.accountName, 'accountName', 2, 80),
        number,
      };
    }
    case 'lankaqr':
      return {
        kind: 'lankaqr',
        merchantName: text(input.merchantName, 'merchantName', 2, 80),
        reference: text(input.reference, 'reference', 3, 40),
      };
    case 'cash':
      return { kind: 'cash', note: optional(input.note, 'note', 120) };
  }
}

const last4 = (s: string) => `••••${s.slice(-4)}`;

/** Safe one-liner for lists; never contains a full number. */
export function summarize(d: PayoutDetails): string {
  switch (d.kind) {
    case 'bank_transfer':
      return `${d.bankName} · ${last4(d.accountNumber)}`;
    case 'mobile_wallet':
      return `${d.provider} · ${last4(d.number)}`;
    case 'lankaqr':
      return `LankaQR · ${d.merchantName}`;
    case 'cash':
      return 'Cash in person';
  }
}
