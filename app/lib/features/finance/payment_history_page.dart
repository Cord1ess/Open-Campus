import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'bill_model.dart';
import 'bill_page.dart' show bdt;

/// Payment History — every trimester (newest first), each showing its PAYMENTS
/// on top (with a running total paid) and its BILLED charges below (with a total
/// billed). Sequential and clearly separated, so it reads like a statement.
class PaymentHistoryPage extends ConsumerStatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  ConsumerState<PaymentHistoryPage> createState() =>
      _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends ConsumerState<PaymentHistoryPage> {
  @override
  void initState() {
    super.initState();
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
            const SliverCollapsingAppBar(title: 'Payment History'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const SectionCard(
                      title: 'Payment History',
                      icon: Icons.receipt_long_outlined,
                      child: CardSkeleton(label: 'Loading your statement…')),
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

class _Content extends StatelessWidget {
  final BillData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    if (d.items.isEmpty) {
      return const SectionCard(
        title: 'Payment History',
        icon: Icons.receipt_long_outlined,
        child: StateMessage(
            icon: Icons.history, title: 'No transactions yet'),
      );
    }
    // A per-trimester statement: newest term first, and within each term a
    // single date-descending stream of bills AND payments interleaved (matching
    // UCAM's own layout). Payments — which carry no term — are assigned to the
    // trimester they chronologically follow. See BillData.statementByTrimester.
    final groups = d.statementByTrimester;
    final keys = groups.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 40 + i * 40,
            child: _TrimesterStatement(
                trimester: keys[i], items: groups[keys[i]]!),
          ),
        ],
      ],
    );
  }
}

/// One trimester's statement: a single date-descending stream of transactions
/// (bills and payments interleaved, newest first), exactly as UCAM lists them.
/// Payments are green (+), charges are neutral. Header shows the term's net.
class _TrimesterStatement extends StatelessWidget {
  final String trimester;
  final List<BillItem> items; // already date-descending (newest first)
  const _TrimesterStatement({required this.trimester, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // Sum by kind so adjustments (waivers) aren't miscounted as charges.
    var totalBilled = 0.0, totalPaid = 0.0, totalWaived = 0.0;
    for (final i in items) {
      switch (i.kind) {
        case BillKind.charge:
          totalBilled += i.amount ?? 0;
        case BillKind.payment:
          totalPaid += (i.payment ?? 0).abs();
        case BillKind.adjustment:
          totalWaived += (i.discount ?? 0).abs();
      }
    }
    // Net still owed this term: charges minus waivers minus payments.
    final net = totalBilled - totalWaived - totalPaid;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trimester header strip.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.md),
            color: scheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(trimester,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (net.abs() >= 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (net > 0 ? scheme.primary : scheme.secondary)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                        net > 0
                            ? 'Due ${bdt(net)}'
                            : 'Settled',
                        style: context.text.labelSmall?.copyWith(
                            color: net > 0 ? scheme.primary : scheme.secondary,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // One date-descending stream — bills and payments interleaved,
                // exactly as UCAM shows the term's activity.
                for (final it in items)
                  _TxnLine(item: it),
                const SizedBox(height: Spacing.md),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: Spacing.md),
                // Compact billed / waived / paid subtotal for the term. Waived
                // only appears when the term actually has a waiver.
                Row(
                  children: [
                    Expanded(
                      child: _Subtotal(
                          label: 'Billed',
                          value: bdt(totalBilled),
                          color: scheme.primary),
                    ),
                    if (totalWaived > 0)
                      Expanded(
                        child: _Subtotal(
                            label: 'Waived',
                            value: '-${bdt(totalWaived)}',
                            color: scheme.tertiary),
                      ),
                    Expanded(
                      child: _Subtotal(
                          label: 'Paid',
                          value: '+${bdt(totalPaid)}',
                          color: scheme.secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single statement row: a bill (charge) or a payment. Payments are shown in
/// the secondary accent with a leading "+"; charges are neutral. A small
/// leading icon + the date make the interleaved stream easy to scan.
class _TxnLine extends StatelessWidget {
  final BillItem item;
  const _TxnLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final kind = item.kind;

    // Per-kind icon, accent, title, and amount string. Adjustments (waivers /
    // discounts) get their own treatment so they never render as a blank charge.
    final (IconData icon, Color accent, String title, String amount) =
        switch (kind) {
      BillKind.payment => (
        Icons.south_west_rounded,
        scheme.secondary,
        item.feeType ?? 'Payment',
        '+${bdt((item.payment ?? 0).abs())}',
      ),
      BillKind.adjustment => (
        Icons.percent_rounded,
        scheme.tertiary,
        item.feeType ?? item.courseCode ?? 'Waiver',
        // Discounts reduce what's owed; show as a negative reduction.
        '-${bdt((item.discount ?? 0).abs())}',
      ),
      BillKind.charge => (
        Icons.north_east_rounded,
        scheme.onSurface,
        item.courseCode ?? item.feeType ?? 'Charge',
        // Guard a charge with no amount (rare) so it reads "—", not a bare unit.
        (item.amount ?? 0) != 0 ? bdt(item.amount) : '—',
      ),
    };

    // Sub-line: date, plus context per kind.
    final subParts = <String>[
      if (item.date != null && item.date!.trim().isNotEmpty) item.date!.trim(),
      // For a charge titled by course code, also show the fee type.
      if (kind == BillKind.charge &&
          item.courseCode != null &&
          item.feeType != null &&
          item.feeType != item.courseCode)
        item.feeType!,
      // The remark carries useful context on payments AND adjustments.
      if (item.remark != null && item.remark!.trim().isNotEmpty)
        item.remark!.trim(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon,
                size: 15,
                color: kind == BillKind.charge
                    ? scheme.onSurfaceVariant
                    : accent),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (subParts.isNotEmpty)
                  Text(
                    subParts.join(' · '),
                    style: context.text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(amount,
              style: context.text.bodyMedium
                  ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// A compact "label / value" subtotal used in the term footer.
class _Subtotal extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Subtotal(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
                color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: context.text.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
