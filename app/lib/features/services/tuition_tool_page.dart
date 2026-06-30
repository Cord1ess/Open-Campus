import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/tuition.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../finance/bill_model.dart';
import 'tool_scaffold.dart';

/// Tuition Fee Tool — Auto (your real UCAM bill) + Manual (estimate from inputs,
/// ported from the reference calculator).
class TuitionToolPage extends ConsumerStatefulWidget {
  const TuitionToolPage({super.key});

  @override
  ConsumerState<TuitionToolPage> createState() => _TuitionToolPageState();
}

class _TuitionToolPageState extends ConsumerState<TuitionToolPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(billProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Tuition Fee Tool',
      builder: (context, mode) => mode == ToolMode.auto
          ? const _AutoTuition()
          : const _ManualTuition(),
    );
  }
}

// ===========================================================================
// AUTO — the student's real billed breakdown from UCAM.
// ===========================================================================
class _AutoTuition extends ConsumerWidget {
  const _AutoTuition();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billProvider);
    return switch (state) {
      ResLoading() => const CardSkeleton(lines: 8),
      ResError(:final message) => StateMessage(
          icon: Icons.cloud_off,
          title: 'Couldn’t load your bill',
          subtitle: message,
          actionLabel: 'Try again',
          onAction: () => ref.read(billProvider.notifier).load(force: true),
        ),
      ResData(:final loaded) => _AutoTuitionBody(loaded.data),
    };
  }
}

class _AutoTuitionBody extends StatelessWidget {
  final BillData bill;
  const _AutoTuitionBody(this.bill);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final billed = bill.totalBilled ?? 0;
    final discount = bill.totalDiscount ?? 0;
    final paid = bill.totalPaid ?? 0;
    final balance = bill.balance ?? 0;
    final term = bill.currentTrimester;

