import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const IV_LEN = 12;
const TAG_LEN = 16;

// Layout: iv(12) | tag(16) | ciphertext. `aad` binds the ciphertext to its field.
export function encryptAesGcm(
  key: Buffer,
  plaintext: string,
  aad?: string,
): Buffer {
  const iv = randomBytes(IV_LEN);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  if (aad) cipher.setAAD(Buffer.from(aad));
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), ct]);
}

export function decryptAesGcm(key: Buffer, blob: Buffer, aad?: string): string {
  if (blob.length < IV_LEN + TAG_LEN) throw new Error('Ciphertext too short');
  const iv = blob.subarray(0, IV_LEN);
  const tag = blob.subarray(IV_LEN, IV_LEN + TAG_LEN);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  if (aad) decipher.setAAD(Buffer.from(aad));
  return Buffer.concat([
    decipher.update(blob.subarray(IV_LEN + TAG_LEN)),
    decipher.final(),
  ]).toString('utf8');
}
