import PDFDocument from 'pdfkit';
import { formatLkr } from '../reminders/reminder-templates';
import type { PublicVerification, Statement } from './statements.service';

const METHOD: Record<string, string> = {
  cash: 'Cash',
  bank_transfer: 'Bank transfer',
  lankaqr: 'LANKAQR',
  mobile_wallet: 'Mobile wallet',
};

const day = (iso: string) => iso.slice(0, 10);

/** The standard PDF fonts cover Latin-1 only. */
const latin = (s: string) => s.replace(/[^\x20-\x7e\xa0-\xff]/g, '?');

export function renderStatementPdf(s: Statement): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margin: 50,
      info: { Title: `Pay&Save statement ${s.verificationCode}` },
    });
    const chunks: Buffer[] = [];
    doc.on('data', (c: Buffer) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const green = '#1F5A45';
    doc.fillColor(green).font('Helvetica-Bold').fontSize(20).text('Pay&Save');
    doc
      .fillColor('#000')
      .fontSize(14)
      .text('Verified savings statement', { paragraphGap: 10 });
    doc.font('Helvetica').fontSize(10);
    const field = (label: string, value: string) => {
      doc.font('Helvetica-Bold').text(`${label}: `, { continued: true });
      doc.font('Helvetica').text(latin(value));
    };
    field('Member', s.holderName);
    field('Circle', `${s.circle.name} (${s.circle.publicCode})`);
    field('Issued', `${s.issuedAt.replace('T', ' ').slice(0, 16)} UTC`);
    field('Verification code', s.verificationCode);
    doc.moveDown();

    doc.font('Helvetica-Bold').fontSize(11).text('Verified contributions');
    doc.moveDown(0.4);
    const cols = [50, 100, 185, 285, 385, 470];
    const row = (cells: string[], bold = false) => {
      const y = doc.y;
      doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(9);
      cells.forEach((c, i) =>
        doc.text(latin(c), cols[i], y, {
          width: cols[i + 1] ? cols[i + 1] - cols[i] - 6 : 80,
        }),
      );
      doc.x = 50;
      doc.moveDown(0.35);
      if (doc.y > 760) doc.addPage();
    };
    row(
      ['Cycle', 'Reference', 'Paid by', 'Recorded', 'Verified', 'Amount'],
      true,
    );
    for (const l of s.lines)
      row([
        String(l.cycleNumber),
        l.reference,
        METHOD[l.method ?? ''] ?? '-',
        day(l.recordedAt),
        day(l.verifiedAt),
        formatLkr(l.amountMinor),
      ]);
    doc.moveDown(0.6);
    const c = s.contributions;
    doc
      .font('Helvetica-Bold')
      .fontSize(11)
      .text(
        `${c.count} verified x ${formatLkr(c.unitMinor)} = ${formatLkr(c.totalMinor)}`,
        50,
      );
    doc.moveDown();

    if (s.payoutsReceived.length > 0) {
      doc.font('Helvetica-Bold').fontSize(11).text('Payouts received');
      doc.font('Helvetica').fontSize(9);
      for (const p of s.payoutsReceived)
        doc.text(
          `Cycle ${p.cycleNumber} - ${p.reference} - ${formatLkr(p.amountMinor)}`,
        );
      doc.moveDown();
    }

    doc.font('Helvetica-Bold').fontSize(11).text('How to check this statement');
    doc
      .font('Helvetica')
      .fontSize(9)
      .text(
        'Pay&Save records payments that members made to each other; it does not hold or move money. ' +
          'Every record is append-only and linked to the one before it by a SHA-256 hash, so a changed record is detectable. ' +
          'Only contributions verified by the circle organizer are listed. ' +
          'To confirm this statement is genuine and unaltered, open the address below or enter the verification code there.',
        { paragraphGap: 6 },
      );
    doc
      .fillColor(green)
      .text(s.verifyUrl, { link: s.verifyUrl, underline: true });
    doc.fillColor('#000').moveDown(0.5);
    doc
      .font('Helvetica-Bold')
      .text('Ledger fingerprint at issue: ', { continued: true });
    doc.font('Courier').fontSize(8).text(s.chainHeadHash);
    doc.end();
  });
}

const csvCell = (v: string | number) => {
  const s = String(v);
  // never let a spreadsheet treat a cell as a formula
  const safe = /^[=+\-@\t\r]/.test(s) ? `'${s}` : s;
  return /[",\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
};

export function renderStatementCsv(s: Statement): string {
  const rows: (string | number)[][] = [
    [
      'cycle',
      'reference',
      'method',
      'recorded_at',
      'verified_at',
      'amount_minor',
    ],
    ...s.lines.map((l) => [
      l.cycleNumber,
      l.reference,
      l.method ?? '',
      l.recordedAt,
      l.verifiedAt,
      l.amountMinor,
    ]),
    [],
    [
      'verified_count',
      'unit_minor',
      'total_minor',
      'verification_code',
      'chain_head_hash',
    ],
    [
      s.contributions.count,
      s.contributions.unitMinor,
      s.contributions.totalMinor,
      s.verificationCode,
      s.chainHeadHash,
    ],
  ];
  return rows.map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n';
}

const esc = (s: string) =>
  s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function renderVerifyPage(code: string, v: PublicVerification): string {
  const ok = v.valid && v.ledgerIntact;
  const c = v.contributions;
  const body = !v.valid
    ? `<h1 class="bad">Not a Pay&amp;Save statement</h1><p>No statement was issued with the code <b>${esc(code)}</b>. Check the code on the document.</p>`
    : `<h1 class="${ok ? 'ok' : 'bad'}">${ok ? 'Genuine statement' : 'Record changed since this statement'}</h1>
       <p>${ok ? 'This statement was issued by Pay&amp;Save and the record behind it is unaltered.' : 'The statement was issued by Pay&amp;Save, but the ledger it was taken from no longer matches. Do not rely on it.'}</p>
       <dl>
         <dt>Member</dt><dd>${esc(v.holderInitials ?? '')}</dd>
         <dt>Circle</dt><dd>${esc(v.circleCode ?? '')}</dd>
         <dt>Issued</dt><dd>${esc((v.issuedAt ?? '').replace('T', ' ').slice(0, 16))} UTC</dd>
         <dt>Verified contributions</dt><dd>${c ? `${c.count} &times; ${esc(formatLkr(c.unitMinor))} = <b>${esc(formatLkr(c.totalMinor))}</b>` : ''}</dd>
         <dt>Ledger fingerprint</dt><dd class="mono">${esc(v.chainHeadHash ?? '')}</dd>
       </dl>
       <p class="note">Compare these figures with the document you were given. Pay&amp;Save records payments members made to each other; it does not hold money.</p>`;
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>Pay&amp;Save statement check</title>
<style>body{font:16px/1.5 system-ui,sans-serif;margin:0;background:#F4F7F5;color:#14251E}
main{max-width:560px;margin:0 auto;padding:32px 20px}.card{background:#fff;border-radius:16px;padding:24px;border:1px solid #DCE5E0}
h1{font-size:22px;margin:0 0 8px}.ok{color:#1F5A45}.bad{color:#A32D2D}dt{font-size:13px;color:#5C6F66;margin-top:14px}
dd{margin:0}.mono{font:12px ui-monospace,monospace;word-break:break-all}.note{font-size:13px;color:#5C6F66;margin-top:20px}
.brand{font-weight:700;color:#1F5A45;margin-bottom:16px}</style></head>
<body><main><div class="brand">Pay&amp;Save</div><div class="card">${body}</div></main></body></html>`;
}
