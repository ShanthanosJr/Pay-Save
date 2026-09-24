import { AppException } from '../errors/app.exception';

function validDayCode(day: number): boolean {
  return (day >= 1 && day <= 366) || (day >= 501 && day <= 866);
}

export function normalizeNic(input: string): string {
  const nic = input.trim().toUpperCase();
  let ok = false;
  if (/^\d{9}[VX]$/.test(nic)) ok = validDayCode(Number(nic.slice(2, 5)));
  else if (/^\d{12}$/.test(nic))
    ok =
      Number(nic.slice(0, 4)) >= 1900 && validDayCode(Number(nic.slice(4, 7)));
  if (!ok) throw new AppException(400, 'INVALID_NIC', 'Invalid NIC number');
  return nic;
}

export function maskNic(nic: string): string {
  return `${'*'.repeat(Math.max(0, nic.length - 3))}${nic.slice(-3)}`;
}
