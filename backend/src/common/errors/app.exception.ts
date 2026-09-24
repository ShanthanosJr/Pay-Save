import { HttpException } from '@nestjs/common';

export class AppException extends HttpException {
  constructor(
    status: number,
    readonly code: string,
    message: string,
    extra: Record<string, unknown> = {},
  ) {
    super({ statusCode: status, code, message, ...extra }, status);
  }
}
