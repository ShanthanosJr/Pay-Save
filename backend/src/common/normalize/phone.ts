import { AppException } from '../errors/app.exception';

export function normalizePhone(input: string): string {
  const cleaned = input.replace(/[\s\-()]/g, '');
  const m = /^(?:0|94|\+94)(7\d{8})$/.exec(cleaned);
  if (!m) throw new AppException(400, 'INVALID_PHONE', 'Invalid phone number');
  return `+94${m[1]}`;
}

export function tryNormalizePhone(input: string): string | null {
  try {
    return normalizePhone(input);
  } catch {
    return null;
  }
}

export function maskPhone(e164: string): string {
  return `${e164.slice(0, 5)}${'*'.repeat(Math.max(0, e164.length - 7))}${e164.slice(-2)}`;
}
