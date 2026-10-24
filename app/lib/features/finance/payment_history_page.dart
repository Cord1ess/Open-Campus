import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/course_names.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import 'bill_model.dart';
import 'bill_page.dart' show bdt;

/// Payment History — totals, a billed/paid/waived chart by trimester, then
/// every trimester (newest first) as one date-descending statement of bills
/// and payments, with the term's subtotals.
class PaymentHistoryPage extends ConsumerStatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  ConsumerState<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
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

/// Compact money for chart axes ("৳26k", "৳1.2M").
String _compact(double v) {
  final a = v.abs();
  if (a >= 1000000) return '৳${(v / 1000000).toStringAsFixed(1)}M';
  if (a >= 1000) return '৳${(v / 1000).toStringAsFixed(0)}k';
  return '৳${v.toStringAsFixed(0)}';
}

/// Strips a leading "[261] " term code from a trimester label.
String _termLabel(String t) => t.replaceFirst(RegExp(r'^\[\d+\]\s*'), '');

({double billed, double paid, double waived}) _totals(List<BillItem> items) {
  // Sum by kind so adjustments (waivers) aren't miscounted as charges.
  var billed = 0.0, paid = 0.0, waived = 0.0;
  for (final i in items) {
    switch (i.kind) {
      case BillKind.charge:
        billed += i.amount ?? 0;
      case BillKind.payment:
        paid += (i.payment ?? 0).abs();
      case BillKind.adjustment:
        waived += (i.discount ?? 0).abs();
    }
  }
  return (billed: billed, paid: paid, waived: waived);
}

class _Content extends StatelessWidget {
  final BillData d;
  const _Content(this.d);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (d.items.isEmpty) {
      return const EmptyState(
          icon: AppIcons.payments, title: 'No transactions yet');
    }
    // Newest term first; within a term one date-descending stream of bills and
    // payments. Payments carry no term and are assigned to the trimester they
    // chronologically follow (see BillData.statementByTrimester).
    final groups = d.statementByTrimester;
    final oldestFirst = groups.entries.toList().reversed.toList();
    final perTerm = [for (final e in oldestFirst) _totals(e.value)];
    final waived = d.totalDiscount != null && d.totalDiscount != 0
        ? d.totalDiscount!.abs()
        : null;

    final sections = <Widget>[
      StatStrip(items: [
        StatBlock(
          label: 'Total billed',
          value: bdt(d.totalBilled),
          numeric: d.totalBilled,
          format: bdt,
          hue: Hue.peach,
        ),
        StatBlock(
          label: 'Total paid',
          value: bdt(d.totalPaid),
          secretId: d.totalPaid != null ? Secrets.totalPaid : null,
          hue: Hue.mint,
        ),
        StatBlock(
          label: 'Waived',
          value: waived != null ? bdt(waived) : '—',
          numeric: waived,
          format: bdt,
          hue: Hue.sky,
        ),
      ]),
      if (oldestFirst.length >= 2)
        Section(
          title: 'By trimester',
          child: Panel(
            child: TrendChart(
              initialMode: ChartMode.bars,
              format: _compact,
              labels: [for (final e in oldestFirst) _termLabel(e.key)],
              series: [
                ChartSeries(
                    name: 'Billed',
                    color: p.accent,
                    values: [for (final t in perTerm) t.billed]),
                ChartSeries(
                    name: 'Paid',
                    color: p.successInk,
                    values: [for (final t in perTerm) t.paid]),
                ChartSeries(
                    name: 'Waived',
                    color: p.infoInk,
                    values: [for (final t in perTerm) t.waived]),
              ],
            ),
          ),
        ),
      ResponsiveGrid(
        maxColumns: 2,
        stretch: false,
        spacing: Spacing.xl,
        runSpacing: Spacing.xl,
        children: [
          for (final (i, e) in groups.entries.indexed)
            Reveal(
              index: i + 2,
              child: _TrimesterStatement(trimester: e.key, items: e.value),
            ),
        ],
      ),
    ];
    return Stacked(children: [
      for (var i = 0; i < sections.length; i++)
        Reveal(index: i, child: sections[i]),
    ]);
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
    final t = _totals(items);
    // Net still owed this term: charges minus waivers minus payments.
    final net = t.billed - t.waived - t.paid;

    return RowGroup(
      title: _termLabel(trimester),
      trailing: net.abs() >= 1
          ? (net > 0
              ? StatusBadge('Due ${bdt(net)}', tone: StatusTone.warning)
              : const StatusBadge('Settled', tone: StatusTone.success))
          : null,
      children: [
        for (final it in items) _TxnLine(item: it),
        // Subtotals: billed / waived (only if any) / paid.
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg + 4, vertical: Spacing.sm),
          child: StatStrip(bordered: false, items: [
            StatBlock(label: 'Billed', value: bdt(t.billed)),
            if (t.waived > 0)
              StatBlock(
                  label: 'Waived',
                  value: '−${bdt(t.waived)}',
                  valueColor: p.infoInk),
            StatBlock(
                label: 'Paid',
                value: '+${bdt(t.paid)}',
                valueColor: p.successInk),
          ]),
        ),
      ],
    );
  }
}

/// A single statement row: a charge, a payment, or a waiver. Course charges
/// show the course title with its code underneath.
class _TxnLine extends StatelessWidget {
  final BillItem item;
  const _TxnLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final p = context.palette;
    final kind = item.kind;

    final (Color color, String title, String amount, IconData icon, Hue hue) =
        switch (kind) {
      BillKind.payment => (
          p.successInk,
          item.feeType ?? 'Payment',
          '+${bdt((item.payment ?? 0).abs())}',
          AppIcons.payments,
          Hue.mint,
        ),
      BillKind.adjustment => (
          p.infoInk,
          item.feeType ?? item.courseCode ?? 'Waiver',
          '−${bdt((item.discount ?? 0).abs())}',
          AppIcons.waiver,
          Hue.sky,
        ),
      BillKind.charge => (
          scheme.onSurface,
          item.courseCode ?? item.feeType ?? 'Charge',
          (item.amount ?? 0) != 0 ? bdt(item.amount) : '—',
          item.courseCode != null ? AppIcons.course : AppIcons.dues,
          Hue.peach,
        ),
    };

    final date = item.date?.trim();
    final remark = item.remark?.trim();
    final isCourse = kind == BillKind.charge && item.courseCode != null;
    final extraParts = <String>[
      if (isCourse && item.feeType != null && item.feeType != item.courseCode)
        item.feeType!,
      if (date != null && date.isNotEmpty) date,
      if (remark != null && remark.isNotEmpty) remark,
    ];
    final titleStyle =
        context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg + 4, vertical: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTile(icon, hue: hue, size: 40),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: isCourse
                ? CourseName(
                    code: item.courseCode!,
                    extra: extraParts.join(' · '),
                    titleStyle: titleStyle,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle),
                      if (extraParts.isNotEmpty)
                        Text(extraParts.join(' · '),
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
