import { INestApplication } from '@nestjs/common';
import helmet from 'helmet';
import { APP_CONFIG } from './config/app-config';
import type { AppConfig } from './config/app-config';

export function configureApp(app: INestApplication): void {
  const cfg = app.get<AppConfig>(APP_CONFIG);
  app.use(helmet());
  if (cfg.corsOrigins === '*' || cfg.corsOrigins.length > 0) {
    app.enableCors({ origin: cfg.corsOrigins });
  }
}
