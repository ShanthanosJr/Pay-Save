import type { AvatarContentType } from './avatar.storage';

/**
 * Identifies an image from its magic bytes. The client's declared
 * Content-Type is never trusted.
 */
export function sniffImageType(buf: Buffer): AvatarContentType | null {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff)
    return 'image/jpeg';
  if (
    buf.length >= 8 &&
    buf
      .subarray(0, 8)
      .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  )
    return 'image/png';
  if (
    buf.length >= 12 &&
    buf.toString('ascii', 0, 4) === 'RIFF' &&
    buf.toString('ascii', 8, 12) === 'WEBP'
  )
    return 'image/webp';
  return null;
}

export function avatarUrl(
  userId: string,
  updatedAt: Date | null,
): string | null {
  return updatedAt ? `/users/${userId}/avatar?v=${updatedAt.getTime()}` : null;
}
