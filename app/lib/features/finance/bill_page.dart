import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/installments.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/resource_view.dart';
import '../common/collapsing_title.dart';
import 'bill_model.dart';

/// Full bill: live balance hero + itemized charges and payments grouped by
/// trimester. Data from /student/bill.
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
            SliverCollapsingAppBar(title: 'Bill & Payments'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                switch (state) {
                  ResLoading() => const CardSkeleton(lines: 6),
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
    // Current-term tuition+trimester fee = charges (not payments) in the most
    // recent trimester, picked deterministically (highest term code) so the
    // installment breakdown isn't tied to backend ordering.
    final currentTerm = d.currentTrimester;
    final currentFee = currentTerm == null
        ? 0.0
        : (groups[currentTerm] ?? const [])
            .where((i) => !i.isPayment)
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
        const SizedBox(height: Spacing.lg),
        for (final (i, entry) in groups.entries.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.lg),
          FadeSlideIn(
            delayMs: 60 + i * 40,
            child: _GroupCard(title: entry.key, items: entry.value),
          ),
        ],
      ],
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
    final color = hasDue ? context.status.bad : context.status.good;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hasDue ? 'Amount due' : 'Current balance',
              style: context.text.labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(hasDue ? bdt(balance) : 'Clear',
                  style: context.text.displaySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
              const SizedBox(width: Spacing.sm),
              if (!hasDue && balance < 0)
                Text('${bdt(balance, signed: true)} advance',
                    style: context.text.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                  child: _miniStat(context, 'Total billed',
                      bdt(d.totalBilled))),
              Expanded(
                  child:
                      _miniStat(context, 'Total paid', bdt(d.totalPaid))),
              if (d.totalDiscount != null && d.totalDiscount != 0)
                Expanded(
                    child: _miniStat(
                        context, 'Waived', bdt(d.totalDiscount!.abs()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: context.text.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final List<BillItem> items;
  const _GroupCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SectionCard(
      title: title,
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: Spacing.lg, color: scheme.outlineVariant),
            _ItemRow(items[i]),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final BillItem item;
  const _ItemRow(this.item);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isPayment = item.isPayment;
    final amount = isPayment ? item.payment : item.amount;
    final color = isPayment ? context.status.good : scheme.onSurface;
    final title = item.courseCode ?? item.feeType ?? 'Item';
    final sub = [
      if (item.courseCode != null) item.feeType,
      if (item.date != null) item.date,
    ].whereType<String>().join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(isPayment ? Icons.south_west : Icons.north_east,
            size: 16,
            color: isPayment ? context.status.good : scheme.onSurfaceVariant),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (sub.isNotEmpty)
                Text(sub,
                    style: context.text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text('${isPayment ? '+' : ''}${bdt(amount)}',
            style: context.text.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
