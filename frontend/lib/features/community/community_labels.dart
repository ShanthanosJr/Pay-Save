import '../../core/community/community.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';

String disputeCategoryLabel(AppLocalizations l10n, DisputeCategory c) => switch (c) {
      DisputeCategory.paymentNotRecorded => l10n.disputeCatNotRecorded,
      DisputeCategory.paymentRejected => l10n.disputeCatRejected,
      DisputeCategory.payoutNotReceived => l10n.disputeCatPayout,
      DisputeCategory.other => l10n.disputeCatOther,
    };

String disputeStatusLabel(AppLocalizations l10n, DisputeStatus s) => switch (s) {
      DisputeStatus.awaitingConsent => l10n.disputeAwaiting,
      DisputeStatus.consented => l10n.disputeConsented,
      DisputeStatus.resolved => l10n.disputeResolved,
      DisputeStatus.declined => l10n.disputeDeclined,
    };

PsPillTone disputeTone(DisputeStatus s) => switch (s) {
      DisputeStatus.awaitingConsent => PsPillTone.warning,
      DisputeStatus.consented => PsPillTone.info,
      DisputeStatus.resolved => PsPillTone.success,
      DisputeStatus.declined => PsPillTone.neutral,
    };
