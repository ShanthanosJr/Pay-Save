import 'package:flutter/material.dart';
import '../../core/widgets/ps_picker_field.dart';
import '../../core/validation/input_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../auth/widgets/error_banner.dart';
import 'circle_setup.dart' show CollectionModeExplainer;

/// FR-04: create a circle in three steps; the turn rule is asked once (U-03).
class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _members = TextEditingController(text: '6');
  int _step = 1;
  CircleInterval _interval = CircleInterval.monthly;
  TurnRule _rule = TurnRule.fixed;
  CollectionMode _mode = CollectionMode.directToRecipient;
  late DateTime _firstDue = DateTime.now().add(const Duration(days: 30));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _members.dispose();
    super.dispose();
  }

  int get _amountMinor => RupeeInputFormatter.parse(_amount.text) * 100;
  int get _memberCount => int.tryParse(_members.text.trim()) ?? 0;

  void _next() {
    final form = _step == 1 ? _form1 : _form2;
    if (!form.currentState!.validate()) return;
    setState(() => _step++);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ref.read(circlesApiProvider).create(
            name: _name.text.trim(),
            contributionMinor: _amountMinor,
            interval: _interval,
            turnRule: _rule,
            collectionMode: _mode,
            plannedCycles: _memberCount,
            firstDueDate: _firstDue,
          );
      ref.read(selectedCircleIdProvider.notifier).select(d.id);
      refreshCircle(ref, d.id);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      titlePlain: l10n.createTitlePlain,
      titleAccent: l10n.createTitleAccent,
      subtitle: l10n.createSubtitle,
      stepLabel: l10n.registerStep(_step, 3),
      step: _step,
      totalSteps: 3,
      onBack: () => _step == 1 ? context.pop() : setState(() => _step--),
      child: AnimatedSwitcher(
        duration: AppMotion.medium,
        switchInCurve: AppMotion.curve,
        child: KeyedSubtree(key: ValueKey(_step), child: switch (_step) {
          1 => _stepOne(l10n),
          2 => _stepTwo(l10n),
          _ => _stepThree(l10n),
        }),
      ),
    );
  }

  Widget _stepOne(AppLocalizations l10n) => Form(
        key: _form1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PsTextField(
            label: l10n.circleNameLabel,
            hint: l10n.circleNameHint,
            controller: _name,
            maxLength: 60,
            validator: (v) => (v ?? '').trim().length < 2 ? l10n.errRequired : null,
          ),
          const SizedBox(height: 16),
          PsTextField(
            label: l10n.contributionAmountLabel,
            hint: l10n.amountHint,
            controller: _amount,
            prefixText: 'LKR ',
            keyboardType: TextInputType.number,
            inputFormatters: [RupeeInputFormatter()],
            textInputAction: TextInputAction.done,
            validator: (v) {
              final n = RupeeInputFormatter.parse(v ?? '');
              return n < 1 || n > 1000000 ? l10n.errAmount : null;
            },
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 32),
          PsButton(label: l10n.continueLabel, trailingIcon: Icons.arrow_forward_rounded, onPressed: _next),
        ]),
      );

  Widget _stepTwo(AppLocalizations l10n) => Form(
        key: _form2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PsGroupLabel(l10n.intervalLabel),
          PsSegmented<CircleInterval>(
            segments: [
              for (final i in CircleInterval.values) (i, intervalLabel(l10n, i)),
            ],
            selected: _interval,
            onChanged: (i) => setState(() => _interval = i),
          ),
          const SizedBox(height: 20),
          PsPickerField<int>(
            label: l10n.membersCountLabel,
            sheetTitle: l10n.membersPickerTitle,
            controller: _members,
            options: [for (var n = 2; n <= 60; n++) n],
            optionLabel: l10n.membersOption,
            onPicked: (_) => setState(() {}),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim()) ?? 0;
              return n < 2 || n > 60 ? l10n.errMembersCount : null;
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l10n.membersCountHelp, style: AppText.caption),
          ),
          const SizedBox(height: 20),
          PsGroupLabel(l10n.firstDueLabel),
          PsListRow(
            icon: Icons.event_rounded,
            title: longDate(l10n, _firstDue),
            showChevron: true,
            onTap: _pickDate,
          ),
          const SizedBox(height: 24),
          PsButton(label: l10n.continueLabel, trailingIcon: Icons.arrow_forward_rounded, onPressed: _next),
        ]),
      );

  Widget _stepThree(AppLocalizations l10n) {
    final rules = [
      (TurnRule.fixed, Icons.format_list_numbered_rounded, l10n.turnRuleFixedHelp),
      (TurnRule.lottery, Icons.casino_rounded, l10n.turnRuleLotteryHelp),
      (TurnRule.needBased, Icons.volunteer_activism_rounded, l10n.turnRuleNeedHelp),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PsGroupLabel(l10n.turnRuleLabel),
      for (final (rule, icon, help) in rules)
        Semantics(
          selected: _rule == rule,
          inMutuallyExclusiveGroup: true,
          child: PsListRow(
            icon: icon,
            tone: _rule == rule ? PsBadgeTone.forest : PsBadgeTone.neutral,
            title: turnRuleLabel(l10n, rule),
            subtitle: help,
            onTap: () => setState(() => _rule = rule),
            trailing: Icon(
              _rule == rule ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: _rule == rule ? AppColors.forest600 : AppColors.strokeStrong,
            ),
          ),
        ),
      const SizedBox(height: 12),
      PsGroupLabel(l10n.whoCollectsTitle),
      PsSegmented<CollectionMode>(
        segments: [
          (CollectionMode.directToRecipient, l10n.modeDirect),
          (CollectionMode.viaOrganizer, l10n.modeViaOrganizer),
        ],
        selected: _mode,
        onChanged: (m) => setState(() => _mode = m),
      ),
      const SizedBox(height: 8),
      CollectionModeExplainer(mode: _mode),
      const SizedBox(height: 12),
      PsArithmeticRow(
        summary: l10n.createSummary(
          _memberCount - 1,
          formatMinor(_amountMinor),
          formatMinor((_memberCount - 1) * _amountMinor),
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 16), ErrorBanner(_error!)],
      const SizedBox(height: 28),
      PsButton(label: l10n.createCta, icon: Icons.check_rounded, loading: _busy, onPressed: _create),
    ]);
  }
}
