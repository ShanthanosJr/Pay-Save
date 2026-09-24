import { Global, Module } from '@nestjs/common';
import { CLOCK, SystemClock } from './clock/clock';
import { CryptoService } from './crypto/crypto.service';

@Global()
@Module({
  providers: [CryptoService, { provide: CLOCK, useClass: SystemClock }],
  exports: [CryptoService, CLOCK],
})
export class CommonModule {}
