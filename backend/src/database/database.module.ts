import {
  Global,
  Inject,
  Logger,
  Module,
  OnModuleDestroy,
} from '@nestjs/common';
import { Pool } from 'pg';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';

export const PG_POOL = Symbol('PG_POOL');

@Global()
@Module({
  providers: [
    {
      provide: PG_POOL,
      inject: [APP_CONFIG],
      useFactory: (cfg: AppConfig) => {
        const pool = new Pool({ connectionString: cfg.databaseUrl, max: 10 });
        pool.on('error', (err) => new Logger('Database').error(err.message));
        return pool;
      },
    },
  ],
  exports: [PG_POOL],
})
export class DatabaseModule implements OnModuleDestroy {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
