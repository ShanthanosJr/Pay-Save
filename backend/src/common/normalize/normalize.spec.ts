import { AppException } from '../errors/app.exception';
import { normalizeEmail } from './email';
import { maskNic, normalizeNic } from './nic';
import { maskPhone, normalizePhone, tryNormalizePhone } from './phone';

describe('normalizePhone', () => {
  it.each([
    '0771234567',
    '94771234567',
    '+94771234567',
    '077 123 4567',
    '+94-77-1234567',
    '(077)1234567',
  ])('accepts %s', (input) => {
    expect(normalizePhone(input)).toBe('+94771234567');
  });

  it.each([
    '',
    '0112345678',
    '077123456',
    '07712345678',
    '+9477123456x',
    '+14155550100',
    '771234567',
    'abc',
  ])('rejects %p with 400', (input) => {
    expect(() => normalizePhone(input)).toThrow(AppException);
    try {
      normalizePhone(input);
    } catch (e) {
      expect((e as AppException).getStatus()).toBe(400);
    }
  });

  it('tryNormalizePhone returns null instead of throwing', () => {
    expect(tryNormalizePhone('nope')).toBeNull();
    expect(tryNormalizePhone('0771234567')).toBe('+94771234567');
  });

  it('masks the middle', () => {
    expect(maskPhone('+94771234521')).toBe('+9477*****21');
  });
});

describe('normalizeNic', () => {
  it('accepts old format case-insensitively and upper-cases', () => {
    expect(normalizeNic('853202345v')).toBe('853202345V');
    expect(normalizeNic(' 853202345X ')).toBe('853202345X');
  });

  it('accepts new 12 digit format', () => {
    expect(normalizeNic('198532002345')).toBe('198532002345');
  });

  it.each([
    '85320234V',
    '8532023456',
    '853202345Z',
    '19853200234',
    '1985320023456',
    '850002345V',
    '853672345V',
    '',
    'abc',
  ])('rejects %p', (input) => {
    expect(() => normalizeNic(input)).toThrow(AppException);
  });

  it('masks all but the last 3 chars', () => {
    expect(maskNic('853202345V')).toBe('*******45V');
  });
});

describe('normalizeEmail', () => {
  it('trims and lower-cases', () => {
    expect(normalizeEmail('  Foo@Example.COM ')).toBe('foo@example.com');
  });
});
