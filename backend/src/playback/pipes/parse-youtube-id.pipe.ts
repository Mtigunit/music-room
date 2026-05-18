import { PipeTransform, Injectable, BadRequestException } from '@nestjs/common';

@Injectable()
export class ParseYoutubeIdPipe implements PipeTransform<string, string> {
  transform(value: string): string {
    const youtubeIdRegex = /^[a-zA-Z0-9_-]{11}$/;
    if (!value || !youtubeIdRegex.test(value)) {
      throw new BadRequestException(
        'Invalid YouTube video ID format. Must be an 11-character alphanumeric string.',
      );
    }
    return value;
  }
}
