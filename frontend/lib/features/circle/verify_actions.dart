import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';

/// What the organizer needs to judge one recorded payment.
class PendingPayment {
  const PendingPayment({
    required this.entryId,
    required this.reference,
    required this.subjectName,
    required this.amountMinor,
    required this.cycleNumber,
    this.method,
    this.provider,
    this.receiptReference,
    this.recordedAt,
    this.actorName,
  });

  final String entryId;
  final String reference;
  final String subjectName;
  final int amountMinor;
  final int cycleNumber;
  final PaymentMethod? method;
  final String? provider;
  final String? receiptReference;
  final DateTime? recordedAt;
  final String? actorName;

  factory PendingPayment.fromItem(VerifyItem i) => PendingPayment(
        entryId: i.entryId,
        reference: i.reference,
        subjectName: i.subjectName,
        amountMinor: i.amountMinor,
        cycleNumber: i.cycleNumber,
        method: i.method,
        provider: i.provider,
        receiptReference: i.receiptReference,
        recordedAt: i.recordedAt,
        actorName: i.actorName,
      );
}

/// Evidence rows shared by the queue and the member sheet.
class PaymentEvidence extends StatelessWidget {
  const PaymentEvidence({super.key, required this.p});

  final PendingPayment p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final method = p.method == null
        ? '—'
        : [methodLabel(l10n, p.method!), if (p.provider != null) p.provider!].join(' · ');
    return Column(children: [
      PsInfoRow(label: l10n.amountLabel, value: formatLkr(p.amountMinor)),
      PsInfoRow(label: l10n.methodLabel, value: method),
      if (p.receiptReference != null) PsInfoRow(label: l10n.receiptRefLabel, value: p.receiptReference!),
      if (p.recordedAt != null) PsInfoRow(label: p.reference, value: dateTime(l10n, p.recordedAt!)),
    ]);
  }
}

Future<void> showReviewPaymentSheet(BuildContext context, {required String circleId, required PendingPayment p}) {
  final l10n = AppLocalizations.of(context);
  return showPsSheet<void>(
    context: context,
    title: '${p.subjectName} · ${p.reference}',
    subtitle: [l10n.cycleLabel(p.cycleNumber), if (p.actorName != null) l10n.recordedBy(p.actorName!)].join(' · '),
    builder: (_) => _ReviewBody(circleId: circleId, p: p),
  );
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({required this.circleId, required this.p});

  final String circleId;
  final PendingPayment p;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(circlesApiProvider).verify(widget.circleId, widget.p.entryId);
      refreshCircle(ref, widget.circleId);
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.verifiedToast(widget.p.reference))));
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PaymentEvidence(p: widget.p),
      if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
      const SizedBox(height: 16),
      PsButton(label: l10n.verifyShort, icon: Icons.check_rounded, loading: _busy, onPressed: _verify),
      const SizedBox(height: 12),
      PsButton(
        label: l10n.rejectAction,
        variant: PsButtonVariant.secondary,
        icon: Icons.undo_rounded,
        onPressed: _busy
            ? null
            : () {
                final nav = Navigator.of(context);
                nav.pop();
                showRejectSheet(nav.context, circleId: widget.circleId, p: widget.p);
              },
      ),
    ]);
  }
}

Future<void> showRejectSheet(BuildContext context, {required String circleId, required PendingPayment p}) {
  final l10n = AppLocalizations.of(context);
  return showPsSheet<void>(
    context: context,
    title: l10n.rejectTitle(p.reference),
    subtitle: l10n.rejectBody,
    builder: (_) => _RejectBody(circleId: circleId, p: p),
  );
}

class _RejectBody extends ConsumerStatefulWidget {
  const _RejectBody({required this.circleId, required this.p});

  final String circleId;
  final PendingPayment p;

  @override
  ConsumerState<_RejectBody> createState() => _RejectBodyState();
}

class _RejectBodyState extends ConsumerState<_RejectBody> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(circlesApiProvider).reject(widget.circleId, widget.p.entryId, _reason.text.trim());
      refreshCircle(ref, widget.circleId);
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.rejectedToast(widget.p.reference))));
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PsTextField(
          label: l10n.rejectReasonLabel,
          hint: l10n.rejectReasonHint,
          controller: _reason,
          maxLength: 200,
          textInputAction: TextInputAction.done,
          validator: (v) => (v ?? '').trim().length < 2 ? l10n.errReason : null,
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
        const SizedBox(height: 20),
        PsButton(label: l10n.rejectAction, variant: PsButtonVariant.danger, loading: _busy, onPressed: _reject),
        const SizedBox(height: 12),
        PsButton(
          label: l10n.cancelLabel,
          variant: PsButtonVariant.secondary,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }
}

/// U-02: closing names the unpaid members and needs an explicit tick.
Future<void> showCloseCycleSheet(BuildContext context, {required CircleDetail detail}) {
  final l10n = AppLocalizations.of(context);
  final current = detail.current!;
  return showPsSheet<void>(
    context: context,
    title: l10n.closeCycle(current.number),
    subtitle: l10n.closeCycleBody(
      detail.memberById(detail.cycles.firstWhere((c) => c.number == current.number).recipientUserId ?? '')?.displayName ??
          '',
      formatMinor(current.totals.verified.totalMinor),
      current.totals.verified.count,
    ),
    builder: (_) => _CloseBody(detail: detail),
  );
}

class _CloseBody extends ConsumerStatefulWidget {
  const _CloseBody({required this.detail});

  final CircleDetail detail;

  @override
  ConsumerState<_CloseBody> createState() => _CloseBodyState();
}

class _CloseBodyState extends ConsumerState<_CloseBody> {
  bool _ack = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.detail.current!;
    final unpaid = current.members.where((m) => current.totals.unpaidUserIds.contains(m.userId)).toList();
    final awaiting = current.totals.awaiting.count;
    final canClose = awaiting == 0 && (unpaid.isEmpty || _ack);

    Future<void> close() async {
      final nav = Navigator.of(context);
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await ref.read(circlesApiProvider).closeCycle(widget.detail.id, current.number, acknowledgeUnpaid: unpaid.length);
        refreshCircle(ref, widget.detail.id);
        nav.pop();
      } catch (e) {
        if (mounted) setState(() => _error = messageFor(l10n, e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (awaiting > 0) ErrorBanner(l10n.errPendingVerifications),
      if (unpaid.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(l10n.closeUnpaidList, style: Theme.of(context).textTheme.bodyMedium),
        ),
        for (final m in unpaid)
          PsListRow(
            icon: Icons.person_off_rounded,
            title: m.displayName,
            subtitle: l10n.legendUnpaid,
          ),
        CheckboxListTile(
          value: _ack,
          onChanged: awaiting > 0 ? null : (v) => setState(() => _ack = v ?? false),
          title: Text(l10n.closeAcknowledge(unpaid.length)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.forest600,
          contentPadding: EdgeInsets.zero,
        ),
      ],
      if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
      const SizedBox(height: 16),
      PsButton(label: l10n.closeConfirm, loading: _busy, onPressed: canClose ? close : null),
      const SizedBox(height: 12),
      PsButton(
        label: l10n.cancelLabel,
        variant: PsButtonVariant.secondary,
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
    ]);
  }
}
