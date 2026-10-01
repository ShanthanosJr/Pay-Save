import { randomBytes } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Client } from 'pg';

export interface TestDatabase {
  url: string;
  drop(): Promise<void>;
}

async function run(url: string, sql: string): Promise<void> {
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    await client.query(sql);
  } finally {
    await client.end();
  }
}

/** Creates a throwaway database next to `baseUrl` with every migration applied. */
export async function createTestDatabase(
  baseUrl: string,
): Promise<TestDatabase> {
  const name = `payandsave_e2e_${randomBytes(6).toString('hex')}`;
  await run(baseUrl, `CREATE DATABASE ${name}`);
  const url = new URL(baseUrl);
  url.pathname = `/${name}`;
  const dir = join(__dirname, '..', '..', 'db', 'migrations');
  const files = readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  for (const f of files) {
    await run(url.toString(), readFileSync(join(dir, f), 'utf8'));
  }
  return {
    url: url.toString(),
    drop: () => run(baseUrl, `DROP DATABASE IF EXISTS ${name} WITH (FORCE)`),
  };
}
