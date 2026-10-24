import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/installments.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'bill_model.dart';
import 'payment_history_page.dart';

/// Balance & Dues: the live balance, totals, and the current term's
/// installment plan. Transaction history lives on Payment History.
/// Data from /student/bill.
class BillPage extends ConsumerStatefulWidget {
  const BillPage({super.key});

  @override
  ConsumerState<BillPage> createState() => _BillPageState();
}

class _BillPageState extends ConsumerState<BillPage> {
  @override
  void initState() {
    super.initState();
    // First fetch once, after mount — not in build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(billProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billProvider);
    return PageScaffold(
      title: 'Balance & Dues',
      onRefresh: () => ref.read(billProvider.notifier).load(force: true),
      body: ResourceBody<BillData>(
        state: state,
        loadingLabel: 'Loading your balance…',
        onRetry: () => ref.read(billProvider.notifier).load(force: true),
        builder: (d) => _Content(d),
      ),
    );
  }
}

/// Thousands separator, compiled once.
final _thousands = RegExp(r'(\d)(?=(\d{3})+$)');

String bdt(double? v, {bool signed = false}) {
  if (v == null) return '—';
  final neg = v < 0;
  final n = v.abs();
  final s = n.toStringAsFixed(0).replaceAllMapped(_thousands, (m) => '${m[1]},');
  final sign = signed && neg ? '-' : '';
  return '$sign৳ $s';
}

class _Content extends StatelessWidget {
  final BillData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    final groups = d.byTrimester;
    // Current-term tuition + trimester fee = the CHARGE rows of the most recent
    // trimester (not payments, not waiver adjustments).
    final currentTerm = d.currentTrimester;
    final currentFee = currentTerm == null
        ? 0.0
        : (groups[currentTerm] ?? const [])
            .where((i) => i.kind == BillKind.charge)
            .fold<double>(0, (s, i) => s + (i.amount ?? 0));

    final left = Stacked(children: [
      _BalancePanel(d),
      if (currentFee > 0) _InstallmentSection(fee: currentFee, term: currentTerm),
    ]);
    final right = Stacked(children: [
      if (d.paymentMethods.isNotEmpty) _PaymentMethodsSection(d.paymentMethods),
      const _HistoryLink(),
    ]);

    return TwoColumn(left: left, right: right, ratio: 0.58);
  }
}

/// The balance figure with the account totals beneath it.
class _BalancePanel extends StatelessWidget {
  final BillData d;
  const _BalancePanel(this.d);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasDue = d.hasDue;
    final balance = d.balance ?? 0;
    final figureColor = hasDue ? p.warningInk : p.successInk;

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasDue ? 'Amount due' : 'Current balance',
                    style: context.text.labelMedium
                        ?.copyWith(color: context.scheme.onSurfaceVariant)),
                const SizedBox(height: Spacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(hasDue ? bdt(balance) : 'Clear',
                            style: context.text.displaySmall?.copyWith(
                                color: figureColor,
                                fontFeatures: tabularFigures)),
                      ),
                    ),
                    if (!hasDue && balance < 0) ...[
                      const SizedBox(width: Spacing.sm),
                      Text('${bdt(balance, signed: true)} advance',
                          style: context.text.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          StatStrip(bordered: false, items: [
            StatBlock(label: 'Total billed', value: bdt(d.totalBilled)),
            StatBlock(label: 'Total paid', value: bdt(d.totalPaid)),
            StatBlock(
                label: 'Waived',
                value: d.totalDiscount != null && d.totalDiscount != 0
                    ? bdt(d.totalDiscount!.abs())
                    : '—'),
          ]),
        ],
      ),
    );
  }
}

/// Installment breakdown for the current term's tuition + trimester fee
/// (40/70/100 with a ৳500 fine each; +৳20k registration for 252+ students).
class _InstallmentSection extends StatelessWidget {
  final double fee;
  final String? term;
  const _InstallmentSection({required this.fee, this.term});

  @override
  Widget build(BuildContext context) {
    final plan = buildInstallmentPlan(fee, is252OrLater: true);
    return Section(
      title: 'Installment plan',
      trailing: term != null ? Text(term!) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tuition + trimester fee: ${bdt(fee)}',
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          if (plan.registrationPayment > 0)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xxs),
              child: Text(
                  'Includes ${bdt(plan.registrationPayment)} paid at registration',
                  style: context.text.bodySmall),
            ),
          const SizedBox(height: Spacing.md),
          RowGroup(
            children: [
              for (final inst in plan.installments) _InstallmentRow(inst),
            ],
          ),
          const SizedBox(height: Spacing.md),
          const InfoNote(
            tone: StatusTone.warning,
            icon: AppIcons.warning,
            text: 'A ৳500 fine applies per installment missed by its deadline. '
                'Dates are set by UCAM each term.',
          ),
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final Installment inst;
  const _InstallmentRow(this.inst);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final ordinal = ['1st', '2nd', '3rd'][inst.number - 1];
    final when = inst.dateLabel != null
        ? ' · by ${inst.dateLabel}'
        : ' · date set by UCAM';
    return ListRow(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Text('${inst.cumulativePercent.toStringAsFixed(0)}%',
            style: context.text.labelMedium
                ?.copyWith(fontFeatures: tabularFigures)),
      ),
      title: '$ordinal installment',
      subtitle: 'Pay up to ${bdt(inst.cumulativeAmount)} total$when',
      value: inst.thisInstallment > 0 ? '+${bdt(inst.thisInstallment)}' : null,
      chevron: false,
    );
  }
}

/// The online-payment methods UCAM accepts — informational only; paying happens
/// on UCAM's own payment page.
class _PaymentMethodsSection extends StatelessWidget {
  final List<PaymentMethod> methods;
  const _PaymentMethodsSection(this.methods);

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Pay online',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UCAM accepts these payment methods:',
              style: context.text.bodySmall),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final m in methods) StatusBadge(m.name, outlined: true),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'To pay, open the payment page on UCAM. Open Campus never handles '
            'your payment or card details.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Link to the separate Payment History page.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink();

  @override
  Widget build(BuildContext context) {
    return RowGroup(
      children: [
        ListRow(
          icon: AppIcons.payments,
          title: 'Payment history',
          subtitle: 'All bills and payments, by trimester',
          onTap: () => Navigator.of(context)
              .push(appRoute(const PaymentHistoryPage())),
        ),
      ],
    );
  }
}
