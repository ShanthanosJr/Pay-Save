export const INTERVALS = ['weekly', 'fortnightly', 'monthly'] as const;
export type CircleInterval = (typeof INTERVALS)[number];

export const CIRCLE_TIME_ZONE = 'Asia/Colombo';

const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

function parse(date: string): Date {
  const m = DATE_RE.exec(date);
  if (!m) throw new Error(`invalid date ${date}`);
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  if (format(d) !== date) throw new Error(`invalid date ${date}`);
  return d;
}

function format(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function isValidDate(date: string): boolean {
  try {
    parse(date);
    return true;
  } catch {
    return false;
  }
}

export function addDays(date: string, days: number): string {
  const d = parse(date);
  d.setUTCDate(d.getUTCDate() + days);
  return format(d);
}

/** Same day-of-month `months` later, clamped to that month's last day. */
export function addMonthsClamped(date: string, months: number): string {
  const d = parse(date);
  const y = d.getUTCFullYear();
  const m = d.getUTCMonth() + months;
  const lastDay = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  return format(new Date(Date.UTC(y, m, Math.min(d.getUTCDate(), lastDay))));
}

export function dueDateFor(
  firstDueDate: string,
  interval: CircleInterval,
  cycleNumber: number,
): string {
  const k = cycleNumber - 1;
  switch (interval) {
    case 'weekly':
      return addDays(firstDueDate, 7 * k);
    case 'fortnightly':
      return addDays(firstDueDate, 14 * k);
    case 'monthly':
      return addMonthsClamped(firstDueDate, k);
  }
}

/** Calendar date in Sri Lanka for an instant. */
export function localDate(instant: Date, timeZone = CIRCLE_TIME_ZONE): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instant);
}
