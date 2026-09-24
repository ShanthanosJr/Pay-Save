import { randomBytes } from 'node:crypto';
import { decryptAesGcm, encryptAesGcm } from './aes-gcm';
import { CryptoService } from './crypto.service';
import { hmacHex, safeEqual } from './hash';
import { hashPassword, verifyPassword } from './password';

describe('aes-gcm', () => {
  const key = randomBytes(32);

  it('round-trips and uses a fresh IV each time', () => {
    const a = encryptAesGcm(key, '+94771234567', 'phone');
    const b = encryptAesGcm(key, '+94771234567', 'phone');
    expect(a.equals(b)).toBe(false);
    expect(decryptAesGcm(key, a, 'phone')).toBe('+94771234567');
  });

  it('rejects tampering, wrong key and wrong aad', () => {
    const blob = encryptAesGcm(key, 'secret', 'phone');
    const tampered = Buffer.from(blob);
    tampered[tampered.length - 1] ^= 1;
    expect(() => decryptAesGcm(key, tampered, 'phone')).toThrow();
    expect(() => decryptAesGcm(randomBytes(32), blob, 'phone')).toThrow();
    expect(() => decryptAesGcm(key, blob, 'nic')).toThrow();
    expect(() => decryptAesGcm(key, Buffer.alloc(5))).toThrow();
  });
});

describe('hash helpers', () => {
  it('hmac is deterministic and key dependent', () => {
    const k1 = randomBytes(32);
    expect(hmacHex(k1, 'x')).toBe(hmacHex(k1, 'x'));
    expect(hmacHex(k1, 'x')).not.toBe(hmacHex(randomBytes(32), 'x'));
    expect(hmacHex(k1, 'x')).toMatch(/^[0-9a-f]{64}$/);
  });

  it('safeEqual compares strings of any length', () => {
    expect(safeEqual('abc', 'abc')).toBe(true);
    expect(safeEqual('abc', 'abd')).toBe(false);
    expect(safeEqual('abc', 'abcd')).toBe(false);
  });
});

describe('password hashing', () => {
  it('produces scrypt$N$r$p$salt$hash and verifies', async () => {
    const h = await hashPassword('correct horse 1');
    expect(h).toMatch(/^scrypt\$32768\$8\$1\$[^$]+\$[^$]+$/);
    expect(await verifyPassword('correct horse 1', h)).toBe(true);
    expect(await verifyPassword('wrong horse 1', h)).toBe(false);
    expect(h).not.toBe(await hashPassword('correct horse 1'));
  });

  it('rejects malformed stored hashes', async () => {
    expect(await verifyPassword('x', 'garbage')).toBe(false);
    expect(await verifyPassword('x', 'bcrypt$1$2$3$4$5')).toBe(false);
    expect(await verifyPassword('x', 'scrypt$a$b$c$d$e')).toBe(false);
  });
});

describe('CryptoService', () => {
  const svc = new CryptoService({
    piiEncryptionKey: randomBytes(32),
    piiHmacKey: randomBytes(32),
  });

  it('encrypts pii and hashes for lookup', () => {
    expect(svc.decryptPii(svc.encryptPii('123456789V', 'nic'), 'nic')).toBe(
      '123456789V',
    );
    expect(svc.lookupHash('a')).toBe(svc.lookupHash('a'));
    expect(svc.hashToken('t')).toMatch(/^[0-9a-f]{64}$/);
  });
});
