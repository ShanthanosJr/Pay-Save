import 'package:flutter/material.dart';
import '../../../core/validation/input_formatters.dart';
import '../../../core/widgets/ps_picker_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validation/validators.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_text_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../register_draft.dart';
import '../widgets/auth_scaffold.dart';

class RegisterDetailsScreen extends ConsumerStatefulWidget {
  const RegisterDetailsScreen({super.key});

  @override
  ConsumerState<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends ConsumerState<RegisterDetailsScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(registerDraftProvider).fullName);
  late final _age = TextEditingController(
    text: ref.read(registerDraftProvider).age == 0 ? '' : '${ref.read(registerDraftProvider).age}',
  );
  late final _nic = TextEditingController(text: ref.read(registerDraftProvider).nic);

  /// The age shown was worked out from the ID number, not picked.
  bool _ageFromNic = false;

  @override
  void initState() {
    super.initState();
    _nic.addListener(_fillAgeFromNic);
  }

  /// Both NIC formats carry the date of birth, so a valid number fills the
  /// age in. The member can still change it.
  void _fillAgeFromNic() {
    final age = ageFromNic(_nic.text);
    if (age == null || age < 18 || age > 100) return;
    if (_age.text.isNotEmpty && !_ageFromNic) return;
    if (_age.text == '$age') return;
    _age.text = '$age';
    setState(() => _ageFromNic = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _nic.dispose();
    super.dispose();
  }

  void _next() {
    if (!_form.currentState!.validate()) return;
    ref.read(registerDraftProvider.notifier).update((d) => d.copyWith(
          fullName: _name.text.trim(),
          age: int.parse(_age.text.trim()),
          nic: _nic.text.trim().toUpperCase(),
        ));
    context.go('/register/phone');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = Validators(l10n);

    return AuthScaffold(
      titlePlain: l10n.regDetailsTitlePlain,
      titleAccent: l10n.regDetailsTitleAccent,
      subtitle: l10n.regDetailsSubtitle,
      stepLabel: l10n.registerStep(1, 3),
      step: 1,
      totalSteps: 3,
      onBack: () => context.go('/'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PsTextField(
              label: l10n.fullNameLabel,
              hint: l10n.fullNameHint,
              controller: _name,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              validator: v.fullName,
            ),
            const SizedBox(height: 16),
            PsTextField(
              label: l10n.nicLabel,
              hint: l10n.nicHint,
              controller: _nic,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              inputFormatters: [NicInputFormatter()],
              validator: v.nic,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: 16),
            PsPickerField<int>(
              label: l10n.ageLabel,
              hint: l10n.agePickerHint,
              helper: _ageFromNic ? l10n.ageFromNic : null,
              sheetTitle: l10n.agePickerTitle,
              controller: _age,
              options: [for (var a = 18; a <= 100; a++) a],
              optionLabel: l10n.ageYears,
              validator: v.age,
              onPicked: (_) => setState(() => _ageFromNic = false),
            ),
            const SizedBox(height: 32),
            PsButton(label: l10n.continueLabel, onPressed: _next, trailingIcon: Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}
