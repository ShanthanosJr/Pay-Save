import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/community/community.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shell/async_states.dart';
import 'community_labels.dart';

/// "Privacy & access" for one circle: what a community officer can and cannot
/// see, the member's own consent, and any dispute that asks for theirs.
class CircleSharingScreen extends ConsumerWidget {
  const CircleSharingScreen({super.key, required this.circleId});

  final String circleId;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() fn) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await fn();
      ref.invalidate(communityConsentProvider(circleId));
      ref.invalidate(disputesProvider(circleId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final api = ref.read(communityApiProvider);
    final consentAsync = ref.watch(communityConsentProvider(circleId));
    final consent = consentAsync.value;
    final disputes = ref.watch(disputesProvider(circleId)).value ?? const <Dispute>[];

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.sharingTitle, backLabel: l10n.backLabel),
        children: [
          if (consent == null && consentAsync.hasError)
            SheetError(error: consentAsync.error!, onRetry: () => ref.invalidate(communityConsentProvider(circleId)))
          else if (consent == null)
            const SheetLoading()
          else ...[
            PsSectionHeader(title: l10n.sharingOfficerTitle),
            for (final (icon, color, text) in [
              (Icons.check_circle_rounded, AppColors.success, l10n.sharingSeesTotals),
              (Icons.cancel_rounded, AppColors.danger, l10n.sharingNeverNames),
              (Icons.gavel_rounded, AppColors.warning, l10n.sharingDisputeException),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpace.m),
                  Expanded(child: Text(text, style: AppText.body)),
                ]),
              ),
            const SizedBox(height: AppSpace.m),
            PsCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SwitchListTile(
                  value: consent.mine,
                  onChanged: (v) => _act(context, ref, () => api.setConsent(circleId, v)),
                  title: Text(l10n.sharingMySwitch, style: AppText.headline),
                  subtitle: Text(l10n.sharingProgress(consent.granted, consent.needed), style: AppText.footnote),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.forest700,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(
                      consent.shared && consent.largeEnough ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: AppSpace.s),
                    Expanded(
                      child: Text(
                        !consent.largeEnough
                            ? l10n.sharingTooSmall(consent.minimumMembers)
                            : consent.shared
                                ? l10n.sharingIsShared
                                : l10n.sharingNotShared,
                        style: AppText.footnote,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.xxl),
            PsSectionHeader(title: l10n.disputesTitle),
            Text(l10n.disputeSteps, style: AppText.footnote),
            const SizedBox(height: AppSpace.m),
            if (disputes.isEmpty)
              Text(l10n.disputesEmpty, style: AppText.body)
            else
              for (final d in disputes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.m),
                  child: PsCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(disputeCategoryLabel(l10n, d.category), style: AppText.headline)),
                        PsStatusPill(
                          label: disputeStatusLabel(l10n, d.status),
                          tone: disputeTone(d.status),
                          icon: d.status == DisputeStatus.resolved ? Icons.check_rounded : Icons.gavel_rounded,
                        ),
                      ]),
                      const SizedBox(height: AppSpace.xs),
                      Text('${d.references.join(', ')} · ${longDate(l10n, d.createdAt)}', style: AppText.footnote),
                      const SizedBox(height: AppSpace.xs),
                      Text(l10n.disputeConsentProgress(d.consentGranted, d.consentNeeded), style: AppText.footnote),
                      if (d.views.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(l10n.disputeViewed(d.views.length, dateTime(l10n, d.views.first)), style: AppText.footnote),
                      ],
                      if (d.resolutionNote != null) ...[
                        const SizedBox(height: AppSpace.s),
                        Text(l10n.disputeOutcome(d.resolutionNote!), style: AppText.body),
                      ],
                      if (d.awaitingMe) ...[
                        const SizedBox(height: AppSpace.m),
                        Text(l10n.disputeAskYou, style: AppText.body),
                        const SizedBox(height: AppSpace.m),
                        Row(children: [
                          Expanded(
                            child: PsButton(
                              label: l10n.disputeRefuse,
                              variant: PsButtonVariant.secondary,
                              compact: true,
                              onPressed: () => _act(context, ref, () => api.respond(circleId, d.id, false)),
                            ),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: PsButton(
                              label: l10n.disputeAllow,
                              compact: true,
                              onPressed: () => _act(context, ref, () => api.respond(circleId, d.id, true)),
                            ),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                ),
            const SizedBox(height: AppSpace.m),
            Text(l10n.disputeHowToRaise, style: AppText.footnote),
          ],
        ],
      ),
    );
  }
}
