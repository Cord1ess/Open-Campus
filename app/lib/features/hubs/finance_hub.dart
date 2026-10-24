import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';
import '../finance/bill_page.dart';
import '../finance/payment_history_page.dart';
import 'hub_page.dart';

class FinanceHub extends ConsumerWidget {
  const FinanceHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final h = home is ResData<HomeSummary> ? home.loaded.data : null;
    final hasDue = h?.hasDue ?? false;
    final p = context.palette;

    void go(BuildContext c, Widget page) =>
        Navigator.of(c).push(appRoute(page));

    return HubPage(
      title: 'Finance',
      header: StatStrip(items: [
        StatBlock(
          label: hasDue ? 'Amount due' : 'Balance',
          value: h == null ? '—' : (hasDue ? bdt(h.dueAmount) : 'Clear'),
          numeric: hasDue ? h?.dueAmount : null,
          format: bdt,
          valueColor: h == null ? null : (hasDue ? p.warningInk : p.successInk),
        ),
        StatBlock(
          label: 'Total paid',
          value: h?.totalPaid != null ? bdt(h!.totalPaid) : '—',
          secretId: h?.totalPaid != null ? Secrets.totalPaid : null,
        ),
        StatBlock(
          label: 'Waived',
          value: h?.totalWaived != null ? bdt(h!.totalWaived) : '—',
          numeric: h?.totalWaived,
          format: bdt,
        ),
      ]),
      groups: [
        HubGroup('Account', [
          HubFeature(
            icon: AppIcons.dues,
            title: 'Balance & Dues',
            subtitle: 'Outstanding amount and installment plan',
            onTap: (c) => go(c, const BillPage()),
          ),
          HubFeature(
            icon: AppIcons.payments,
            title: 'Payment History',
            subtitle: 'Bills and payments by trimester',
            onTap: (c) => go(c, const PaymentHistoryPage()),
          ),
          const HubFeature(
            icon: AppIcons.invoices,
            title: 'Invoices & Fees',
            subtitle: 'Fee structure and invoices',
            status: FeatureStatus.comingSoon,
          ),
        ]),
        const HubGroup('Pay', [
          HubFeature(
            icon: AppIcons.pay,
            title: 'Pay Now',
            subtitle: 'Opens the UCAM payment page',
            status: FeatureStatus.opensInUcam,
          ),
        ]),
      ],
    );
  }
}
