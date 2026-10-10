import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/format/money.dart';
import '../../core/statements/file_sharer.dart';
import '../../core/statements/statements.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import '../shell/async_states.dart';

/// Verified savings statement (FR-11): proof a member can hand to a lender.
class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue() => _run(() async {
        await ref.read(statementsApiProvider).issue(widget.circleId);
        ref.invalidate(statementsProvider(widget.circleId));
      });

  Future<void> _share(Statement s, {required bool csv}) => _run(() async {
        final bytes = await ref.read(statementsApiProvider).file(s.id, csv: csv);
        await ref.read(fileSharerProvider)(
          bytes,
          name: 'pay-and-save-${s.verificationCode}.${csv ? 'csv' : 'pdf'}',
          mimeType: csv ? 'text/csv' : 'application/pdf',
        );
      });

  void _copy(String label, String value) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copiedToast(label))));
  }

  void _lines(Statement s) {
    final l10n = AppLocalizations.of(context);
    showPsSheet<void>(
      context: context,
      title: l10n.statementEntriesTitle,
      subtitle: l10n.statementEntriesBody,
      builder: (_) => Column(children: [
        for (final line in s.lines)
          PsInfoRow(
            label: '${l10n.cycleLabel(line.cycleNumber)} · ${line.reference}',
            value: formatLkr(line.amountMinor),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(statementsProvider(widget.circleId));
    final statements = async.value;
    final latest = statements?.firstOrNull;

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.statementTitle, backLabel: l10n.backLabel),
        children: [
          Text(l10n.statementIntro, style: AppText.body),
          const SizedBox(height: AppSpace.xl),
          if (statements == null && async.hasError)
            SheetError(error: async.error!, onRetry: () => ref.invalidate(statementsProvider(widget.circleId)))
          else if (statements == null)
            const PsSkeletonCard(lines: 4, button: true)
          else ...[
            if (latest != null) ...[
              PsCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l10n.statementIssued(dateTime(l10n, latest.issuedAt)), style: AppText.footnote),
                  const SizedBox(height: AppSpace.m),
                  PsArithmeticRow(
                    summary: l10n.arithmeticVerified(
                      latest.contributions.count,
                      formatLkr(latest.contributions.unitMinor),
                      formatLkr(latest.contributions.totalMinor),
                    ),
                    onTap: () => _lines(latest),
                  ),
                  const SizedBox(height: AppSpace.l),
                  PsInfoRow(
                    label: l10n.statementCode,
                    value: latest.verificationCode,
                    trailing: IconButton(
                      tooltip: l10n.copyValue(l10n.statementCode),
                      constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                      icon: const Icon(Icons.copy_rounded, color: AppColors.forest700),
                      onPressed: () => _copy(l10n.statementCode, latest.verificationCode),
                    ),
                  ),
                  PsInfoRow(
                    label: l10n.statementCheckLink,
                    value: latest.verifyUrl,
                    trailing: IconButton(
                      tooltip: l10n.copyValue(l10n.statementCheckLink),
                      constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                      icon: const Icon(Icons.copy_rounded, color: AppColors.forest700),
                      onPressed: () => _copy(l10n.statementCheckLink, latest.verifyUrl),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpace.l),
              PsButton(
                label: l10n.statementSharePdf,
                icon: Icons.picture_as_pdf_rounded,
                onPressed: _busy ? null : () => _share(latest, csv: false),
              ),
              const SizedBox(height: AppSpace.m),
              PsButton(
                label: l10n.statementShareCsv,
                icon: Icons.table_chart_rounded,
                variant: PsButtonVariant.secondary,
                onPressed: _busy ? null : () => _share(latest, csv: true),
              ),
              const SizedBox(height: AppSpace.m),
            ],
            PsButton(
              label: latest == null ? l10n.statementCreate : l10n.statementCreateNew,
              icon: Icons.verified_user_rounded,
              variant: latest == null ? PsButtonVariant.primary : PsButtonVariant.secondary,
              loading: _busy,
              onPressed: _issue,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.l),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: AppSpace.xxl),
            PsSectionHeader(title: l10n.statementHowTitle),
            for (final (icon, text) in [
              (Icons.verified_rounded, l10n.statementHowVerified),
              (Icons.link_rounded, l10n.statementHowChain),
              (Icons.visibility_off_rounded, l10n.statementHowPrivacy),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 20, color: AppColors.forest700),
                  const SizedBox(width: AppSpace.m),
                  Expanded(child: Text(text, style: AppText.footnote)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}
