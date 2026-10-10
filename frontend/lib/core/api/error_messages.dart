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
    case 'USERNAME_TAKEN':
      return l10n.errUsernameTaken;
    case 'IMAGE_TOO_LARGE':
      return l10n.errImageTooLarge;
    case 'UNSUPPORTED_IMAGE':
    case 'IMAGE_REQUIRED':
      return l10n.errUnsupportedImage;
    case 'BLOCKED':
      return l10n.errBlocked;
    case 'NO_PAL_REQUEST':
      return l10n.errNoPalRequest;
    case 'TOO_MANY_PAL_REQUESTS':
      return l10n.errTooManyPalRequests;
    case 'NOT_A_PAL':
      return l10n.errNotAPal;
    case 'NOT_ENOUGH_SEATS':
      return l10n.errNotEnoughSeats;
    case 'PAYOUT_DETAILS_MISSING':
      return l10n.errPayoutMissingStart;
    case 'PAYOUT_METHOD_IN_USE':
      return l10n.errMethodInUse;
    case 'INVALID_PAYOUT_DETAILS':
      return l10n.errPayoutDetails;
    case 'INVITATION_NOT_FOUND':
      return l10n.errInvitationGone;
    case 'FILE_TOO_LARGE':
      return l10n.errFileTooLarge;
    case 'UNSUPPORTED_MEDIA':
    case 'FILE_REQUIRED':
      return l10n.errUnsupportedMedia;
    case 'OWN_TURN':
      return l10n.errOwnTurn;
    case 'CYCLE_CLOSED':
      return l10n.errCycleClosed;
    case 'CYCLE_HAS_PAYMENTS':
      return l10n.errCycleHasPayments;
    case 'FIRST_DUE_DATE_PASSED':
      return l10n.errFirstDuePassed;
    case 'WRONG_PASSWORD':
      return l10n.errWrongPassword;
    case 'DELIVERY_FAILED':
      return l10n.errDeliveryFailed;
    case 'EMAIL_NOT_VERIFIED':
      return l10n.errEmailNotVerified;
    case 'REMINDER_DAYS_REQUIRED':
      return l10n.reminderChooseDay;
    case 'NOTHING_VERIFIED':
      return l10n.errNothingVerified;
    case 'LEDGER_INTEGRITY':
      return l10n.errLedgerIntegrity;
    case 'MEMBER_ALREADY_PAID_OUT':
      return l10n.errMemberPaidOut;
    case 'MEMBER_HAS_PAYMENT':
      return l10n.errMemberHasPayment;
    case 'ALREADY_REMINDED':
      return l10n.errAlreadyReminded;
    case 'ORGANIZER_CANNOT_LEAVE':
      return l10n.errOrganizerCannotLeave;
    case 'DISPUTE_CLOSED':
      return l10n.errDisputeClosed;
    case 'FORBIDDEN_ROLE':
      return l10n.errNotYourRecord;
    case 'NOT_FOUND':
      return l10n.personNotFound;
  }
  return switch (e.statusCode) {
    401 => l10n.errInvalidCredentials,
    423 => l10n.errAccountLocked,
    429 => l10n.errTooManyAttempts,
    _ => l10n.errGeneric,
  };
}
