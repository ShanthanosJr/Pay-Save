import { Logger } from '@nestjs/common';
import { createTransport } from 'nodemailer';
import type { Transporter } from 'nodemailer';
import type { AppConfig } from '../config/app-config';
import { DeliveryError, EmailMessage, EmailTransport } from './messaging.types';

/** Development only: prints the message instead of sending it. */
export class ConsoleEmailTransport implements EmailTransport {
  private readonly logger = new Logger('Email');

  send({ to, subject, text }: EmailMessage): Promise<void> {
    const at = to.indexOf('@');
    this.logger.log(
      `[EMAIL] ${to.slice(0, 1)}***${to.slice(at)} ${subject} | ${text}`,
    );
    return Promise.resolve();
  }
}

/** Any SMTP relay: Amazon SES, Brevo, Mailgun, Gmail with an app password. */
export class SmtpEmailTransport implements EmailTransport {
  private readonly transporter: Transporter;

  constructor(private readonly cfg: AppConfig['email']) {
    this.transporter = createTransport({
      host: cfg.smtpHost,
      port: cfg.smtpPort,
      secure: cfg.smtpSecure,
      requireTLS: !cfg.smtpSecure,
      auth: cfg.smtpUser
        ? { user: cfg.smtpUser, pass: cfg.smtpPass }
        : undefined,
      connectionTimeout: 10_000,
      socketTimeout: 15_000,
    });
  }

  async send({ to, subject, text }: EmailMessage): Promise<void> {
    try {
      await this.transporter.sendMail({
        from: this.cfg.from,
        to,
        subject,
        text,
      });
    } catch (err) {
      throw new DeliveryError(
        'email',
        (err as { code?: string }).code ?? (err as Error).name,
      );
    }
  }
}

export function createEmailTransport(cfg: AppConfig['email']): EmailTransport {
  return cfg.provider === 'smtp'
    ? new SmtpEmailTransport(cfg)
    : new ConsoleEmailTransport();
}
