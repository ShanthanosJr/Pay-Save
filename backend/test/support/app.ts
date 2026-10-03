import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/app.setup';
import { OTP_SENDER, OtpPurpose, OtpSender } from '../../src/otp/otp-sender';

export class RecordingSender implements OtpSender {
  sent: { purpose: OtpPurpose; target: string; code: string }[] = [];
  send(m: { purpose: OtpPurpose; target: string; code: string }) {
    this.sent.push(m);
    return Promise.resolve();
  }
  last(purpose: OtpPurpose): string {
    const m = [...this.sent].reverse().find((s) => s.purpose === purpose);
    if (!m) throw new Error(`no ${purpose} otp sent`);
    return m.code;
  }
}

export async function createTestApp() {
  const sender = new RecordingSender();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(OTP_SENDER)
    .useValue(sender)
    .compile();
  const app = moduleRef.createNestApplication<INestApplication<App>>();
  configureApp(app);
  await app.init();
  return { app, sender };
}

export interface TestUser {
  id: string;
  token: string;
  auth: { Authorization: string };
}

/** Verifies `phone` by OTP and returns the phone verification token. */
export async function verifyPhone(
  app: INestApplication<App>,
  sender: RecordingSender,
  phone: string,
): Promise<string> {
  await request(app.getHttpServer())
    .post('/auth/otp/request')
    .send({ phone })
    .expect(200);
  const res = await request(app.getHttpServer())
    .post('/auth/otp/verify')
    .send({ phone, code: sender.last('phone_register') })
    .expect(200);
  return (res.body as { phoneVerificationToken: string })
    .phoneVerificationToken;
}

export async function registerUser(
  app: INestApplication<App>,
  sender: RecordingSender,
  n: number,
  fullName: string,
): Promise<TestUser> {
  const suffix = String(n).padStart(2, '0');
  const phone = `07711000${suffix}`;
  const token = await verifyPhone(app, sender, phone);
  const res = await request(app.getHttpServer())
    .post('/auth/register')
    .send({
      fullName,
      age: 30 + n,
      nic: `9012300${suffix}V`,
      phone,
      email: `user${suffix}@social.e2e.test`,
      password: 'Passw0rdTest',
      phoneVerificationToken: token,
    })
    .expect(201);
  const body = res.body as { accessToken: string; user: { id: string } };
  return {
    id: body.user.id,
    token: body.accessToken,
    auth: { Authorization: `Bearer ${body.accessToken}` },
  };
}
