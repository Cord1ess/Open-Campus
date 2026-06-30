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

/// Extracts the leading numeric term code (e.g. "[261] Spring 2026" → 261) so
/// trimesters sort newest-first. Non-coded groups (e.g. "Payments") sort last.
int _termCode(String t) {
  final m = RegExp(r'\d+').firstMatch(t);
  return m != null ? int.parse(m.group(0)!) : -1;
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
    final groups = d.byTrimester;
    // Newest trimester first by term code.
    final keys = groups.keys.toList()
      ..sort((a, b) => _termCode(b).compareTo(_termCode(a)));

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

/// One trimester's statement: payments (top) then billed charges (below), each
/// with its own subtotal. Accent-coloured.
class _TrimesterStatement extends StatelessWidget {
  final String trimester;
  final List<BillItem> items;
  const _TrimesterStatement({required this.trimester, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final payments = items.where((i) => i.isPayment).toList();
    final bills = items.where((i) => !i.isPayment).toList();
    final totalPaid = payments.fold<double>(0, (s, i) => s + (i.payment ?? 0));
    final totalBilled = bills.fold<double>(0, (s, i) => s + (i.amount ?? 0));
    final net = totalBilled - totalPaid;

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
                // Payments first (most recent on top).
                if (payments.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Payments',
                    icon: Icons.south_west_rounded,
                    total: '+${bdt(totalPaid)}',
                    color: scheme.secondary,
                  ),
                  const SizedBox(height: Spacing.sm),
                  for (final p in payments)
                    _Line(
                      title: p.feeType ?? p.remark ?? 'Payment',
                      sub: p.date,
                      amount: '+${bdt(p.payment)}',
                      amountColor: scheme.secondary,
                      icon: Icons.south_west_rounded,
                    ),
                ],
                if (payments.isNotEmpty && bills.isNotEmpty) ...[
                  const SizedBox(height: Spacing.md),
                  Divider(height: 1, color: scheme.outlineVariant),
                  const SizedBox(height: Spacing.md),
                ],
                // Billed charges below.
                if (bills.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Billed',
                    icon: Icons.north_east_rounded,
                    total: bdt(totalBilled),
                    color: scheme.primary,
                  ),
                  const SizedBox(height: Spacing.sm),
                  for (final b in bills)
                    _Line(
                      title: b.courseCode ?? b.feeType ?? 'Charge',
                      sub: [
                        if (b.courseCode != null) b.feeType,
                        if (b.discount != null && b.discount! > 0)
                          'waiver ${bdt(b.discount)}',
                      ].whereType<String>().join(' · '),
                      amount: bdt(b.amount),
                      amountColor: scheme.onSurface,
                      icon: Icons.north_east_rounded,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final String total;
  final Color color;
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const Spacer(),
        Text(total,
            style: context.text.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String title;
  final String? sub;
  final String amount;
  final Color amountColor;
  final IconData icon;
  const _Line({
    required this.title,
    required this.sub,
    required this.amount,
    required this.amountColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (sub != null && sub!.isNotEmpty)
                  Text(sub!,
                      style: context.text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(amount,
              style: context.text.bodyMedium
                  ?.copyWith(color: amountColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
