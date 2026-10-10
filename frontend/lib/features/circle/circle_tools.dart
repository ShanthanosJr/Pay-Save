import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/reminders/reminders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';

/// Per-circle extras: reminders, statement, privacy, and member management.
class CircleTools extends ConsumerWidget {
  const CircleTools({super.key, required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    final started = s.status != CircleStatus.draft;
    final others = detail.members.where((m) => m.role != CircleRole.organizer).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.xxxl),
        PsSectionHeader(title: l10n.circleToolsTitle),
        if (s.status == CircleStatus.active)
          PsListRow(
            icon: Icons.alarm_rounded,
            tone: PsBadgeTone.mint,
            title: l10n.remindersTitle,
            subtitle: l10n.remindersRowHint,
            showChevron: true,
            onTap: () => context.push('/circles/${s.id}/reminders'),
          ),
        if (started)
          PsListRow(
            icon: Icons.verified_user_rounded,
            tone: PsBadgeTone.mint,
            title: l10n.statementTitle,
            subtitle: l10n.statementRowHint,
            showChevron: true,
            onTap: () => context.push('/circles/${s.id}/statement'),
          ),
        PsListRow(
          icon: Icons.shield_rounded,
          tone: PsBadgeTone.mint,
          title: l10n.sharingTitle,
          subtitle: l10n.sharingRowHint,
          showChevron: true,
          onTap: () => context.push('/circles/${s.id}/sharing'),
        ),
        if (s.isOrganizer && others.isNotEmpty && s.status != CircleStatus.completed)
          PsListRow(
            icon: Icons.manage_accounts_rounded,
            tone: PsBadgeTone.neutral,
            title: l10n.manageMembersTitle,
            subtitle: l10n.manageMembersHint,
            showChevron: true,
            onTap: () => showManageMembersSheet(context, ref, detail),
          ),
        if (!s.isOrganizer && s.status == CircleStatus.draft)
          PsListRow(
            icon: Icons.logout_rounded,
            tone: PsBadgeTone.danger,
            title: l10n.leaveCircleAction,
            titleColor: AppColors.danger,
            onTap: () => _confirmLeave(context, ref),
          ),
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      context,
      title: l10n.leaveCircleTitle(detail.summary.name),
      body: l10n.leaveCircleBody,
      action: l10n.leaveCircleAction,
    );
    if (ok != true) return;
    try {
      await ref.read(circlesApiProvider).leave(detail.summary.id);
      ref.invalidate(myCirclesProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.leftCircleToast)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    }
  }
}

Future<bool?> _confirm(BuildContext context, {required String title, required String body, required String action}) {
  final l10n = AppLocalizations.of(context);
  return showPsSheet<bool>(
    context: context,
    title: title,
    subtitle: body,
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
          child: PsButton(label: action, variant: PsButtonVariant.danger, onPressed: () => Navigator.of(ctx).pop(true)),
        ),
      ],
    ),
  );
}

/// Organizer: remind an unpaid member, or remove a member (FR-05, FR-09).
/// [ref] belongs to the page underneath: it must outlive this sheet, which
/// closes before the removal is confirmed.
void showManageMembersSheet(BuildContext context, WidgetRef ref, CircleDetail detail) {
  final l10n = AppLocalizations.of(context);
  final s = detail.summary;
  final unpaid = {
    for (final m in detail.current?.members ?? const <CycleMemberStatus>[])
      if (m.status == ContributionStatus.due || m.status == ContributionStatus.overdue) m.userId,
  };
  showPsSheet<void>(
    context: context,
    title: l10n.manageMembersTitle,
    subtitle: s.status == CircleStatus.draft ? l10n.manageMembersDraftBody : l10n.manageMembersActiveBody,
    builder: (ctx) {
      final messenger = ScaffoldMessenger.of(context);

      Future<void> nudge(CircleMember m) async {
        try {
          await ref.read(remindersApiProvider).nudge(s.id, m.userId);
          messenger.showSnackBar(SnackBar(content: Text(l10n.nudgeSentToast(m.displayName))));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
        }
      }

      Future<void> remove(CircleMember m) async {
        Navigator.of(ctx).pop();
        String? reason;
        if (s.status == CircleStatus.draft) {
          final ok = await _confirm(
            context,
            title: l10n.removeMemberTitle(m.displayName),
            body: l10n.removeMemberDraftBody,
            action: l10n.removeMemberAction,
          );
          if (ok != true) return;
        } else {
          reason = await _askReason(context, m);
          if (reason == null) return;
        }
        try {
          await ref.read(circlesApiProvider).removeMember(s.id, m.userId, reason: reason);
          refreshCircle(ref, s.id);
          messenger.showSnackBar(SnackBar(content: Text(l10n.memberRemovedToast(m.displayName))));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
        }
      }

      return Column(
        children: [
          for (final m in detail.members.where((x) => x.role != CircleRole.organizer))
            PsListRow(
              leading: PsAvatar(name: m.displayName, size: 42),
              title: m.displayName,
              subtitle: unpaid.contains(m.userId) ? l10n.memberUnpaidThisCycle : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unpaid.contains(m.userId))
                    IconButton(
                      tooltip: l10n.sendReminderAction,
                      constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                      icon: const Icon(Icons.notifications_active_rounded, color: AppColors.forest700),
                      onPressed: () => nudge(m),
                    ),
                  IconButton(
                    tooltip: l10n.removeMemberAction,
                    constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                    icon: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                    onPressed: () => remove(m),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

Future<String?> _askReason(BuildContext context, CircleMember m) {
  final l10n = AppLocalizations.of(context);
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  return showPsSheet<String>(
    context: context,
    title: l10n.removeMemberTitle(m.displayName),
    subtitle: l10n.removeMemberActiveBody,
    builder: (ctx) => Form(
      key: form,
      child: Column(
        children: [
          PsTextField(
            label: l10n.removeReasonLabel,
            hint: l10n.removeReasonHint,
            controller: reason,
            textInputAction: TextInputAction.done,
            validator: (v) => (v ?? '').trim().length < 3 ? l10n.errRequired : null,
          ),
          const SizedBox(height: AppSpace.xl),
          PsButton(
            label: l10n.removeMemberAction,
            variant: PsButtonVariant.danger,
            onPressed: () {
              if (form.currentState!.validate()) Navigator.of(ctx).pop(reason.text.trim());
            },
          ),
        ],
      ),
    ),
  );
}
