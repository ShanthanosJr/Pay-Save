import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/payouts/payout_models.dart';
import '../../core/payouts/payouts_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import 'payout_ui.dart';

/// The member's choice of what to share with one circle.
class PayoutSelection {
  const PayoutSelection(this.ids, this.preferredId);

  final List<String> ids;
  final String? preferredId;

  bool get isEmpty => ids.isEmpty;

  PayoutSelection toggle(String id) {
    if (ids.contains(id)) {
      final rest = ids.where((x) => x != id).toList();
      return PayoutSelection(rest, preferredId == id ? rest.firstOrNull : preferredId);
    }
    return PayoutSelection([...ids, id], preferredId ?? id);
  }

  PayoutSelection prefer(String id) => PayoutSelection(ids, id);

  /// Starts from the default method when nothing is chosen yet.
  static PayoutSelection initial(List<PayoutMethod> mine, List<String> current, String? preferred) {
    if (current.isNotEmpty) return PayoutSelection(current, preferred ?? current.first);
    final d = mine.where((m) => m.isDefault).firstOrNull;
    return d == null ? const PayoutSelection([], null) : PayoutSelection([d.id], d.id);
  }
}

/// Tick the methods to share, star the preferred one, or add a new one inline.
class PayoutMethodPicker extends ConsumerWidget {
  const PayoutMethodPicker({super.key, required this.selection, required this.onChanged});

  final PayoutSelection? selection;
  final ValueChanged<PayoutSelection> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myPayoutMethodsProvider);
    final mine = async.value;
    if (mine == null) {
      return async.hasError
          ? Text(messageFor(l10n, async.error!), style: AppText.body)
          : const PsSkeletonRows(count: 2, leading: PsSkeletonLeading.badge);
    }
    final sel = selection ?? PayoutSelection.initial(mine, const [], null);
    if (selection == null && !sel.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(sel));
    }

    Future<void> addNew() async {
      final id = await context.push<String>('/profile/payment-methods/new');
      if (id != null) onChanged(sel.toggle(id));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in mine)
          PayoutMethodCard(
            kind: m.kind,
            summary: m.summary,
            holder: m.details.accountName ?? m.details.merchantName ?? m.details.note,
            preferred: sel.ids.length > 1 && sel.preferredId == m.id,
            selected: sel.ids.contains(m.id),
            onTap: () => onChanged(sel.toggle(m.id)),
            trailing: sel.ids.length > 1 && sel.ids.contains(m.id) && sel.preferredId != m.id
                ? IconButton(
                    tooltip: l10n.preferredLabel,
                    constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                    icon: Icon(
                      Icons.star_outline_rounded,
                      color: m.kind == PayoutKind.bankTransfer ? AppColors.onForest : AppColors.forest700,
                    ),
                    onPressed: () => onChanged(sel.prefer(m.id)),
                  )
                : null,
          ),
        PsButton(
          label: l10n.addNewMethod,
          icon: Icons.add_rounded,
          variant: PsButtonVariant.secondary,
          compact: true,
          onPressed: addNew,
        ),
      ],
    );
  }
}

/// Sheet version for changing what a circle sees. Returns the new selection.
Future<PayoutSelection?> showPayoutPickerSheet(
  BuildContext context, {
  required String circleName,
  required List<String> currentIds,
  String? currentPreferred,
}) {
  final l10n = AppLocalizations.of(context);
  return showPsSheet<PayoutSelection>(
    context: context,
    title: l10n.choosePayoutTitle(circleName),
    subtitle: l10n.choosePayoutBody,
    builder: (ctx) => _PickerSheetBody(currentIds: currentIds, currentPreferred: currentPreferred),
  );
}

class _PickerSheetBody extends StatefulWidget {
  const _PickerSheetBody({required this.currentIds, this.currentPreferred});

  final List<String> currentIds;
  final String? currentPreferred;

  @override
  State<_PickerSheetBody> createState() => _PickerSheetBodyState();
}

class _PickerSheetBodyState extends State<_PickerSheetBody> {
  late PayoutSelection? _sel = widget.currentIds.isEmpty
      ? null
      : PayoutSelection(widget.currentIds, widget.currentPreferred ?? widget.currentIds.first);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sel = _sel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayoutMethodPicker(selection: sel, onChanged: (s) => setState(() => _sel = s)),
        const SizedBox(height: AppSpace.l),
        PsButton(
          label: l10n.shareSelected,
          icon: Icons.check_rounded,
          onPressed: sel == null || sel.isEmpty ? null : () => Navigator.of(context).pop(sel),
        ),
      ],
    );
  }
}
