import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format/money.dart';
import '../../core/format/status_label.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_bar_chart.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../circle/sample_circle.dart';
import '../shell/brand_header.dart';

/// Member dashboard. Circle figures are placeholder data until the ledger
/// API lands; status always comes from the contribution state machine.
class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthLoggedIn ? auth.user : null;
    final status = SampleCircle.myStatus;
    final canPay = status == ContributionStatus.due || status == ContributionStatus.overdue;
    final dueDate = DateFormat.MMMd(l10n.localeName).format(SampleCircle.dueDate);
    const unit = SampleCircle.contributionMinor;
    const verified = SampleCircle.verifiedThisCycle;
    final members = SampleCircle.members(user?.fullName ?? '');

    return PsForestPage(
      header: const BrandHeader(),
      children: [
        Text(SampleCircle.name, style: AppText.footnote),
        const SizedBox(height: 4),
        Text(l10n.greeting(user?.firstName ?? ''), style: AppText.display),
        const SizedBox(height: AppSpace.xxl),

        PsSectionHeader(
          title: l10n.needsAttention,
          trailing: PsPillLink(label: l10n.seeMore, onTap: () => showNotificationsSheet(context)),
        ),
        _AttentionCard(
          title: canPay ? l10n.contributionDueTitle : statusLabel(l10n, status),
          body: '${l10n.cycleOf(SampleCircle.currentCycle, SampleCircle.totalCycles)} · ${formatLkr(unit)}',
          meta: l10n.dueInDays(dueDate, SampleCircle.daysLeft),
          status: status,
          statusLabel: statusLabel(l10n, status),
          action: canPay
              ? PsButton(
                  label: l10n.payNow,
                  icon: Icons.arrow_outward_rounded,
                  onPressed: () => _showRecordPayment(context),
                )
              : PsButton(label: l10n.viewRecord, variant: PsButtonVariant.secondary, onPressed: () => context.go('/history')),
        ),
        const SizedBox(height: AppSpace.xxxl),

        PsSectionHeader(title: l10n.dashboardTitle),
        Row(children: [
          Expanded(
            child: _StatTile(
              label: l10n.mySavingsTile,
              value: formatLkr(verified * unit),
              caption: l10n.verifiedCount(verified),
              badge: const PsIconBadge(icon: Icons.savings_rounded, size: 36),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: _StatTile(
              label: l10n.thisCycle,
              value: statusLabel(l10n, status),
              valueColor: status == ContributionStatus.overdue ? AppColors.danger : null,
              caption: l10n.dueInDays(dueDate, SampleCircle.daysLeft),
              badge: PsIconBadge(
                icon: PsStatusBadge.styleFor(status).$1,
                tone: status == ContributionStatus.verified
                    ? PsBadgeTone.forest
                    : status == ContributionStatus.overdue
                        ? PsBadgeTone.danger
                        : PsBadgeTone.warning,
                size: 36,
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.m),
        PsCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(l10n.collectionTitle, style: AppText.callout.copyWith(color: AppColors.inkMuted))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(l10n.cycleLabel(SampleCircle.currentCycle), style: AppText.label),
              ),
            ]),
            const SizedBox(height: AppSpace.l),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatLkr(verified * unit), style: AppText.figure),
            ),
            const SizedBox(height: 6),
            Text(l10n.collectionOf(formatMinor(members.length * unit)), style: AppText.footnote),
            const SizedBox(height: AppSpace.xl),
            PsBarChart(
                  semanticLabel: l10n.collectionChartLabel,
                  bars: [
                    for (var i = 0; i < SampleCircle.collectedPerCycle.length; i++)
                      PsBar(
                        label: '${i + 1}',
                        value: SampleCircle.collectedPerCycle[i] ?? 0,
                        empty: SampleCircle.collectedPerCycle[i] == null,
                        highlight: i + 1 == SampleCircle.currentCycle,
                      ),
                  ],
                ),
            const SizedBox(height: AppSpace.l),
            PsArithmeticRow(
              summary: l10n.arithmeticSummary(
                verified,
                l10n.statusVerified.toLowerCase(),
                formatMinor(unit),
                formatMinor(verified * unit),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.xxxl),

        PsSectionHeader(
          title: l10n.turnOrderTitle,
          trailing: PsPillLink(label: l10n.seeMore, onTap: () => context.go('/circle')),
        ),
        for (final m in members.where((m) => m.turn >= SampleCircle.currentCycle))
          PsListRow(
            leading: PsAvatar(name: m.name, size: 42),
            title: m.isYou ? l10n.youLabel : m.name,
            subtitle: l10n.receivesInCycle(m.turn),
            trailing: m.turn == SampleCircle.currentCycle
                ? PsStatusPill(label: l10n.turnCurrent, tone: PsPillTone.success, icon: Icons.south_west_rounded)
                : m.turn == SampleCircle.currentCycle + 1
                    ? PsStatusPill(label: l10n.turnNext, tone: PsPillTone.info, filled: false)
                    : null,
          ),
      ],
    );
  }

  void _showRecordPayment(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showPsSheet<void>(
      context: context,
      title: l10n.recordPaymentTitle,
      subtitle: l10n.recordPaymentSubtitle(SampleCircle.recipientName, SampleCircle.currentCycle),
      builder: (ctx) => const _RecordPaymentBody(),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.title,
    required this.body,
    required this.meta,
    required this.status,
    required this.statusLabel,
    required this.action,
  });

  final String title;
  final String body;
  final String meta;
  final ContributionStatus status;
  final String statusLabel;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final urgent = status == ContributionStatus.due || status == ContributionStatus.overdue;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsIconBadge(
              icon: urgent ? Icons.priority_high_rounded : PsStatusBadge.styleFor(status).$1,
              tone: urgent ? PsBadgeTone.danger : PsBadgeTone.forest,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.section.copyWith(fontSize: 19)),
                const SizedBox(height: 4),
                Text(body, style: AppText.body.copyWith(color: AppColors.ink)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  PsStatusBadge(status: status, label: statusLabel, filled: false),
                  Text(meta, style: AppText.footnote),
                ]),
              ]),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadii.card)),
          ),
          child: action,
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.badge,
    this.caption,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget badge;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: AppText.footnote)),
          badge,
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.figureSmall.copyWith(color: valueColor)),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: AppText.caption, maxLines: 2),
        ],
      ]),
    );
  }
}

