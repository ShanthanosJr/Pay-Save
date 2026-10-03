import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../auth/widgets/error_banner.dart';

/// Normalises what people type or paste: spaces, dashes, lower case.
String normalizeJoinCode(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ref.read(circlesApiProvider).join(normalizeJoinCode(_code.text));
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
      titlePlain: l10n.joinTitlePlain,
      titleAccent: l10n.joinTitleAccent,
      subtitle: l10n.joinSubtitle,
      onBack: () => context.pop(),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PsTextField(
            label: l10n.joinCodeLabel,
            hint: l10n.joinCodeHint,
            controller: _code,
            maxLength: 11,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
              TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
            ],
            validator: (v) => normalizeJoinCode(v ?? '').length != 8 ? l10n.errJoinCode : null,
            onSubmitted: (_) => _join(),
          ),
          if (_error != null) ...[const SizedBox(height: 16), ErrorBanner(_error!)],
          const SizedBox(height: 32),
          PsButton(label: l10n.joinCta, icon: Icons.login_rounded, loading: _busy, onPressed: _join),
        ]),
      ),
    );
  }
}
