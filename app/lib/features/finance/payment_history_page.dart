import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'bill_model.dart';
import 'bill_page.dart' show bdt;

/// Payment History — every trimester (newest first) as one date-descending
/// statement of bills and payments, with the term's subtotals.
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
    return PageScaffold(
      title: 'Payment History',
      onRefresh: () => ref.read(billProvider.notifier).load(force: true),
      body: ResourceBody<BillData>(
        state: state,
        loadingLabel: 'Loading your statement…',
        onRetry: () => ref.read(billProvider.notifier).load(force: true),
        builder: (d) => _Content(d),
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
      return const EmptyState(
          icon: AppIcons.payments, title: 'No transactions yet');
    }
    // Newest term first; within a term one date-descending stream of bills and
    // payments. Payments carry no term and are assigned to the trimester they
    // chronologically follow (see BillData.statementByTrimester).
    final groups = d.statementByTrimester;
    return ResponsiveGrid(
      maxColumns: 2,
      stretch: false,
      spacing: Spacing.xl,
      runSpacing: Spacing.xl,
      children: [
        for (final e in groups.entries)
          _TrimesterStatement(trimester: e.key, items: e.value),
      ],
    );
  }
}

/// One trimester's statement with its net status and subtotals.
class _TrimesterStatement extends StatelessWidget {
  final String trimester;
  final List<BillItem> items; // already date-descending (newest first)
  const _TrimesterStatement({required this.trimester, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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

    return RowGroup(
      title: trimester,
      trailing: net.abs() >= 1
          ? (net > 0
              ? StatusBadge('Due ${bdt(net)}', tone: StatusTone.warning)
              : const StatusBadge('Settled', tone: StatusTone.success))
          : null,
      children: [
        for (final it in items) _TxnLine(item: it),
        // Subtotals: billed / waived (only if any) / paid.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: StatStrip(bordered: false, items: [
            StatBlock(label: 'Billed', value: bdt(totalBilled)),
            if (totalWaived > 0)
              StatBlock(
                  label: 'Waived',
                  value: '−${bdt(totalWaived)}',
                  valueColor: p.infoInk),
            StatBlock(
                label: 'Paid',
                value: '+${bdt(totalPaid)}',
                valueColor: p.successInk),
          ]),
        ),
      ],
    );
  }
}

/// A single statement row: a charge, a payment, or a waiver.
class _TxnLine extends StatelessWidget {
  final BillItem item;
  const _TxnLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final kind = item.kind;

    final (Color color, String title, String amount) = switch (kind) {
      BillKind.payment => (
        p.successInk,
        item.feeType ?? 'Payment',
        '+${bdt((item.payment ?? 0).abs())}',
      ),
      BillKind.adjustment => (
        p.infoInk,
        item.feeType ?? item.courseCode ?? 'Waiver',
        '−${bdt((item.discount ?? 0).abs())}',
      ),
      BillKind.charge => (
        scheme.onSurface,
        item.courseCode ?? item.feeType ?? 'Charge',
        (item.amount ?? 0) != 0 ? bdt(item.amount) : '—',
      ),
    };

    final subParts = <String>[
      if (item.date != null && item.date!.trim().isNotEmpty) item.date!.trim(),
      if (kind == BillKind.charge &&
          item.courseCode != null &&
          item.feeType != null &&
          item.feeType != item.courseCode)
        item.feeType!,
      if (item.remark != null && item.remark!.trim().isNotEmpty)
        item.remark!.trim(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                if (subParts.isNotEmpty)
                  Text(subParts.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          Text(amount,
              style: context.text.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabularFigures)),
        ],
      ),
    );
  }
}
