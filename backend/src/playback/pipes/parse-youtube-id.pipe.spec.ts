import { BadRequestException } from '@nestjs/common';
import { ParseYoutubeIdPipe } from './parse-youtube-id.pipe';

describe('ParseYoutubeIdPipe', () => {
  let pipe: ParseYoutubeIdPipe;

  beforeEach(() => {
    pipe = new ParseYoutubeIdPipe();
  });

  it('should be defined', () => {
    expect(pipe).toBeDefined();
  });

  it('should return the value if it is a valid 11-character YouTube ID', () => {
    const validId = 'zUJuVsSR5n4';
    expect(pipe.transform(validId)).toBe(validId);

    const validIdWithSpecialChars = 'zUJuVs-R_n4';
    expect(pipe.transform(validIdWithSpecialChars)).toBe(
      validIdWithSpecialChars,
    );
  });

  it('should throw BadRequestException if the value is not 11 characters', () => {
    expect(() => pipe.transform('short')).toThrow(BadRequestException);
    expect(() => pipe.transform('waytoolongtobeayoutubeid')).toThrow(
      BadRequestException,
    );
  });

  it('should throw BadRequestException if the value contains invalid characters', () => {
    expect(() => pipe.transform('zUJuVsSR5n!')).toThrow(BadRequestException);
    expect(() => pipe.transform('zUJuVsSR5n ')).toThrow(BadRequestException);
  });

  it('should throw BadRequestException if the value is empty or undefined', () => {
    expect(() => pipe.transform('')).toThrow(BadRequestException);
  });
});
