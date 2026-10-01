import '../../l10n/gen/app_localizations.dart';
import '../widgets/ps_status_badge.dart';

String statusLabel(AppLocalizations l10n, ContributionStatus s) => switch (s) {
      ContributionStatus.due => l10n.statusDue,
      ContributionStatus.overdue => l10n.statusOverdue,
      ContributionStatus.pendingSync => l10n.statusSavedOffline,
      ContributionStatus.recorded => l10n.statusAwaiting,
      ContributionStatus.verified => l10n.statusVerified,
    };
