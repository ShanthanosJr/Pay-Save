import type { Language } from '../users/users.repository';

export interface ReminderText {
  circle: string;
  cycle: number;
  /** Already formatted, e.g. "LKR 5,000.00". */
  amount: string;
  dueDate: string;
  daysLeft: number;
}

/** Whole rupees and cents from minor units, without floating point. */
export function formatLkr(minor: number): string {
  const whole = Math.trunc(minor / 100);
  const cents = String(Math.abs(minor % 100)).padStart(2, '0');
  return `LKR ${whole.toLocaleString('en-LK')}.${cents}`;
}

const DUE: Record<Language, (t: ReminderText) => string> = {
  en: (t) =>
    t.daysLeft === 0
      ? `Pay&Save: ${t.circle} cycle ${t.cycle} is due today (${t.amount}). Record it in the app after you pay.`
      : `Pay&Save: ${t.circle} cycle ${t.cycle} is due on ${t.dueDate}, in ${t.daysLeft} day(s) (${t.amount}).`,
  si: (t) =>
    t.daysLeft === 0
      ? `Pay&Save: ${t.circle} ${t.cycle} වන වටය අද ගෙවිය යුතුයි (${t.amount}). ගෙවූ පසු යෙදුමේ සටහන් කරන්න.`
      : `Pay&Save: ${t.circle} ${t.cycle} වන වටය ${t.dueDate} දින ගෙවිය යුතුයි, තව දින ${t.daysLeft}යි (${t.amount}).`,
  ta: (t) =>
    t.daysLeft === 0
      ? `Pay&Save: ${t.circle} சுற்று ${t.cycle} இன்று செலுத்த வேண்டும் (${t.amount}). செலுத்திய பின் செயலியில் பதிவு செய்யவும்.`
      : `Pay&Save: ${t.circle} சுற்று ${t.cycle} ${t.dueDate} அன்று செலுத்த வேண்டும், இன்னும் ${t.daysLeft} நாள் (${t.amount}).`,
};

const OVERDUE: Record<Language, (t: ReminderText) => string> = {
  en: (t) =>
    `Pay&Save: ${t.circle} cycle ${t.cycle} was due on ${t.dueDate} and is not recorded yet (${t.amount}).`,
  si: (t) =>
    `Pay&Save: ${t.circle} ${t.cycle} වන වටය ${t.dueDate} දින ගෙවිය යුතුව තිබුණි; තවම සටහන් වී නැත (${t.amount}).`,
  ta: (t) =>
    `Pay&Save: ${t.circle} சுற்று ${t.cycle} ${t.dueDate} அன்று செலுத்த வேண்டியது; இன்னும் பதிவாகவில்லை (${t.amount}).`,
};

const SUBJECT: Record<Language, string> = {
  en: 'Pay&Save contribution reminder',
  si: 'Pay&Save දායක මුදල් මතක් කිරීම',
  ta: 'Pay&Save பங்களிப்பு நினைவூட்டல்',
};

export const reminderText = (
  language: Language,
  t: ReminderText,
): { subject: string; text: string } => ({
  subject: SUBJECT[language],
  text: (t.daysLeft < 0 ? OVERDUE : DUE)[language](t),
});
