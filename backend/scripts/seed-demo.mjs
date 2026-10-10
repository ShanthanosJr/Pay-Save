// Creates demo accounts and one running circle on a LOCAL development API.
//   node scripts/seed-demo.mjs            (API on http://localhost:3000, DEV_OTP_ECHO=true)
// Safe to re-run: existing accounts are signed in instead of re-created.
// Never run against production: these passwords are public.
import { randomUUID } from 'node:crypto';

const API = process.env.API_BASE_URL ?? 'http://localhost:3000';
if (!/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(API)) {
  console.error('seed-demo only runs against a local API');
  process.exit(1);
}

export const PASSWORD = 'Demo12345';
export const ACCOUNTS = [
  { key: 'organizer', fullName: 'Kamala Perera', phone: '0719900001', email: 'kamala@demo.payandsave.test', nic: '905550001V', age: 41 },
  { key: 'member1', fullName: 'Nadeeshi Silva', phone: '0719900002', email: 'nadeeshi@demo.payandsave.test', nic: '905550002V', age: 29 },
  { key: 'member2', fullName: 'Ruwan Fernando', phone: '0719900003', email: 'ruwan@demo.payandsave.test', nic: '905550003V', age: 35 },
  { key: 'member3', fullName: 'Tharshini Rajan', phone: '0719900004', email: 'tharshini@demo.payandsave.test', nic: '905550004V', age: 33 },
  { key: 'officer', fullName: 'Sunil Jayasinghe', phone: '0719900005', email: 'sunil@demo.payandsave.test', nic: '905550005V', age: 52 },
];

async function call(method, path, { token, body, ok = [200, 201, 204] } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!ok.includes(res.status)) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return { status: res.status, data };
}

async function signIn(a) {
  const otp = await call('POST', '/auth/otp/request', { body: { phone: a.phone }, ok: [200, 409] });
  if (otp.status === 409) {
    const { data } = await call('POST', '/auth/login', { body: { identifier: a.email, password: PASSWORD } });
    return { id: data.user.id, token: data.accessToken, created: false };
  }
  if (!otp.data.devCode) throw new Error('Set DEV_OTP_ECHO=true in backend/.env to seed demo accounts');
  const v = await call('POST', '/auth/otp/verify', { body: { phone: a.phone, code: otp.data.devCode } });
  const { data } = await call('POST', '/auth/register', {
    body: {
      fullName: a.fullName,
      age: a.age,
      nic: a.nic,
      phone: a.phone,
      email: a.email,
      password: PASSWORD,
      phoneVerificationToken: v.data.phoneVerificationToken,
    },
  });
  return { id: data.user.id, token: data.accessToken, created: true };
}

const users = {};
for (const a of ACCOUNTS) {
  users[a.key] = { ...a, ...(await signIn(a)) };
  console.log(`${users[a.key].created ? 'created' : 'exists '}  ${a.fullName}`);
}

const [org, ...members] = ['organizer', 'member1', 'member2', 'member3'].map((k) => users[k]);

for (const u of [org, ...members]) {
  const { data } = await call('GET', '/users/me/payout-methods', { token: u.token });
  if (data.methods.length === 0)
    await call('POST', '/users/me/payout-methods', { token: u.token, body: { kind: 'cash', note: 'Hand it to me in person' } });
}

// everyone is a pal of everyone, so any of them can organise a circle
const people = [org, ...members];
for (let i = 0; i < people.length; i++)
  for (let j = i + 1; j < people.length; j++) {
    await call('PUT', `/people/${people[j].id}/pal`, { token: people[i].token, ok: [200, 201, 409] });
    await call('POST', `/people/${people[i].id}/pal/accept`, { token: people[j].token, ok: [200, 201, 404, 409] });
  }

const mine = await call('GET', '/circles', { token: org.token });
if (mine.data.circles.some((c) => c.name === 'Friends Seettu')) {
  console.log('exists   Friends Seettu');
} else {
  const due = new Date(Date.now() + 5 * 86_400_000).toISOString().slice(0, 10);
  const { data: circle } = await call('POST', '/circles', {
    token: org.token,
    body: {
      name: 'Friends Seettu',
      contributionMinor: 500_000,
      interval: 'monthly',
      turnRule: 'fixed',
      plannedCycles: 4,
      firstDueDate: due,
      collectionMode: 'via_organizer',
    },
  });
  for (const m of members) await call('POST', '/circles/join', { token: m.token, body: { code: circle.joinCode } });
  await call('POST', `/circles/${circle.id}/start`, { token: org.token, body: { order: people.map((p) => p.id) } });
  // one verified payment and one waiting, so every screen has something to show
  const record = (u) =>
    call('POST', `/circles/${circle.id}/contributions`, {
      token: u.token,
      body: { cycleNumber: 1, method: 'bank_transfer', receiptReference: 'DEMO-REF', clientEntryId: randomUUID() },
    });
  const first = await record(members[0]);
  await call('POST', `/circles/${circle.id}/contributions/${first.data.entry.id}/verify`, { token: org.token });
  await record(members[1]);
  console.log('created  Friends Seettu (4 members, cycle 1 open)');
}

console.log(`\nLog in with any email in ACCOUNTS (top of this file) and the PASSWORD constant.`);
console.log(`Officer role (run once):\n  UPDATE users SET is_community_officer = true WHERE email = '${users.officer.email}';`);