    // Current-trimester fee lines (charges only, not payments).
    final termItems = term == null
        ? <BillItem>[]
        : bill.items
            .where((i) => i.trimester == term && !i.isPayment)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataUsedPanel(rows: [
          ('Total billed (all trimesters)', formatBdt(billed)),
          ('Total discount', formatBdt(discount)),
          ('Total paid', formatBdt(paid)),
          (balance >= 0 ? 'Outstanding balance' : 'Advance balance',
              formatBdt(balance.abs())),
          if (term != null) ('Current trimester', term),
        ]),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          child: SectionCard(
            title: 'Account summary',
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
              children: [
                _row(context, 'Total billed', formatBdt(billed)),
                if (discount > 0)
                  _row(context, 'Discounts / waivers', '−${formatBdt(discount)}',
                      color: context.status.good),
                _row(context, 'Total paid', formatBdt(paid)),
                Divider(height: Spacing.xl, color: scheme.outlineVariant),
                _row(
                  context,
                  balance > 0
                      ? 'Outstanding due'
                      : balance < 0
                          ? 'Advance / credit'
                          : 'Cleared',
                  formatBdt(balance.abs()),
                  bold: true,
                  color: balance > 0 ? context.status.bad : scheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (termItems.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 60,
            child: SectionCard(
              title: 'This trimester’s charges',
              icon: Icons.receipt_long_outlined,
              trailing: term != null
                  ? Text(term,
                      style: context.text.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant))
                  : null,
              child: Column(
                children: [
                  for (var i = 0; i < termItems.length; i++) ...[
                    if (i > 0)
                      Divider(height: Spacing.lg, color: scheme.outlineVariant),
                    _BillRow(termItems[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        _note(context,
            'This is your actual UCAM bill — the real figures, not an estimate. '
            'For a what-if estimate (different credits, waiver, scholarship), '
            'switch to Manual.'),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: context.text.bodyMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                    fontWeight: bold ? FontWeight.w700 : null)),
          ),
          Text(value,
              style: (bold ? context.text.titleMedium : context.text.bodyMedium)
                  ?.copyWith(
                      color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _note(BuildContext context, String text) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.primary),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text,
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final BillItem item;
  const _BillRow(this.item);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final net = (item.amount ?? 0) - (item.discount ?? 0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.feeType ?? item.courseCode ?? 'Fee',
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (item.courseCode != null && item.feeType != null)
                Text(
                    '${item.courseCode}${item.credit != null ? ' · ${item.credit!.toStringAsFixed(1)} cr' : ''}',
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatBdt(net),
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if ((item.discount ?? 0) > 0)
              Text('−${formatBdt(item.discount!)}',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.status.good)),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// MANUAL — estimate from inputs (port of the reference calculator).
// ===========================================================================
class _ManualTuition extends StatefulWidget {
  const _ManualTuition();

  @override
  State<_ManualTuition> createState() => _ManualTuitionState();
}

class _ManualTuitionState extends State<_ManualTuition> {
  final _newCr = TextEditingController();
  final _retake1Cr = TextEditingController();
  final _retakeRegCr = TextEditingController();
  final _perCredit = TextEditingController(text: '6500');
  final _trimFee = TextEditingController(text: '6500');
  double _waiver = 0;
  double _scholarship = 0;
  bool _late = false;
  bool _waiverFirst = false;

  @override
  void dispose() {
    for (final c in [_newCr, _retake1Cr, _retakeRegCr, _perCredit, _trimFee]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final input = TuitionInput(
      newCredits: _num(_newCr),
      retakeFirstCredits: _num(_retake1Cr),
      retakeRegularCredits: _num(_retakeRegCr),
      perCreditFee: _num(_perCredit),
      trimesterFee: _num(_trimFee),
      waiverPercent: _waiver,
      scholarshipPercent: _scholarship,
      lateRegistration: _late,
      waiverInFirstInstallment: _waiverFirst,
    );
    final hasCredits = input.newCredits > 0 ||
        input.retakeFirstCredits > 0 ||
        input.retakeRegularCredits > 0;
    final r = calculateTuition(input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: SectionCard(
            title: 'Your courses',
            icon: Icons.menu_book_outlined,
            child: Column(
              children: [
                _field(_newCr, 'New course credits', Icons.add_circle_outline),
                const SizedBox(height: Spacing.md),
                _field(_retake1Cr, 'Retake credits (1st time, 50% off)',
                    Icons.replay_outlined),
                const SizedBox(height: Spacing.md),
                _field(_retakeRegCr, 'Retake credits (2nd+ time)',
                    Icons.repeat_outlined),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 60,
          child: SectionCard(
            title: 'Fees & discounts',
            icon: Icons.percent_outlined,
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _field(_perCredit, 'Per-credit fee', null)),
                  const SizedBox(width: Spacing.md),
                  Expanded(child: _field(_trimFee, 'Trimester fee', null)),
                ]),
                const SizedBox(height: Spacing.md),
                _percentRow('Waiver', _waiver, (v) => setState(() => _waiver = v)),
                const SizedBox(height: Spacing.sm),
                _percentRow('Scholarship', _scholarship,
                    (v) => setState(() => _scholarship = v)),
                const SizedBox(height: Spacing.xs),
                Text(
                    'Scholarship applies to your first 13 credits; any extra '
                    'credits use the waiver rate.',
                    style: context.text.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant)),
                const SizedBox(height: Spacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _late,
                  onChanged: (v) => setState(() => _late = v),
                  title: const Text('Late registration (+500৳)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _waiverFirst,
                  onChanged: (v) => setState(() => _waiverFirst = v),
                  title: const Text('Apply waiver in 1st installment'),
                  subtitle: const Text('1st installment = 40% of net (not gross)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        if (hasCredits)
          FadeSlideIn(delayMs: 120, child: _ResultCard(r))
        else
          _hint(context, 'Enter your credits above to see the estimate.'),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, IconData? icon) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }

  Widget _percentRow(String label, double value, ValueChanged<double> onChanged) {
    final scheme = context.scheme;
    return Row(
      children: [
        SizedBox(
            width: 96,
            child: Text(label,
                style: context.text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant))),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${value.toStringAsFixed(0)}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('${value.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: context.text.labelLarge?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _hint(BuildContext context, String text) => Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 18, color: context.scheme.primary),
          const SizedBox(width: Spacing.sm),
          Expanded(
              child: Text(text,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant))),
        ]),
      );
}

class _ResultCard extends StatelessWidget {
  final TuitionResult r;
  const _ResultCard(this.r);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Estimated payable',
      icon: Icons.calculate_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(formatBdt(r.netPayable),
            style: context.text.labelLarge?.copyWith(
                color: onAccent(scheme.primary), fontWeight: FontWeight.w800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(context, 'New course tuition', formatBdt(r.newTuition)),
          if (r.retakeFirstTuition > 0)
            _line(context, 'Retake (1st time)', formatBdt(r.retakeFirstTuition)),
          if (r.retakeRegularTuition > 0)
            _line(context, 'Retake (2nd+ time)',
                formatBdt(r.retakeRegularTuition)),
          _line(context, 'Trimester / admin fee', formatBdt(r.adminFees)),
          Divider(height: Spacing.lg, color: scheme.outlineVariant),
          _line(context, 'Gross total', formatBdt(r.grossTotal)),
          for (final d in r.discounts)
            _line(context, d.label, '−${formatBdt(d.amount)}',
                color: context.status.good, sub: d.description),
          Divider(height: Spacing.lg, color: scheme.outlineVariant),
          _line(context, 'Net payable', formatBdt(r.netPayable),
              bold: true, color: scheme.primary),
          const SizedBox(height: Spacing.lg),
          Text('Installments',
              style: context.text.labelMedium?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(r.installmentMethod,
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.sm),
          _installment(context, '1st', r.firstInstallment),
          _installment(context, '2nd', r.secondInstallment),
          _installment(context, '3rd', r.thirdInstallment),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value,
      {bool bold = false, Color? color, String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.text.bodyMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                        fontWeight: bold ? FontWeight.w700 : null)),
                if (sub != null)
                  Text(sub,
                      style: context.text.labelSmall
                          ?.copyWith(color: context.scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(value,
              style: (bold ? context.text.titleMedium : context.text.bodyMedium)
                  ?.copyWith(
                      color: color,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _installment(BuildContext context, String label, double amount) {
    final scheme = context.scheme;
    final zero = amount <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: zero
                  ? scheme.surfaceContainerHighest
                  : scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(label,
                style: context.text.labelSmall?.copyWith(
                    color: zero ? scheme.onSurfaceVariant : scheme.primary,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
              child: Text('$label installment',
                  style: context.text.bodyMedium?.copyWith(
                      color: zero ? scheme.onSurfaceVariant : null))),
          Text(formatBdt(amount),
              style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: zero ? scheme.onSurfaceVariant : null)),
        ],
      ),
    );
  }
}
