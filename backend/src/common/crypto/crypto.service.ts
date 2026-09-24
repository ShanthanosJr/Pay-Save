import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG } from '../../config/app-config';
import type { AppConfig } from '../../config/app-config';
import { decryptAesGcm, encryptAesGcm } from './aes-gcm';
import { hmacHex, sha256Hex } from './hash';
import { hashPassword, verifyPassword } from './password';

export type CryptoKeys = Pick<AppConfig, 'piiEncryptionKey' | 'piiHmacKey'>;

@Injectable()
export class CryptoService {
  constructor(@Inject(APP_CONFIG) private readonly keys: CryptoKeys) {}

  encryptPii(plaintext: string, field: string): Buffer {
    return encryptAesGcm(this.keys.piiEncryptionKey, plaintext, field);
  }

  decryptPii(blob: Buffer, field: string): string {
    return decryptAesGcm(this.keys.piiEncryptionKey, blob, field);
  }

  lookupHash(value: string): string {
    return hmacHex(this.keys.piiHmacKey, value);
  }

  hashPassword(password: string): Promise<string> {
    return hashPassword(password);
  }

  verifyPassword(password: string, stored: string): Promise<boolean> {
    return verifyPassword(password, stored);
  }

  hashToken(token: string): string {
    return sha256Hex(token);
  }
}
