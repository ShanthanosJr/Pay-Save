import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format/money.dart';
import '../../core/format/status_label.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shell/brand_header.dart';
import 'sample_circle.dart';

class CircleScreen extends ConsumerWidget {
  const CircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final you = auth is AuthLoggedIn ? auth.user.fullName : '';
    final members = SampleCircle.members(you);
    final organizer = members.firstWhere((m) => m.isOrganizer);

    return PsForestPage(
      header: const BrandHeader(),
      children: [
        PsSectionHeader(
          title: SampleCircle.name,
          large: true,
          trailing: Semantics(
            label: l10n.circleCodeLabel(SampleCircle.code),
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tag_rounded, size: 16, color: AppColors.onForest),
                const SizedBox(width: 4),
                Text(SampleCircle.code, style: AppText.label.copyWith(color: AppColors.onForest)),
              ]),
            ),
          ),
        ),
        PsCard(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: IntrinsicHeight(
            child: Row(children: [
              _Fact(label: l10n.contributionLabel, value: formatLkr(SampleCircle.contributionMinor)),
              const VerticalDivider(color: AppColors.stroke, width: 1),
              _Fact(label: l10n.intervalLabel, value: l10n.intervalMonthly),
              const VerticalDivider(color: AppColors.stroke, width: 1),
              _Fact(label: l10n.turnRuleLabel, value: l10n.turnRuleFixed),
            ]),
          ),
        ),
        const SizedBox(height: AppSpace.xxxl),
        PsSectionHeader(title: l10n.circleMembers),
        Container(
          margin: const EdgeInsets.only(bottom: AppSpace.m),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Row(children: [
            const Icon(Icons.verified_rounded, size: 18, color: AppColors.forest700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.cycleOf(SampleCircle.currentCycle, SampleCircle.totalCycles)} · '
                '${l10n.membersVerifiedSummary(members.where((m) => m.status == ContributionStatus.verified).length, members.length)}',
                style: AppText.footnote.copyWith(color: AppColors.forest800),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpace.m),
          child: Row(children: [
            PsAvatar(name: organizer.name, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text('${l10n.organizerLabel} · ${organizer.name}', style: AppText.callout)),
          ]),
        ),
        for (final m in members)
          PsListRow(
            leading: PsAvatar(name: m.name, size: 46),
            title: m.isYou ? '${m.name} (${l10n.youLabel})' : m.name,
            subtitle: m.isOrganizer ? '${l10n.turnNumber(m.turn)} · ${l10n.organizerLabel}' : l10n.turnNumber(m.turn),
            trailing: PsStatusBadge(status: m.status, label: _shortStatus(l10n, m.status)),
          ),
      ],
    );
  }

  String _shortStatus(AppLocalizations l10n, ContributionStatus s) =>
      s == ContributionStatus.recorded ? l10n.filterPending : statusLabel(l10n, s);
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 6),
          Text(value, style: AppText.headline.copyWith(fontSize: 15)),
        ]),
      ),
    );
  }
}
