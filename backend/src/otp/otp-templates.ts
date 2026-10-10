import type { OtpLanguage, OtpPurpose } from './otp-sender';

const MINUTES = 5;

/** One GSM segment in English; never includes anything but the code. */
const SMS: Record<OtpLanguage, (code: string) => string> = {
  en: (c) =>
    `Pay&Save code: ${c}. Valid for ${MINUTES} minutes. Never share this code with anyone.`,
  si: (c) =>
    `Pay&Save කේතය: ${c}. මිනිත්තු ${MINUTES}ක් වලංගුයි. මෙම කේතය කිසිවෙකුට නොදෙන්න.`,
  ta: (c) =>
    `Pay&Save குறியீடு: ${c}. ${MINUTES} நிமிடங்களுக்கு செல்லுபடியாகும். இதை யாருடனும் பகிர வேண்டாம்.`,
};

const SUBJECT: Record<OtpPurpose, Record<OtpLanguage, string>> = {
  phone_register: {
    en: 'Your Pay&Save code',
    si: 'ඔබේ Pay&Save කේතය',
    ta: 'உங்கள் Pay&Save குறியீடு',
  },
  email_verify: {
    en: 'Verify your email for Pay&Save',
    si: 'Pay&Save සඳහා ඔබේ ඊමේල් තහවුරු කරන්න',
    ta: 'Pay&Save க்கான உங்கள் மின்னஞ்சலை உறுதிப்படுத்தவும்',
  },
  password_reset: {
    en: 'Reset your Pay&Save password',
    si: 'ඔබේ Pay&Save මුරපදය යළි සකසන්න',
    ta: 'உங்கள் Pay&Save கடவுச்சொல்லை மீட்டமைக்கவும்',
  },
};

const BODY: Record<OtpLanguage, (code: string) => string> = {
  en: (c) =>
    `Your Pay&Save code is ${c}.\n\nIt is valid for ${MINUTES} minutes. Never share this code with anyone; Pay&Save will never ask for it.\n\nIf you did not ask for this code, you can ignore this email.`,
  si: (c) =>
    `ඔබේ Pay&Save කේතය ${c}.\n\nමෙය මිනිත්තු ${MINUTES}ක් වලංගුයි. මෙම කේතය කිසිවෙකුට නොදෙන්න; Pay&Save කිසි විටෙක එය ඉල්ලන්නේ නැත.\n\nඔබ මෙම කේතය ඉල්ලුවේ නැත්නම්, මෙම ඊමේල් නොසලකා හරින්න.`,
  ta: (c) =>
    `உங்கள் Pay&Save குறியீடு ${c}.\n\nஇது ${MINUTES} நிமிடங்களுக்கு செல்லுபடியாகும். இதை யாருடனும் பகிர வேண்டாம்; Pay&Save ஒருபோதும் இதைக் கேட்காது.\n\nநீங்கள் இதைக் கோரவில்லை என்றால், இந்த மின்னஞ்சலைப் புறக்கணிக்கலாம்.`,
};

export const otpSms = (code: string, language: OtpLanguage = 'en'): string =>
  SMS[language](code);

export const otpEmail = (
  purpose: OtpPurpose,
  code: string,
  language: OtpLanguage = 'en',
): { subject: string; text: string } => ({
  subject: SUBJECT[purpose][language],
  text: BODY[language](code),
});
