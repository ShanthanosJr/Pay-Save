import '../../l10n/gen/app_localizations.dart';
import 'api_exception.dart';

String messageFor(AppLocalizations l10n, Object error) {
  final e = ApiException.from(error);
  if (e.isNetwork) return l10n.errNetwork;
  switch (e.code) {
    case 'PHONE_TAKEN':
      return l10n.errPhoneTaken;
    case 'EMAIL_TAKEN':
      return l10n.errEmailTaken;
    case 'NIC_TAKEN':
      return l10n.errNicTaken;
    case 'ACCOUNT_LOCKED':
      return l10n.errAccountLocked;
    case 'INVALID_CREDENTIALS':
      return l10n.errInvalidCredentials;
    case 'INVALID_CODE':
      return l10n.errInvalidCode;
    case 'OTP_LOCKED':
    case 'OTP_COOLDOWN':
      return l10n.errTooManyAttempts;
  }
  return switch (e.statusCode) {
    401 => l10n.errInvalidCredentials,
    423 => l10n.errAccountLocked,
    429 => l10n.errTooManyAttempts,
    _ => l10n.errGeneric,
  };
}
