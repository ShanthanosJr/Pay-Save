import {
  Controller,
  Get,
  Header,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { CircleRole, CurrentMembership } from '../circles/circle-role.guard';
import type { Membership } from '../circles/circle-role.guard';
import {
  renderStatementCsv,
  renderStatementPdf,
  renderVerifyPage,
} from './statement-render';
import { StatementsService } from './statements.service';

@Controller()
@UseGuards(JwtAuthGuard)
export class StatementsController {
  constructor(private readonly statements: StatementsService) {}

  @Post('circles/:id/statements')
  @CircleRole('member')
  @Throttle({ default: { limit: 6, ttl: 60_000 } })
  issue(@CurrentMembership() m: Membership) {
    return this.statements.issue(m);
  }

  @Get('circles/:id/statements')
  @CircleRole('member')
  list(@CurrentMembership() m: Membership) {
    return this.statements.list(m);
  }

  /** Owner only (checked in the service); `?format=csv` for a spreadsheet. */
  @Get('statements/:statementId/file')
  async file(
    @CurrentUser() user: AuthUser,
    @Param('statementId', new ParseUUIDPipe()) id: string,
    @Query('format') format: string | undefined,
    @Res() res: Response,
  ): Promise<void> {
    const s = await this.statements.mine(user.id, id);
    const csv = format === 'csv';
    const data = csv
      ? Buffer.from(renderStatementCsv(s), 'utf8')
      : await renderStatementPdf(s);
    res
      .status(200)
      .set({
        'Content-Type': csv ? 'text/csv; charset=utf-8' : 'application/pdf',
        'Content-Disposition': `attachment; filename="pay-and-save-${s.verificationCode}.${csv ? 'csv' : 'pdf'}"`,
        'Content-Length': String(data.length),
        'Cache-Control': 'private, no-store',
      })
      .end(data);
  }
}

/** Public by design: a lender checks a code without an account. */
@Controller()
export class StatementVerifyController {
  constructor(private readonly statements: StatementsService) {}

  @Get('statements/verify/:code')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  verify(@Param('code') code: string) {
    return this.statements.verify(code.slice(0, 40));
  }

  @Get('verify/:code')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  async page(@Param('code') raw: string): Promise<string> {
    const code = raw.slice(0, 40);
    return renderVerifyPage(code, await this.statements.verify(code));
  }
}
