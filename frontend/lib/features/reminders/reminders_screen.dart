import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/reminders/reminders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_section.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import '../shell/async_states.dart';

const _dayChoices = [7, 3, 1, 0];

/// Reminder settings for one circle. Everything starts off; "3 days before"
/// is suggested but never ticked for the member (U-06).
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool? _enabled;
  Set<int> _days = {};
  Set<String> _channels = {};
  bool _busy = false;
  String? _error;

  void _load(ReminderPreferences p) {
    if (_enabled != null) return;
    _enabled = p.enabled;
    _days = p.daysBefore.toSet();
    _channels = p.channels.toSet();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_enabled! && _days.isEmpty) {
      setState(() => _error = l10n.reminderChooseDay);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(remindersApiProvider)
          .set(
            widget.circleId,
            enabled: _enabled!,
            daysBefore: _days.toList(),
            channels: _enabled! ? _channels.toList() : const [],
          );
      ref.invalidate(reminderPreferencesProvider(widget.circleId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.remindersSavedToast)));
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dayLabel(AppLocalizations l10n, int d) => d == 0 ? l10n.reminderOnTheDay : l10n.reminderDaysBefore(d);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(reminderPreferencesProvider(widget.circleId));
    final prefs = async.value;
    if (prefs != null) _load(prefs);
    final on = _enabled ?? false;

    Widget tick({required String label, required bool value, required ValueChanged<bool> onChanged, String? note}) =>
        // ListTile paints on the nearest Material; the page sheet is a ColoredBox
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: value,
            onChanged: on ? (v) => onChanged(v ?? false) : null,
            title: Text(label, style: AppText.label),
            subtitle: note == null ? null : Text(note, style: AppText.caption),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.forest700,
          ),
        );

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.remindersTitle, backLabel: l10n.backLabel),
        children: [
          if (prefs == null && async.hasError)
            SheetError(error: async.error!, onRetry: () => ref.invalidate(reminderPreferencesProvider(widget.circleId)))
          else if (prefs == null)
            const SheetLoading()
          else ...[
            Text(l10n.remindersIntro, style: AppText.body),
            const SizedBox(height: AppSpace.l),
            PsCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: SwitchListTile(
                value: on,
                onChanged: (v) => setState(() => _enabled = v),
                title: Text(l10n.remindersSwitch, style: AppText.headline),
                subtitle: Text(on ? l10n.remindersOn : l10n.remindersOff, style: AppText.footnote),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.forest700,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            PsSectionHeader(title: l10n.remindersWhen),
            for (final d in _dayChoices)
              tick(
                label: _dayLabel(l10n, d),
                value: _days.contains(d),
                note: prefs.suggestedDaysBefore.contains(d) ? l10n.reminderSuggested : null,
                onChanged: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
              ),
            const SizedBox(height: AppSpace.l),
            PsSectionHeader(title: l10n.remindersHow),
            Text(l10n.remindersInAppAlways, style: AppText.footnote),
            tick(
              label: l10n.reminderBySms,
              value: _channels.contains('sms'),
              onChanged: (v) => setState(() => v ? _channels.add('sms') : _channels.remove('sms')),
            ),
            tick(
              label: l10n.reminderByEmail,
              value: _channels.contains('email'),
              note: prefs.emailVerified ? null : l10n.reminderEmailNeedsVerify,
              onChanged: (v) {
                if (!prefs.emailVerified) return;
                setState(() => v ? _channels.add('email') : _channels.remove('email'));
              },
            ),
            if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
            const SizedBox(height: AppSpace.xxl),
            PsButton(label: l10n.saveReminders, onPressed: _save, loading: _busy),
          ],
        ],
      ),
    );
  }
}
