import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/installments.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../common/collapsing_title.dart';
import 'bill_model.dart';
import 'payment_history_page.dart';

/// Balance & Dues: the live balance/dues hero, totals, and the current term's
/// installment plan — NO transaction history (that lives on Payment History).
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
    // Kick off the first fetch once, after mount — not in build() (which would
    // re-fire on every rebuild and mutate a provider mid-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(billProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(billProvider.notifier).load(force: true),
        child: CustomScrollView(
          slivers: [
            const SliverCollapsingAppBar(title: 'Balance & Dues'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const SectionCard(
                      title: 'Balance & Dues',
                      icon: Icons.account_balance_wallet_outlined,
                      child: CardSkeleton(label: 'Loading your balance…')),
                  ResError(:final message) => StateMessage(
                      icon: Icons.cloud_off,
                      title: 'Couldn\'t load',
                      subtitle: message,
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.read(billProvider.notifier).load(force: true),
                    ),
                  ResData(:final loaded) => _Content(loaded.data),
                },
                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thousands separator, compiled once (not per call — `bdt` runs many times per
/// render of the bill page).
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
    // Current-term tuition+trimester fee = the CHARGE rows (not payments, not
    // waiver adjustments) in the most recent trimester, picked deterministically
    // (season-aware) so the installment breakdown isn't tied to backend ordering.
    final currentTerm = d.currentTrimester;
    final currentFee = currentTerm == null
        ? 0.0
        : (groups[currentTerm] ?? const [])
            .where((i) => i.kind == BillKind.charge)
            .fold<double>(0, (s, i) => s + (i.amount ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(child: _BalanceHero(d)),
        if (currentFee > 0) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 40,
            child: _InstallmentCard(fee: currentFee, term: currentTerm),
          ),
        ],
        if (d.paymentMethods.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          FadeSlideIn(
              delayMs: 80, child: _PaymentMethodsCard(d.paymentMethods)),
        ],
        const SizedBox(height: Spacing.lg),
        const FadeSlideIn(delayMs: 100, child: _HistoryLink()),
      ],
    );
  }
}

/// The online-payment methods UCAM accepts — shown for information. Paying opens
/// UCAM's own payment page in the browser (we never handle money in-app).
class _PaymentMethodsCard extends StatelessWidget {
  final List<PaymentMethod> methods;
  const _PaymentMethodsCard(this.methods);

  IconData _iconFor(String code) => switch (code) {
        'bk' => Icons.account_balance_wallet_outlined, // bKash (mobile wallet)
        'nx' => Icons.account_balance_outlined, // DBBL Nexus (bank card)
        _ => Icons.credit_card_outlined, // Visa / Master / AmEx
      };

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: 'Pay online',
      icon: Icons.payment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UCAM accepts these payment methods:',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final m in methods)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(m.code),
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(m.name,
                          style: context.text.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'To pay, open the payment page on UCAM. Open Campus never handles '
            'your payment or card details.',
            style: context.text.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Footer link to the separate Payment History page.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: () => Navigator.of(context)
          .push(sharedAxisRoute(const PaymentHistoryPage())),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: scheme.primary),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment history',
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('All bills & payments, by trimester',
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Installment breakdown for the current term's tuition+trimester fee
/// (40/70/100 with ৳500 fine each, +৳20k registration for 252+ students).
/// Dates come from the academic calendar — scaffolded for now.
class _InstallmentCard extends StatelessWidget {
  final double fee;
  final String? term;
  const _InstallmentCard({required this.fee, this.term});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final plan = buildInstallmentPlan(fee, is252OrLater: true);
    return SectionCard(
      title: 'Installment plan',
      icon: Icons.payments_outlined,
      trailing: term != null
          ? Text(term!,
              style: context.text.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tuition + trimester fee: ${bdt(fee)}',
            style: context.text.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (plan.registrationPayment > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Includes ${bdt(plan.registrationPayment)} paid at registration',
                style: context.text.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: Spacing.md),
          for (final inst in plan.installments) ...[
            _InstallmentRow(inst),
            const SizedBox(height: Spacing.sm),
          ],
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: context.status.warnContainer,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: context.status.warn),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'A ৳500 fine applies per installment missed by its deadline. '
                    'Dates are set by UCAM each term.',
                    style: context.text.labelSmall
                        ?.copyWith(color: context.status.warn),
                  ),
                ),
              ],
            ),
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
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          alignment: Alignment.center,
          child: Text('${inst.cumulativePercent.toStringAsFixed(0)}%',
              style: context.text.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$ordinal installment',
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Pay up to ${bdt(inst.cumulativeAmount)} total'
                  '${inst.dateLabel != null ? ' · by ${inst.dateLabel}' : ' · date set by UCAM'}',
                  style: context.text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (inst.thisInstallment > 0)
          Text('+${bdt(inst.thisInstallment)}',
              style: context.text.titleSmall?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final BillData d;
  const _BalanceHero(this.d);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hasDue = d.hasDue;
    final balance = d.balance ?? 0;
    // Gradient hero in a theme accent: dues use the primary accent, a clear
    // balance uses the secondary (calmer) accent. No fixed red/green.
    final accent = hasDue ? scheme.primary : scheme.secondary;
    final onAcc = hasDue ? scheme.onPrimary : scheme.onSecondary;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  hasDue
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 18,
                  color: onAcc),
              const SizedBox(width: 6),
              Text(hasDue ? 'Amount due' : 'Current balance',
                  style: context.text.labelLarge?.copyWith(
                      color: onAcc.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(hasDue ? bdt(balance) : 'Clear',
                  style: context.text.displaySmall
                      ?.copyWith(color: onAcc, fontWeight: FontWeight.w800)),
              const SizedBox(width: Spacing.sm),
              if (!hasDue && balance < 0)
                Text('${bdt(balance, signed: true)} advance',
                    style: context.text.labelMedium
                        ?.copyWith(color: onAcc.withValues(alpha: 0.85))),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Divider(color: onAcc.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                  child: _miniStat(context, 'Total billed',
                      bdt(d.totalBilled), onAcc)),
              Expanded(
                  child:
                      _miniStat(context, 'Total paid', bdt(d.totalPaid), onAcc)),
              if (d.totalDiscount != null && d.totalDiscount != 0)
                Expanded(
                    child: _miniStat(
                        context, 'Waived', bdt(d.totalDiscount!.abs()), onAcc)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value, Color onAcc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelSmall
                ?.copyWith(color: onAcc.withValues(alpha: 0.85))),
        const SizedBox(height: 2),
        Text(value,
            style: context.text.titleSmall
                ?.copyWith(color: onAcc, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

