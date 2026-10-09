import { summarize, toPayoutDetails } from './payout-details';

describe('payout details', () => {
  it('normalises a bank account and masks it in the summary', () => {
    const d = toPayoutDetails({
      kind: 'bank_transfer',
      bankName: ' Bank of  Ceylon ',
      branch: 'Kandy',
      accountName: 'A. Silva',
      accountNumber: '0071-2345 6789',
    });
    expect(d).toEqual({
      kind: 'bank_transfer',
      bankName: 'Bank of Ceylon',
      branch: 'Kandy',
      accountName: 'A. Silva',
      accountNumber: '007123456789',
    });
    expect(summarize(d)).toBe('Bank of Ceylon · ••••6789');
  });

  it('stores wallet numbers in E.164 and masks them', () => {
    const d = toPayoutDetails({
      kind: 'mobile_wallet',
      provider: 'eZ Cash',
      accountName: 'Amaya',
      number: '077 123 4567',
    });
    expect(d).toMatchObject({ number: '+94771234567' });
    expect(summarize(d)).toBe('eZ Cash · ••••4567');
  });

  it('rejects bad input per kind', () => {
    const bad = [
      {
        kind: 'bank_transfer',
        bankName: 'BOC',
        accountName: 'A',
        accountNumber: '123',
      },
      {
        kind: 'bank_transfer',
        bankName: 'BOC',
        accountName: 'Amaya',
        accountNumber: 'abc123456',
      },
      {
        kind: 'mobile_wallet',
        provider: 'Genie',
        accountName: 'Amaya',
        number: '0112345678',
      },
      { kind: 'lankaqr', merchantName: 'Amaya', reference: 'x' },
      { kind: 'cash', note: 'x'.repeat(121) },
    ] as const;
    for (const b of bad) expect(() => toPayoutDetails(b)).toThrow();
  });

  it('cash needs no details', () => {
    expect(summarize(toPayoutDetails({ kind: 'cash' }))).toBe('Cash in person');
  });
});
