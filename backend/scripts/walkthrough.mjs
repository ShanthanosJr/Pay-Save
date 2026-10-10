// End-to-end walkthrough on a LOCAL development API: four new people, one
// lottery seettu followed from invitation to the last payout, and every
// feature around it. Each step checks what the server answered.
//   node scripts/walkthrough.mjs        (API on :3000 with DEV_OTP_ECHO=true)
import { createHash, randomUUID } from 'node:crypto';

const API = process.env.API_BASE_URL ?? 'http://localhost:3000';
if (!/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(API)) throw new Error('local API only');
const PASSWORD = 'Walk12345';
const run = String(Date.now()).slice(-6);
let passed = 0;
const failures = [];

async function call(method, path, { token, body, form, raw } = {}) {
  let res;
  for (let attempt = 0; ; attempt++) {
    res = await fetch(`${API}${path}`, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: form ?? (body ? JSON.stringify(body) : undefined),
    });
    // The API allows five code or login requests a minute; wait it out.
    if (res.status !== 429 || attempt === 5 || form) break;
    const peek = await res.clone().text();
    if (!peek.includes('ThrottlerException')) break;
    process.stdout.write('      (rate limit reached, waiting 15s)\n');
    await new Promise((r) => setTimeout(r, 15_000));
  }
  if (raw) return { status: res.status, bytes: Buffer.from(await res.arrayBuffer()), type: res.headers.get('content-type') };
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: res.status, data };
}
const expectStatus = (r, ...ok) => {
  if (!ok.includes(r.status)) throw new Error(`expected ${ok.join('/')}, got ${r.status} ${JSON.stringify(r.data)?.slice(0, 160)}`);
  return r.data;
};
const eq = (a, b, what) => {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${what}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
};
async function step(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok  ${name}`);
  } catch (e) {
    failures.push(name);
    console.log(`FAIL  ${name}\n      ${e.message}`);
  }
}

const people = [
  { key: 'org', fullName: 'Walk Organizer', n: 1 },
  { key: 'a', fullName: 'Walk Amaya', n: 2 },
  { key: 'b', fullName: 'Walk Bimal', n: 3 },
  { key: 'c', fullName: 'Walk Chathu', n: 4 },
].map((p) => ({ ...p, phone: `0718${run}`.slice(0, 9) + p.n, email: `walk${run}${p.n}@walk.payandsave.test`, nic: `90${String(100 + p.n)}${run.slice(0, 4)}V` }));
const U = {};

console.log('\n1. Accounts');
for (const p of people)
  await step(`register ${p.fullName} with a phone code`, async () => {
    const otp = expectStatus(await call('POST', '/auth/otp/request', { body: { phone: p.phone, language: 'en' } }), 200);
    if (!otp.devCode) throw new Error('DEV_OTP_ECHO must be true');
    if (p.n === 1)
      expectStatus(await call('POST', '/auth/otp/verify', { body: { phone: p.phone, code: '000000' === otp.devCode ? '111111' : '000000' } }), 400);
    const v = expectStatus(await call('POST', '/auth/otp/verify', { body: { phone: p.phone, code: otp.devCode } }), 200);
    const reg = expectStatus(await call('POST', '/auth/register', { body: { fullName: p.fullName, age: 30 + p.n, nic: p.nic, phone: p.phone, email: p.email, password: PASSWORD, phoneVerificationToken: v.phoneVerificationToken } }), 201);
    if (reg.user.phoneMasked.includes(p.phone.slice(3, 8))) throw new Error('phone is not masked');
    U[p.key] = { ...p, id: reg.user.id, token: reg.accessToken, refresh: reg.refreshToken };
  });
if (failures.length) {
  console.log('\nCould not create the accounts; stopping.');
  process.exit(1);
}
const { org, a, b, c } = U;
const all = [org, a, b, c];

await step('wrong password is refused, right one logs in', async () => {
  expectStatus(await call('POST', '/auth/login', { body: { identifier: a.email, password: 'Nope12345' } }), 401);
  const ok = expectStatus(await call('POST', '/auth/login', { body: { identifier: a.phone, password: PASSWORD } }), 200);
  a.token = ok.accessToken;
});
await step('email is verified with an emailed code', async () => {
  const otp = expectStatus(await call('POST', '/users/me/email/otp', { token: a.token }), 200);
  expectStatus(await call('POST', '/users/me/email/verify', { token: a.token, body: { code: otp.devCode } }), 200);
  eq(expectStatus(await call('GET', '/users/me', { token: a.token }), 200).emailVerified, true, 'emailVerified');
});
await step('profile edit, language and change password', async () => {
  const me = expectStatus(await call('PATCH', '/users/me', { token: b.token, body: { username: `walk.b${run}`, city: 'Kandy', bio: 'Saving for a scooter', language: 'si' } }), 200);
  eq([me.city, me.language], ['Kandy', 'si'], 'profile');
  expectStatus(await call('POST', '/users/me/password', { token: b.token, body: { currentPassword: 'wrong', newPassword: 'Other12345' } }), 400);
  const t = expectStatus(await call('POST', '/users/me/password', { token: b.token, body: { currentPassword: PASSWORD, newPassword: 'Other12345' } }), 200);
  b.token = t.accessToken;
});
await step('forgot password: code, reset, old password dead', async () => {
  const f = expectStatus(await call('POST', '/auth/password/forgot', { body: { identifier: c.email } }), 200);
  expectStatus(await call('POST', '/auth/password/reset', { body: { identifier: c.email, code: f.devCode, newPassword: 'Reset12345' } }), 204);
  expectStatus(await call('POST', '/auth/login', { body: { identifier: c.email, password: PASSWORD } }), 401);
  c.token = expectStatus(await call('POST', '/auth/login', { body: { identifier: c.email, password: 'Reset12345' } }), 200).accessToken;
});
await step('everyone adds how they get paid (stored encrypted, shown masked)', async () => {
  const m = expectStatus(await call('POST', '/users/me/payout-methods', { token: org.token, body: { kind: 'bank_transfer', bankName: 'Bank of Ceylon', branch: 'Kandy', accountName: 'Walk Organizer', accountNumber: '0071 2345 6789' } }), 201);
  if (!/••••6789/.test(m.methods[0].summary)) throw new Error(`not masked: ${m.methods[0].summary}`);
  for (const u of [a, b, c]) expectStatus(await call('POST', '/users/me/payout-methods', { token: u.token, body: { kind: 'cash', note: 'In person' } }), 201);
});

console.log('\n2. Pals and chat');
await step('search finds people without private fields; pal requests accepted', async () => {
  const found = expectStatus(await call('GET', `/people/search?q=Walk%20Amaya`, { token: org.token }), 200);
  const hit = found.find((p) => p.id === a.id);
  if (!hit) throw new Error('not found');
  for (const k of ['phone', 'email', 'nic', 'age']) if (k in hit) throw new Error(`search leaked ${k}`);
  for (const u of [a, b, c]) {
    expectStatus(await call('PUT', `/people/${u.id}/pal`, { token: org.token }), 200, 201);
    expectStatus(await call('POST', `/people/${org.id}/pal/accept`, { token: u.token }), 200, 201);
  }
});
let chatId;
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(256, 7)]);
const MP4 = Buffer.concat([Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftypmp42'), Buffer.alloc(512, 3)]);
await step('chat: text with emoji, a retry is not duplicated, unread count', async () => {
  chatId = expectStatus(await call('POST', '/chats', { token: org.token, body: { userId: a.id } }), 200).id;
  const id = randomUUID();
  const body = { clientMessageId: id, body: 'Welcome to the seettu 🎉🙏' };
  const first = expectStatus(await call('POST', `/chats/${chatId}/messages`, { token: org.token, body }), 201);
  const again = expectStatus(await call('POST', `/chats/${chatId}/messages`, { token: org.token, body }), 201);
  eq(again.id, first.id, 'same message');
  eq(first.body, 'Welcome to the seettu 🎉🙏', 'emoji survive');
  eq(expectStatus(await call('GET', '/chats/unread', { token: a.token }), 200).count, 1, 'unread');
});
let photoMsg;
await step('chat: photo and video are sent and fetched back byte for byte', async () => {
  const form = new FormData();
  form.set('clientMessageId', randomUUID());
  form.set('caption', 'Bank slip');
  form.set('file', new Blob([PNG]), 'slip.png');
  photoMsg = expectStatus(await call('POST', `/chats/${chatId}/media`, { token: a.token, form }), 201);
  eq([photoMsg.kind, photoMsg.media.contentType], ['image', 'image/png'], 'photo');
  const got = await call('GET', photoMsg.media.url, { token: org.token, raw: true });
  if (got.status !== 200 || Buffer.compare(got.bytes, PNG) !== 0) throw new Error('photo bytes differ');
  eq((await call('GET', photoMsg.media.url, { token: b.token, raw: true })).status, 404, 'outsider');
  const vf = new FormData();
  vf.set('clientMessageId', randomUUID());
  vf.set('file', new Blob([MP4]), 'clip.mp4');
  eq(expectStatus(await call('POST', `/chats/${chatId}/media`, { token: org.token, form: vf }), 201).kind, 'video', 'video');
});
await step('chat: react, star, pin, favourite, delete message, delete chat', async () => {
  const r = expectStatus(await call('PUT', `/chats/${chatId}/messages/${photoMsg.id}/reaction`, { token: org.token, body: { emoji: '👍' } }), 200);
  eq(r.reactions, [{ emoji: '👍', count: 1, mine: true }], 'reaction');
  eq(expectStatus(await call('PUT', `/chats/${chatId}/messages/${photoMsg.id}/star`, { token: org.token, body: { starred: true } }), 200).starred, true, 'star');
  expectStatus(await call('PATCH', `/chats/${chatId}`, { token: org.token, body: { pinned: true, favourite: true } }), 204);
  const inbox = expectStatus(await call('GET', '/chats', { token: org.token }), 200);
  eq([inbox[0].pinned, inbox[0].favourite], [true, true], 'flags');
  expectStatus(await call('DELETE', `/chats/${chatId}/messages/${photoMsg.id}`, { token: org.token }), 404); // not the sender
  expectStatus(await call('DELETE', `/chats/${chatId}/messages/${photoMsg.id}`, { token: a.token }), 204);
  eq((await call('GET', photoMsg.media.url, { token: org.token, raw: true })).status, 404, 'deleted photo');
  expectStatus(await call('DELETE', `/chats/${chatId}`, { token: a.token }), 204);
  eq(expectStatus(await call('GET', '/chats', { token: a.token }), 200).length, 0, 'cleared for me');
  eq(expectStatus(await call('GET', '/chats', { token: org.token }), 200).length, 1, 'kept for them');
});

console.log('\n3. Circle setup (lottery)');
let circle;
const detail = async (u) => expectStatus(await call('GET', `/circles/${circle.id}`, { token: u.token }), 200);
await step('create a 4-member monthly circle at LKR 5,000', async () => {
  expectStatus(await call('POST', '/circles', { token: org.token, body: { name: 'x', contributionMinor: 0, interval: 'daily', turnRule: 'fixed', plannedCycles: 1, firstDueDate: 'soon' } }), 400);
  const due = new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10);
  circle = expectStatus(await call('POST', '/circles', { token: org.token, body: { name: `Walk Seettu ${run}`, contributionMinor: 500_000, interval: 'monthly', turnRule: 'lottery', plannedCycles: 4, firstDueDate: due, collectionMode: 'direct_to_recipient' } }), 201);
  eq([circle.status, circle.role, circle.joinCode.length], ['draft', 'organizer', 8], 'draft');
});
await step('invite two pals; the invitation shows 3 x 5,000 = 15,000; one accepts, one declines then joins by code', async () => {
  expectStatus(await call('POST', `/circles/${circle.id}/invitations`, { token: org.token, body: { userIds: [a.id, b.id], message: 'Join us' } }), 201);
  const inv = expectStatus(await call('GET', '/circle-invitations', { token: a.token }), 200).invitations[0];
  eq(inv.circle.payout, { count: 3, unitMinor: 500_000, totalMinor: 1_500_000, entryIds: [] }, 'pot arithmetic');
  expectStatus(await call('POST', `/circle-invitations/${inv.id}/accept`, { token: a.token, body: {} }), 200);
  const invB = expectStatus(await call('GET', '/circle-invitations', { token: b.token }), 200).invitations[0];
  expectStatus(await call('POST', `/circle-invitations/${invB.id}/decline`, { token: b.token }), 204);
  expectStatus(await call('POST', '/circles/join', { token: b.token, body: { code: circle.joinCode.toLowerCase().replace(/(.{4})/, '$1-') } }), 200);
  expectStatus(await call('POST', '/circles/join', { token: c.token, body: { code: circle.joinCode } }), 200);
  expectStatus(await call('POST', '/circles/join', { token: c.token, body: { code: circle.joinCode } }), 409);
});
await step('a member leaves the draft and comes back', async () => {
  expectStatus(await call('POST', `/circles/${circle.id}/leave`, { token: c.token }), 204);
  expectStatus(await call('GET', `/circles/${circle.id}`, { token: c.token }), 404);
  expectStatus(await call('POST', '/circles/join', { token: c.token, body: { code: circle.joinCode } }), 200);
});
let order;
await step('lottery: fingerprint first, seed hidden; after start the draw can be re-checked by anyone', async () => {
  expectStatus(await call('POST', `/circles/${circle.id}/start`, { token: a.token, body: {} }), 403);
  const committed = expectStatus(await call('POST', `/circles/${circle.id}/lottery/commit`, { token: org.token }), 200);
  if (!committed.lottery.commitment || committed.lottery.seed !== null) throw new Error('seed visible before the draw');
  const started = expectStatus(await call('POST', `/circles/${circle.id}/start`, { token: org.token, body: {} }), 200);
  const seed = started.lottery.seed;
  eq(createHash('sha256').update(seed).digest('hex'), committed.lottery.commitment, 'sha256(seed)');
  const mine = all.map((u) => ({ id: u.id, k: createHash('sha256').update(`${seed}:${u.id}`).digest('hex') })).sort((x, y) => (x.k < y.k ? -1 : 1)).map((x) => x.id);
  order = started.cycles.map((cy) => cy.recipientUserId);
  eq(order, mine, 'order re-derived from the seed');
  eq(started.status, 'active', 'status');
  expectStatus(await call('POST', '/circles/join', { token: a.token, body: { code: circle.joinCode } }), 409);
});
const byId = (id) => all.find((u) => u.id === id);

console.log('\n4. Four cycles, start to finish');
const pay = (u, n, extra = {}) => call('POST', `/circles/${circle.id}/contributions`, { token: u.token, body: { cycleNumber: n, method: 'bank_transfer', receiptReference: `REF-${n}`, clientEntryId: randomUUID(), ...extra } });
const verify = (id) => call('POST', `/circles/${circle.id}/contributions/${id}/verify`, { token: org.token });
const payouts = [];
for (let n = 1; n <= 4; n++) {
  const receiver = byId(order[n - 1]);
  const payers = all.filter((u) => u.id !== receiver.id);
  await step(`cycle ${n}: ${receiver.fullName} receives and owes nothing; the other three are due`, async () => {
    const d = await detail(receiver);
    eq([d.currentCycle.number, d.currentCycle.myStatus, d.currentCycle.recipient.isYou], [n, null, true], 'receiver view');
    eq(d.current.totals.membersDue, 3, 'members due');
    eq(expectStatus(await pay(receiver, n), 409).code, 'OWN_TURN', 'own turn');
    const pt = expectStatus(await call('GET', `/circles/${circle.id}/pay-to`, { token: payers[0].token }), 200);
    eq([pt.payee.id, pt.amount.totalMinor, pt.youReceive], [receiver.id, 500_000, false], 'pay-to');
  });
  if (n === 1) {
    await step('cycle 1: a dropped connection retried with the same id records once; paying twice is refused', async () => {
      const id = randomUUID();
      const first = expectStatus(await pay(payers[0], 1, { clientEntryId: id }), 201);
      const retry = expectStatus(await pay(payers[0], 1, { clientEntryId: id }), 200);
      eq(retry.entry.id, first.entry.id, 'same entry');
      eq(expectStatus(await pay(payers[0], 1), 409).code, 'ALREADY_RECORDED', 'double pay');
      expectStatus(await call('POST', `/circles/${circle.id}/contributions/${first.entry.id}/verify`, { token: payers[0].token }), payers[0].id === org.id ? 201 : 403);
      if (payers[0].id !== org.id) expectStatus(await verify(first.entry.id), 201);
    });
    await step('cycle 1: a payment is rejected with a reason, stays in the record, and is recorded again', async () => {
      const wrong = expectStatus(await pay(payers[1], 1), 201).entry;
      const corr = expectStatus(await call('POST', `/circles/${circle.id}/contributions/${wrong.id}/reject`, { token: org.token, body: { reason: 'No transfer received' } }), 201).entry;
      eq([corr.type, corr.amountMinor, corr.targetEntryId], ['correction', -500_000, wrong.id], 'correction');
      eq((await detail(payers[1])).currentCycle.myStatus, payers[1].id === receiver.id ? null : 'due', 'due again');
      const again = expectStatus(await pay(payers[1], 1), 201).entry;
      expectStatus(await verify(again.id), 201);
      const ledger = expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=mine`, { token: payers[1].token }), 200).entries;
      eq(ledger.find((e) => e.id === wrong.id).status, 'corrected', 'original kept');
    });
    await step('cycle 1: a mistaken verification is undone while the cycle is open', async () => {
      const e = expectStatus(await pay(payers[2], 1, { method: 'cash' }), 201).entry;
      expectStatus(await verify(e.id), 201);
      expectStatus(await call('POST', `/circles/${circle.id}/contributions/${e.id}/reverse`, { token: org.token, body: { reason: 'Verified the wrong person' } }), 201);
      const again = expectStatus(await pay(payers[2], 1, { method: 'cash' }), 201).entry;
      expectStatus(await verify(again.id), 201);
    });
  } else if (n === 2) {
    await step('cycle 2: reminders are off by default; turned on; the organizer nudges once a day', async () => {
      const late = payers.find((u) => u.id !== org.id);
      const prefs = expectStatus(await call('GET', `/circles/${circle.id}/reminders`, { token: late.token }), 200);
      eq([prefs.enabled, prefs.daysBefore], [false, []], 'default off');
      expectStatus(await call('PUT', `/circles/${circle.id}/reminders`, { token: late.token, body: { enabled: true, daysBefore: [], channels: [] } }), 400);
      expectStatus(await call('PUT', `/circles/${circle.id}/reminders`, { token: late.token, body: { enabled: true, daysBefore: [3, 0], channels: [] } }), 200);
      expectStatus(await call('POST', `/circles/${circle.id}/members/${late.id}/remind`, { token: org.token }), 200);
      expectStatus(await call('POST', `/circles/${circle.id}/members/${late.id}/remind`, { token: org.token }), 429);
      const box = expectStatus(await call('GET', '/notifications', { token: late.token }), 200);
      if (!box.items.some((x) => x.kind === 'organizer_nudge')) throw new Error('nudge not in inbox');
    });
    await step('cycle 2: the organizer records cash for a member; one member stays unpaid', async () => {
      const [p1, p2] = payers.filter((u) => u.id !== org.id);
      const cash = expectStatus(await call('POST', `/circles/${circle.id}/contributions`, { token: org.token, body: { cycleNumber: 2, method: 'cash', subjectUserId: p1.id, clientEntryId: randomUUID() } }), 201).entry;
      eq([cash.subjectUserId, cash.actorUserId], [p1.id, org.id], 'cash on behalf');
      expectStatus(await verify(cash.id), 201);
      expectStatus(await call('POST', `/circles/${circle.id}/contributions`, { token: p1.token, body: { cycleNumber: 2, method: 'cash', subjectUserId: p2.id, clientEntryId: randomUUID() } }), 403);
      if (payers.includes(org)) expectStatus(await verify(expectStatus(await pay(org, 2), 201).entry.id), 201);
    });
  } else {
    await step(`cycle ${n}: all three pay and are verified`, async () => {
      for (const u of payers) expectStatus(await verify(expectStatus(await pay(u, n, { method: n === 3 ? 'lankaqr' : 'mobile_wallet', provider: n === 3 ? undefined : 'Genie' }), 201).entry.id), 201);
    });
  }
  await step(`cycle ${n}: close needs the unpaid named; payout = verified count x 5,000`, async () => {
    const before = await detail(org);
    const t = before.current.totals;
    eq(t.awaiting.count, 0, 'nothing waiting');
    eq(expectStatus(await call('POST', `/circles/${circle.id}/cycles/${n}/close`, { token: org.token, body: { acknowledgeUnpaid: t.unpaid.count + 1 } }), 409).code, 'UNPAID_NOT_ACKNOWLEDGED', 'ack');
    expectStatus(await call('POST', `/circles/${circle.id}/cycles/${n}/close`, { token: a.token, body: { acknowledgeUnpaid: t.unpaid.count } }), a.id === org.id ? 200 : 403);
    const after = expectStatus(await call('POST', `/circles/${circle.id}/cycles/${n}/close`, { token: org.token, body: { acknowledgeUnpaid: t.unpaid.count } }), 200);
    eq(t.verified.totalMinor, t.verified.count * 500_000, 'arithmetic');
    payouts.push({ n, receiver: receiver.id, count: t.verified.count, total: t.verified.totalMinor, unpaid: t.unpaid.count });
    eq(after.status, n === 4 ? 'completed' : 'active', 'circle status');
    console.log(`      cycle ${n}: ${t.verified.count} verified x 5,000 = ${t.verified.totalMinor / 100}; unpaid ${t.unpaid.count}`);
  });
}
await step('expected: cycles 1, 3, 4 paid 15,000 each; cycle 2 paid 10,000 with one member unpaid', async () => {
  eq(payouts.map((p) => [p.count, p.total / 100, p.unpaid]), [[3, 15000, 0], [2, 10000, 1], [3, 15000, 0], [3, 15000, 0]], 'payouts');
});
await step('a closed cycle can no longer be changed; removing a paid-out member is refused', async () => {
  const ledger = expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=all`, { token: org.token }), 200).entries;
  const verified = ledger.find((e) => e.type === 'contribution_recorded' && e.status === 'verified');
  eq(expectStatus(await call('POST', `/circles/${circle.id}/contributions/${verified.id}/reverse`, { token: org.token, body: { reason: 'too late' } }), 409).code, 'CYCLE_CLOSED', 'closed');
  expectStatus(await call('POST', `/circles/${circle.id}/members/${a.id}/remove`, { token: org.token, body: { reason: 'test' } }), 409);
});

console.log('\n5. The record');
await step('ledger: every entry chained to the one before; members see only their own', async () => {
  const entries = expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=all`, { token: org.token }), 200).entries.slice().reverse();
  let prev = '0'.repeat(64);
  for (const e of entries) {
    if (e.prevHash !== prev) throw new Error(`chain broken at ${e.reference}`);
    prev = e.hash;
  }
  const types = new Set(entries.map((e) => e.type));
  for (const t of ['member_added', 'member_removed', 'turn_order_set', 'contribution_recorded', 'contribution_verified', 'correction', 'payout', 'cycle_closed'])
    if (!types.has(t)) throw new Error(`no ${t} entry`);
  console.log(`      ${entries.length} entries, chain intact`);
  expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=all`, { token: a.token }), 403);
  const mine = expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=mine`, { token: a.token }), 200).entries;
  if (mine.some((e) => e.subjectUserId && e.subjectUserId !== a.id && !e.targetEntryId)) throw new Error('saw someone else');
});
await step('statement: PDF, CSV and a public check that shows initials and totals only', async () => {
  const s = expectStatus(await call('POST', `/circles/${circle.id}/statements`, { token: a.token }), 201);
  eq(s.contributions.totalMinor, s.contributions.count * 500_000, 'statement arithmetic');
  const pdf = await call('GET', `/statements/${s.id}/file`, { token: a.token, raw: true });
  if (pdf.bytes.subarray(0, 5).toString() !== '%PDF-') throw new Error('not a PDF');
  eq((await call('GET', `/statements/${s.id}/file`, { token: b.token, raw: true })).status, 404, 'owner only');
  const pub = expectStatus(await call('GET', `/statements/verify/${s.verificationCode}`), 200);
  eq([pub.valid, pub.ledgerIntact, pub.holderInitials], [true, true, 'W. A.'], 'public check');
  if (JSON.stringify(pub).includes('Amaya')) throw new Error('name leaked');
  eq(expectStatus(await call('GET', '/statements/verify/PS-AAAA-BBBB-CCCC'), 200).valid, false, 'bogus code');
  console.log(`      ${s.contributions.count} verified x 5,000 = ${s.contributions.totalMinor / 100} · ${s.verificationCode}`);
});
await step('notifications: verified, rejected and cycle-closed reached the right inboxes; mark all read', async () => {
  const kinds = new Set();
  for (const u of all) for (const x of expectStatus(await call('GET', '/notifications', { token: u.token }), 200).items) kinds.add(x.kind);
  for (const k of ['circle_started', 'payment_verified', 'payment_rejected', 'cycle_closed', 'payout_due_to_you', 'circle_invitation', 'member_joined'])
    if (!kinds.has(k)) throw new Error(`no ${k} notification`);
  eq(expectStatus(await call('POST', '/notifications/read', { token: a.token, body: {} }), 200).unread, 0, 'unread');
});