class _RecordPaymentBody extends StatefulWidget {
  const _RecordPaymentBody();

  @override
  State<_RecordPaymentBody> createState() => _RecordPaymentBodyState();
}

class _RecordPaymentBodyState extends State<_RecordPaymentBody> {
  String _method = 'bank_transfer';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final methods = [
      ('cash', l10n.methodCash, Icons.payments_rounded),
      ('bank_transfer', l10n.methodBank, Icons.account_balance_rounded),
      ('mobile_wallet', l10n.methodWallet, Icons.phone_iphone_rounded),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PsInfoRow(label: l10n.amountLabel, value: formatLkr(SampleCircle.contributionMinor)),
      const SizedBox(height: AppSpace.s),
      PsGroupLabel(l10n.methodLabel),
      for (final (id, label, icon) in methods)
        Semantics(
          selected: _method == id,
          child: PsListRow(
            icon: icon,
            tone: _method == id ? PsBadgeTone.forest : PsBadgeTone.neutral,
            title: label,
            onTap: () => setState(() => _method = id),
            trailing: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                _method == id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                key: ValueKey(_method == id),
                color: _method == id ? AppColors.forest600 : AppColors.strokeStrong,
              ),
            ),
          ),
        ),
      const SizedBox(height: AppSpace.m),
      PsButton(label: l10n.recordPaymentCta, onPressed: null),
      const SizedBox(height: AppSpace.m),
      PsButton(
        label: l10n.cancelLabel,
        variant: PsButtonVariant.secondary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: AppSpace.m),
      Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSubtle),
        const SizedBox(width: 8),
        Expanded(child: Text(l10n.recordPaymentSoon, style: AppText.caption)),
      ]),
    ]);
  }
}
