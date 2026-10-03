import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return sourceFiles(p);
    return p.endsWith('.ts') && !p.endsWith('.spec.ts') ? [p] : [];
  });
}

describe('ledger rules (AGENTS 2 and 3)', () => {
  const root = join(__dirname, '..');
  const files = sourceFiles(root).map((p) => ({
    path: relative(root, p),
    text: readFileSync(p, 'utf8'),
  }));

  it('only LedgerService inserts ledger rows', () => {
    const writers = files
      .filter((f) => /INSERT\s+INTO\s+ledger_entries/i.test(f.text))
      .map((f) => f.path);
    expect(writers).toEqual([join('ledger', 'ledger.service.ts')]);
  });

  it('no code updates or deletes ledger rows', () => {
    const offenders = files
      .filter((f) =>
        /(UPDATE\s+ledger_entries|DELETE\s+FROM\s+ledger_entries|TRUNCATE\s+ledger_entries)/i.test(
          f.text,
        ),
      )
      .map((f) => f.path);
    expect(offenders).toEqual([]);
  });
});
