import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/community/community.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shell/async_states.dart';
import 'community_labels.dart';

/// Community officer home: consented circles by code with totals only, and
/// the disputes whose members have agreed to show evidence.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final circlesAsync = ref.watch(communityOverviewProvider);
    final circles = circlesAsync.value;
    final disputes = ref.watch(officerDisputesProvider).value ?? const <OfficerDispute>[];

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.communityTitle, backLabel: l10n.backLabel),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(AppRadii.small)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.shield_rounded, size: 20, color: AppColors.forest700),
              const SizedBox(width: AppSpace.m),
              Expanded(child: Text(l10n.communityPrivacyNote, style: AppText.footnote.copyWith(color: AppColors.forest800))),
            ]),
          ),
          const SizedBox(height: AppSpace.xl),
          PsSectionHeader(title: l10n.communityDisputesTitle),
          if (disputes.isEmpty)
            Text(l10n.communityNoDisputes, style: AppText.body)
          else
            for (final d in disputes)
              PsListRow(
                icon: Icons.gavel_rounded,
                tone: d.status == DisputeStatus.resolved ? PsBadgeTone.neutral : PsBadgeTone.warning,
                title: '${d.circleCode} · ${disputeCategoryLabel(l10n, d.category)}',
                subtitle: '${l10n.communityEntryCount(d.entryCount)} · ${longDate(l10n, d.createdAt)}',
                trailing: PsStatusPill(
                  label: disputeStatusLabel(l10n, d.status),
                  tone: disputeTone(d.status),
                  icon: Icons.gavel_rounded,
                  filled: false,
                ),
                onTap: () => context.push('/community/disputes/${d.id}'),
              ),
          const SizedBox(height: AppSpace.xxl),
          PsSectionHeader(title: l10n.communityCirclesTitle),
          if (circles == null && circlesAsync.hasError)
            SheetError(error: circlesAsync.error!, onRetry: () => ref.invalidate(communityOverviewProvider))
          else if (circles == null)
            const SheetLoading()
          else if (circles.isEmpty)
            Text(l10n.communityNoCircles, style: AppText.body)
          else
            for (final c in circles)
              PsListRow(
                icon: Icons.groups_rounded,
                tone: PsBadgeTone.mint,
                title: c.circleCode,
                subtitle: l10n.communityCircleLine(c.members, c.cyclesRun),
                trailing: Text(
                  c.onTimeRatePct == null ? '—' : l10n.communityOnTime(c.onTimeRatePct!),
                  style: AppText.label,
                ),
              ),
        ],
      ),
    );
  }
}

/// The entries named in one consented dispute. Opening this page is logged
/// and the members concerned are told.
class DisputeEvidenceScreen extends ConsumerStatefulWidget {
  const DisputeEvidenceScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<DisputeEvidenceScreen> createState() => _DisputeEvidenceScreenState();
}

class _DisputeEvidenceScreenState extends ConsumerState<DisputeEvidenceScreen> {
  late Future<(OfficerDispute, List<EvidenceEntry>)> _load;

  @override
  void initState() {
    super.initState();
    // read once: every fetch writes an access-log row
    _load = ref.read(communityApiProvider).evidence(widget.disputeId);
  }

  Future<void> _resolve() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showPsSheet<bool>(
      context: context,
      title: l10n.communityResolveTitle,
      subtitle: l10n.communityResolveBody,
      builder: (ctx) => Form(
        key: form,
        child: Column(children: [
          PsTextField(
            label: l10n.communityResolveNote,
            controller: note,
            textInputAction: TextInputAction.done,
            validator: (v) => (v ?? '').trim().length < 3 ? l10n.errRequired : null,
          ),
          const SizedBox(height: AppSpace.xl),
          PsButton(
            label: l10n.communityResolveAction,
            onPressed: () {
              if (form.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
          ),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(communityApiProvider).resolve(widget.disputeId, note.text.trim());
      ref.invalidate(officerDisputesProvider);
      router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: FutureBuilder(
        future: _load,
        builder: (context, snap) {
          final data = snap.data;
          return PsForestPage(
            header: PsBackHeader(title: l10n.communityEvidenceTitle, backLabel: l10n.backLabel),
            children: [
              if (snap.hasError)
                SheetError(
                  error: snap.error!,
                  onRetry: () => setState(() => _load = ref.read(communityApiProvider).evidence(widget.disputeId)),
                )
              else if (data == null)
                const SheetLoading()
              else ...[
                Text('${data.$1.circleCode} · ${disputeCategoryLabel(l10n, data.$1.category)}', style: AppText.headline),
                const SizedBox(height: AppSpace.xs),
                Text(l10n.communityEvidenceNote, style: AppText.footnote),
                const SizedBox(height: AppSpace.l),
                for (final e in data.$2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.m),
                    child: PsCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(e.reference, style: AppText.headline),
                        PsInfoRow(label: l10n.evidenceType, value: e.type.replaceAll('_', ' ')),
                        if (e.cycleNumber != null) PsInfoRow(label: l10n.evidenceCycle, value: '${e.cycleNumber}'),
                        if (e.amountMinor != null) PsInfoRow(label: l10n.amountToPay, value: formatLkr(e.amountMinor!)),
                        if (e.subject != null) PsInfoRow(label: l10n.evidenceAbout, value: e.subject!),
                        PsInfoRow(label: l10n.evidenceRecordedBy, value: e.recordedBy),
                        if (e.status != null) PsInfoRow(label: l10n.evidenceStatus, value: e.status!),
                        PsInfoRow(label: l10n.evidenceWhen, value: dateTime(l10n, e.createdAt)),
                        const SizedBox(height: AppSpace.s),
                        Text(e.hash, style: AppText.caption),
                      ]),
                    ),
                  ),
                if (data.$1.status == DisputeStatus.consented)
                  PsButton(label: l10n.communityResolveAction, icon: Icons.check_rounded, onPressed: _resolve),
              ],
            ],
          );
        },
      ),
    );
  }
}
