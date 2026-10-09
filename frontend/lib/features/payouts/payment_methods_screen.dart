import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/payouts/payout_models.dart';
import '../../core/payouts/payouts_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';
import 'payout_ui.dart';

/// "How you get paid": the member's own payment details, managed once and
/// shared per circle.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myPayoutMethodsProvider);
    final methods = async.value;

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.paymentMethodsTitle, backLabel: l10n.backLabel),
        children: [
          Text(l10n.paymentMethodsIntro, style: AppText.body),
          const SizedBox(height: AppSpace.xl),
          if (methods == null && async.hasError)
            Column(
              children: [
                Text(messageFor(l10n, async.error!), style: AppText.body),
                const SizedBox(height: AppSpace.m),
                PsButton(
                  label: l10n.retryLabel,
                  variant: PsButtonVariant.secondary,
                  compact: true,
                  expand: false,
                  onPressed: () => ref.invalidate(myPayoutMethodsProvider),
                ),
              ],
            )
          else if (methods == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2)),
            )
          else if (methods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
              child: Column(
                children: [
                  const PsIconBadge(icon: Icons.account_balance_wallet_outlined, tone: PsBadgeTone.mint, size: 64),
                  const SizedBox(height: AppSpace.m),
                  Text(l10n.paymentMethodsEmpty, style: AppText.headline),
                  const SizedBox(height: AppSpace.xs),
                  Text(l10n.paymentMethodsEmptyBody, textAlign: TextAlign.center, style: AppText.footnote),
                ],
              ),
            )
          else
            for (final m in methods)
              PayoutMethodCard(
                kind: m.kind,
                summary: m.summary,
                holder: m.details.accountName ?? m.details.merchantName ?? m.details.note,
                isDefault: m.isDefault,
                trailing: IconButton(
                  tooltip: l10n.moreActions,
                  constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: m.kind == PayoutKind.bankTransfer ? AppColors.onForest : AppColors.inkMuted,
                  ),
                  onPressed: () => _actions(context, ref, m),
                ),
              ),
          const SizedBox(height: AppSpace.m),
          PsButton(
            label: l10n.addPaymentMethod,
            icon: Icons.add_rounded,
            onPressed: () => context.push('/profile/payment-methods/new'),
          ),
          const SizedBox(height: AppSpace.xxl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(l10n.paymentMethodsPrivacy, style: AppText.footnote)),
            ],
          ),
        ],
      ),
    );
  }

  void _actions(BuildContext context, WidgetRef ref, PayoutMethod m) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(payoutsApiProvider);

    Future<void> run(Future<void> Function() fn, String toast) async {
      try {
        await fn();
        ref.invalidate(myPayoutMethodsProvider);
        messenger.showSnackBar(SnackBar(content: Text(toast)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
      }
    }

    showPsSheet<void>(
      context: context,
      title: m.summary,
      builder: (ctx) => Column(
        children: [
          if (!m.isDefault)
            PsListRow(
              icon: Icons.star_outline_rounded,
              tone: PsBadgeTone.mint,
              title: l10n.makeDefaultAction,
              subtitle: l10n.makeDefaultLabel,
              onTap: () {
                Navigator.of(ctx).pop();
                run(() => api.makeDefault(m.id), l10n.makeDefaultAction);
              },
            ),
          PsListRow(
            icon: Icons.delete_outline_rounded,
            tone: PsBadgeTone.danger,
            title: l10n.removeMethodAction,
            titleColor: AppColors.danger,
            onTap: () async {
              Navigator.of(ctx).pop();
              final ok = await showPsSheet<bool>(
                context: context,
                title: l10n.removeMethodTitle(m.summary),
                subtitle: l10n.removeMethodBody,
                builder: (c2) => Row(
                  children: [
                    Expanded(
                      child: PsButton(
                        label: l10n.cancelLabel,
                        variant: PsButtonVariant.secondary,
                        onPressed: () => Navigator.of(c2).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: PsButton(
                        label: l10n.removeMethodAction,
                        variant: PsButtonVariant.danger,
                        onPressed: () => Navigator.of(c2).pop(true),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) await run(() => api.remove(m.id), l10n.methodRemovedToast);
            },
          ),
        ],
      ),
    );
  }
}
