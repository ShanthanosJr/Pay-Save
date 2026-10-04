import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/social/social_models.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';

enum PalAction { request, accept, ignore, withdraw, remove }

/// The pal action a button should offer for [status].
PalAction primaryPalAction(PalStatus status) => switch (status) {
  PalStatus.none => PalAction.request,
  PalStatus.incoming => PalAction.accept,
  PalStatus.outgoing => PalAction.withdraw,
  PalStatus.pals => PalAction.remove,
};

/// Runs a pal action for [person]: asks first where it undoes something,
/// then calls the API, refreshes counts and badges, and confirms with a toast.
/// [onStart] fires once the call is really going ahead (after any
/// confirmation), so callers show progress only then.
/// Returns false if the user cancelled or the call failed.
Future<bool> runPalAction(
  BuildContext context,
  WidgetRef ref,
  Person person,
  PalAction action, {
  bool keepSuggestions = false,
  VoidCallback? onStart,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (action == PalAction.withdraw || action == PalAction.remove) {
    final withdraw = action == PalAction.withdraw;
    final ok = await showPsSheet<bool>(
      context: context,
      title: withdraw ? l10n.withdrawPalTitle(person.fullName) : l10n.removePalTitle(person.fullName),
      subtitle: withdraw ? l10n.withdrawPalBody : l10n.removePalBody,
      builder: (ctx) => Row(
        children: [
          Expanded(
            child: PsButton(
              label: l10n.cancelLabel,
              variant: PsButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: PsButton(
              label: withdraw ? l10n.withdrawAction : l10n.removePalAction,
              variant: PsButtonVariant.danger,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;
  }

  onStart?.call();
  final api = ref.read(socialApiProvider);
  try {
    final after = switch (action) {
      PalAction.request => await api.requestPal(person.id),
      PalAction.accept => await api.acceptPal(person.id),
      PalAction.ignore => await api.ignorePal(person.id),
      PalAction.withdraw || PalAction.remove => await api.endPal(person.id),
    };
    refreshAfterPalChange(ref, person.id, keepSuggestions: keepSuggestions);
    final toast = switch (action) {
      // a request to someone who had already asked me connects us at once
      PalAction.request when after.person.palStatus == PalStatus.pals => l10n.nowPalsToast(person.fullName),
      PalAction.request => l10n.palRequestSentToast,
      PalAction.accept => l10n.nowPalsToast(person.fullName),
      PalAction.ignore => l10n.palRequestIgnoredToast,
      PalAction.withdraw => l10n.requestWithdrawnToast,
      PalAction.remove => l10n.palRemovedToast,
    };
    messenger.showSnackBar(SnackBar(content: Text(toast)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    return false;
  }
}

/// Label, icon and style for the main pal button.
(String, IconData, PsButtonVariant) palButtonStyle(AppLocalizations l10n, PalStatus status) => switch (status) {
  PalStatus.none => (l10n.addPalAction, Icons.person_add_alt_1_rounded, PsButtonVariant.primary),
  PalStatus.incoming => (l10n.acceptPalAction, Icons.check_rounded, PsButtonVariant.primary),
  PalStatus.outgoing => (l10n.palPendingAction, Icons.schedule_rounded, PsButtonVariant.secondary),
  PalStatus.pals => (l10n.palsLabel, Icons.handshake_outlined, PsButtonVariant.secondary),
};
