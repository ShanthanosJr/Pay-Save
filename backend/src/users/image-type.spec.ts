import { avatarUrl, sniffImageType } from './image-type';

describe('sniffImageType', () => {
  it('recognises jpeg, png and webp by magic bytes', () => {
    expect(sniffImageType(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0]))).toBe(
      'image/jpeg',
    );
    expect(
      sniffImageType(
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0]),
      ),
    ).toBe('image/png');
    expect(
      sniffImageType(
        Buffer.concat([
          Buffer.from('RIFF'),
          Buffer.alloc(4),
          Buffer.from('WEBPVP8 '),
        ]),
      ),
    ).toBe('image/webp');
  });

  it('rejects everything else, whatever it claims to be', () => {
    expect(sniffImageType(Buffer.from('<svg onload=alert(1)>'))).toBeNull();
    expect(sniffImageType(Buffer.from('GIF89a'))).toBeNull();
    expect(sniffImageType(Buffer.alloc(0))).toBeNull();
  });
});

describe('avatarUrl', () => {
  it('is versioned by update time and null without a photo', () => {
    expect(avatarUrl('u1', new Date(1000))).toBe('/users/u1/avatar?v=1000');
    expect(avatarUrl('u1', null)).toBeNull();
  });
});
