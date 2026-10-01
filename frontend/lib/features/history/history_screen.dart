import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../core/format/status_label.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../circle/sample_circle.dart';
import '../shell/brand_header.dart';

enum _Filter { all, verified, pending }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat.yMMMd(l10n.localeName);
    final entries = SampleCircle.myEntries.where((e) => switch (_filter) {
          _Filter.all => true,
          _Filter.verified => e.status == ContributionStatus.verified && e.kind == EntryKind.contribution,
          _Filter.pending => e.status == ContributionStatus.recorded || e.status == ContributionStatus.pendingSync,
        });

    String method(String m) => switch (m) {
          'cash' => l10n.methodCash,
          'mobile_wallet' => l10n.methodWallet,
          _ => l10n.methodBank,
        };

    return PsForestPage(
      header: const BrandHeader(),
      children: [
        PsSectionHeader(title: l10n.navHistory, large: true),
        PsSegmented<_Filter>(
          segments: [
            (_Filter.all, l10n.filterAll),
            (_Filter.verified, l10n.filterVerified),
            (_Filter.pending, l10n.filterPending),
          ],
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: AppSpace.xl),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.curve,
          child: entries.isEmpty
              ? _Empty(key: const ValueKey('empty'), title: l10n.emptyPendingTitle, body: l10n.emptyPendingBody)
              : Column(
                  key: ValueKey(_filter),
                  children: [
                    for (final e in entries)
                      e.kind == EntryKind.correction
                          ? PsListRow(
                              icon: Icons.undo_rounded,
                              tone: PsBadgeTone.warning,
                              title: '${l10n.entryCorrection} · ${e.reference}',
                              subtitle: '${l10n.correctsRef(e.corrects!)}\n${fmt.format(e.date)}',
                              trailing: Text(
                                '−${formatMinor(-e.amountMinor)}',
                                style: AppText.label.copyWith(color: AppColors.warning),
                              ),
                            )
                          : PsListRow(
                              icon: SampleCircle.correctedRefs.contains(e.reference)
                                  ? Icons.remove_done_rounded
                                  : Icons.check_rounded,
                              tone: SampleCircle.correctedRefs.contains(e.reference)
                                  ? PsBadgeTone.neutral
                                  : PsBadgeTone.forest,
                              title: l10n.entryContribution(e.cycle),
                              subtitle: '${e.reference} · ${method(e.method)} · ${fmt.format(e.date)}',
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formatLkr(e.amountMinor), style: AppText.label),
                                  const SizedBox(height: 6),
                                  SampleCircle.correctedRefs.contains(e.reference)
                                      ? PsStatusPill(
                                          label: l10n.statusCorrected,
                                          tone: PsPillTone.neutral,
                                          icon: Icons.undo_rounded,
                                          filled: false,
                                        )
                                      : PsStatusBadge(status: e.status, label: statusLabel(l10n, e.status)),
                                ],
                              ),
                            ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.m),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkSubtle),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.recordsAppendOnly, style: AppText.caption)),
        ]),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: AppColors.mintSoft, shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_empty_rounded, size: 44, color: AppColors.forest600),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(title, style: AppText.section, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s),
        Text(body, style: AppText.body, textAlign: TextAlign.center),
      ]),
    );
  }
}
