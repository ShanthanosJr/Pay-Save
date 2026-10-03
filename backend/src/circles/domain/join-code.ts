import { randomInt } from 'node:crypto';

export const JOIN_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const JOIN_CODE_LENGTH = 8;

const VALID = new RegExp(`^[${JOIN_CODE_ALPHABET}]{${JOIN_CODE_LENGTH}}$`);

export function generateJoinCode(): string {
  let code = '';
  for (let i = 0; i < JOIN_CODE_LENGTH; i++) {
    code += JOIN_CODE_ALPHABET[randomInt(JOIN_CODE_ALPHABET.length)];
  }
  return code;
}

/** Uppercases and strips whitespace and dashes; null if it cannot be a join code. */
export function normalizeJoinCode(input: string): string | null {
  const code = input
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '');
  return VALID.test(code) ? code : null;
}
