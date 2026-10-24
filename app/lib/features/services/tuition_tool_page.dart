import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/tuition.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../finance/bill_model.dart';
import 'numeric_input.dart';
import 'tool_scaffold.dart';

/// Tuition Fee Tool — Auto (your real UCAM bill) + Manual (estimate from
/// inputs).
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
    return ResourceBody<BillData>(
      state: state,
      loadingLabel: 'Loading your bill…',
      errorTitle: 'Couldn’t load your bill',
      onRetry: () => ref.read(billProvider.notifier).load(force: true),
      builder: (d) => _AutoTuitionBody(d),
    );
  }
}

class _AutoTuitionBody extends StatelessWidget {
  final BillData bill;
  const _AutoTuitionBody(this.bill);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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

    final summary = Section(
      title: 'Account summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueRow(label: 'Total billed', value: formatBdt(billed)),
          if (discount > 0)
            KeyValueRow(
                label: 'Discounts / waivers',
                value: '−${formatBdt(discount)}',
                valueColor: p.successInk),
          KeyValueRow(label: 'Total paid', value: formatBdt(paid)),
          const Divider(height: Spacing.lg),
          KeyValueRow(
            label: balance > 0
                ? 'Outstanding due'
                : balance < 0
                    ? 'Advance / credit'
                    : 'Cleared',
            value: formatBdt(balance.abs()),
            emphasize: true,
            valueColor: balance > 0 ? p.warningInk : p.successInk,
          ),
        ],
      ),
    );

    final charges = termItems.isEmpty
        ? null
        : Section(
            title: 'This trimester’s charges',
            trailing: term != null ? Text(term) : null,
            child: RowGroup(
              children: [for (final it in termItems) _BillRow(it)],
            ),
          );

    return Stacked(
      children: [
        DataUsedPanel(rows: [
          ('Total billed (all trimesters)', formatBdt(billed)),
          ('Total discount', formatBdt(discount)),
          ('Total paid', formatBdt(paid)),
          (balance >= 0 ? 'Outstanding balance' : 'Advance balance',
              formatBdt(balance.abs())),
          if (term != null) ('Current trimester', term),
        ]),
        if (charges != null)
          ResponsiveGrid(
            maxColumns: 2,
            stretch: false,
            spacing: Spacing.xl,
            children: [summary, charges],
          )
        else
          summary,
        const InfoNote(
          text: 'This is your actual UCAM bill — the real figures, not an '
              'estimate. For a what-if estimate (different credits, waiver, '
              'scholarship), switch to Manual.',
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final BillItem item;
  const _BillRow(this.item);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final net = (item.amount ?? 0) - (item.discount ?? 0);
    final hasDiscount = (item.discount ?? 0) > 0;
    final sub = item.courseCode != null && item.feeType != null
        ? '${item.courseCode}${item.credit != null ? ' · ${item.credit!.toStringAsFixed(1)} cr' : ''}'
        : null;
    return ListRow(
      title: item.feeType ?? item.courseCode ?? 'Fee',
      subtitle: sub,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatBdt(net),
              style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600, fontFeatures: tabularFigures)),
          if (hasDiscount)
            Text('−${formatBdt(item.discount!)}',
                style: context.text.labelSmall?.copyWith(
                    color: p.successInk, fontFeatures: tabularFigures)),
        ],
      ),
    );
  }
}

// ===========================================================================
// MANUAL — estimate from inputs.
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

  // Clamp to non-negative so a stray "-" can't produce a negative fee/credit.
  double _num(TextEditingController c) => clampNonNeg(c.text) ?? 0;

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

    final inputs = Stacked(
      children: [
        Section(
          title: 'Your courses',
          child: FormWidth(
            maxWidth: 560,
            child: Column(
              children: [
                _field(_newCr, 'New course credits'),
                const SizedBox(height: Spacing.md),
                _field(_retake1Cr, 'Retake credits (1st time, 50% off)'),
                const SizedBox(height: Spacing.md),
                _field(_retakeRegCr, 'Retake credits (2nd+ time)'),
              ],
            ),
          ),
        ),
        Section(
          title: 'Fees & discounts',
          child: FormWidth(
            maxWidth: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: _field(_perCredit, 'Per-credit fee')),
                  const SizedBox(width: Spacing.md),
                  Expanded(child: _field(_trimFee, 'Trimester fee')),
                ]),
                const SizedBox(height: Spacing.lg),
                _percentRow('Waiver', _waiver, (v) => setState(() => _waiver = v)),
                _percentRow('Scholarship', _scholarship,
                    (v) => setState(() => _scholarship = v)),
                Text(
                    'Scholarship applies to your first 13 credits; any extra '
                    'credits use the waiver rate.',
                    style: context.text.bodySmall),
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
                  subtitle:
                      const Text('1st installment = 40% of net (not gross)'),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final result = hasCredits
        ? _ResultSection(r)
        : const InfoNote(
            text: 'Enter your credits above to see the estimate.');

    return TwoColumn(left: inputs, right: result, ratio: 0.5);
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: decimalInput,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _percentRow(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 96,
            child: Text(label,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.scheme.onSurfaceVariant))),
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
                  color: context.palette.accentInk,
                  fontFeatures: tabularFigures)),
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  final TuitionResult r;
  const _ResultSection(this.r);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Section(
      title: 'Estimated payable',
      trailing: StatusBadge(formatBdt(r.netPayable), tone: StatusTone.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueRow(label: 'New course tuition', value: formatBdt(r.newTuition)),
          if (r.retakeFirstTuition > 0)
            KeyValueRow(
                label: 'Retake (1st time)',
                value: formatBdt(r.retakeFirstTuition)),
          if (r.retakeRegularTuition > 0)
            KeyValueRow(
                label: 'Retake (2nd+ time)',
                value: formatBdt(r.retakeRegularTuition)),
          KeyValueRow(
              label: 'Trimester / admin fee', value: formatBdt(r.adminFees)),
          const Divider(height: Spacing.lg),
          KeyValueRow(label: 'Gross total', value: formatBdt(r.grossTotal)),
          for (final d in r.discounts) ...[
            KeyValueRow(
                label: d.label,
                value: '−${formatBdt(d.amount)}',
                valueColor: p.successInk),
            if (d.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Text(d.description, style: context.text.bodySmall),
              ),
          ],
          const Divider(height: Spacing.lg),
          KeyValueRow(
              label: 'Net payable',
              value: formatBdt(r.netPayable),
              emphasize: true,
              valueColor: p.accentInk),
          const SizedBox(height: Spacing.lg),
          Text('Installments', style: context.text.titleSmall),
          const SizedBox(height: Spacing.xxs),
          Text(r.installmentMethod, style: context.text.bodySmall),
          const SizedBox(height: Spacing.xs),
          _installment(context, '1st installment', r.firstInstallment),
          _installment(context, '2nd installment', r.secondInstallment),
          _installment(context, '3rd installment', r.thirdInstallment),
        ],
      ),
    );
  }

  Widget _installment(BuildContext context, String label, double amount) {
    final zero = amount <= 0;
    return KeyValueRow(
      label: label,
      value: formatBdt(amount),
      valueColor: zero ? context.scheme.onSurfaceVariant : null,
    );
  }
}