console.log('\n6. Community tier');
await step('sharing needs every member; a 4-member circle is never shown to officers', async () => {
  for (const u of all) expectStatus(await call('PUT', `/circles/${circle.id}/community/consent`, { token: u.token, body: { granted: true } }), 200);
  const st = expectStatus(await call('GET', `/circles/${circle.id}/community`, { token: a.token }), 200);
  eq([st.shared, st.largeEnough, st.granted], [true, false, 4], 'consent');
  expectStatus(await call('GET', '/community/overview', { token: a.token }), 403);
});
await step('dispute: only about your own record; evidence stays closed to non-officers', async () => {
  const mine = expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=mine`, { token: b.token }), 200).entries.find((e) => e.type === 'contribution_recorded');
  const others = expectStatus(await call('GET', `/circles/${circle.id}/ledger?scope=all`, { token: org.token }), 200).entries.find((e) => e.type === 'contribution_recorded' && e.subjectUserId === a.id);
  expectStatus(await call('POST', `/circles/${circle.id}/disputes`, { token: b.token, body: { entryIds: [others.id], category: 'other' } }), 403);
  const d = expectStatus(await call('POST', `/circles/${circle.id}/disputes`, { token: b.token, body: { entryIds: [mine.id], category: 'payment_not_recorded' } }), 201);
  const done = b.id === org.id ? d : expectStatus(await call('PUT', `/circles/${circle.id}/disputes/${d.id}/consent`, { token: org.token, body: { granted: true } }), 200);
  eq(done.status, 'consented', 'consented');
  expectStatus(await call('GET', `/community/disputes/${d.id}/evidence`, { token: org.token }), 403);
});

console.log('\n7. Access');
await step('strangers and signed-out callers get nothing', async () => {
  expectStatus(await call('GET', `/circles/${circle.id}`), 401);
  expectStatus(await call('GET', '/notifications'), 401);
  expectStatus(await call('GET', `/chats/${chatId}/messages`, { token: c.token }), 404);
  expectStatus(await call('POST', '/auth/logout', { token: c.token }), 204);
});

console.log(`\n${passed} steps passed, ${failures.length} failed${failures.length ? ':\n - ' + failures.join('\n - ') : ''}`);
process.exit(failures.length ? 1 : 0);
