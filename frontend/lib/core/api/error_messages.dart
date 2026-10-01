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
    case 'INVALID_NIC':
      return l10n.errNicFormat;
    case 'ACCOUNT_LOCKED':
      return l10n.errAccountLocked;
    case 'INVALID_CREDENTIALS':
      return l10n.errInvalidCredentials;
    case 'INVALID_CODE':
      return l10n.errInvalidCode;
    case 'INVALID_JOIN_CODE':
      return l10n.errInvalidJoinCode;
    case 'CIRCLE_ALREADY_STARTED':
      return l10n.errCircleStarted;
    case 'CIRCLE_FULL':
      return l10n.errCircleFull;
    case 'ALREADY_MEMBER':
      return l10n.errAlreadyMember;
    case 'NOT_ENOUGH_MEMBERS':
      return l10n.errNotEnoughMembers;
    case 'ALREADY_RECORDED':
      return l10n.errAlreadyRecorded;
    case 'PENDING_VERIFICATIONS':
      return l10n.errPendingVerifications;
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
