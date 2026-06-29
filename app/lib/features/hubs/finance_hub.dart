import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/stat_tiles.dart';
import '../../shared/widgets.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/home_model.dart';
import '../finance/bill_page.dart';
import 'hub_page.dart';

class FinanceHub extends ConsumerWidget {
  const FinanceHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final h = home is ResData<HomeSummary> ? home.loaded.data : null;
    final hasDue = h?.hasDue ?? false;
    final scheme = context.scheme;

    return HubPage(
      title: 'Finance',
      header: StatRow(tiles: [
        // Filled focal tile — orange when there's a due, blue when clear.
        StatTile(
          icon: hasDue ? Icons.error_outline : Icons.check_circle_outline,
          label: hasDue ? 'Due' : 'Balance',
          value: h == null
              ? '—'
              : hasDue
                  ? bdt(h.dueAmount)
                  : 'Clear',
          accent: hasDue ? scheme.primary : scheme.secondary,
          filled: true,
        ),
        StatTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Total paid',
          value: h?.totalPaid != null ? bdt(h!.totalPaid) : '—',
          accent: scheme.secondary,
        ),
        StatTile(
          icon: Icons.savings_outlined,
          label: 'Waived',
          value: h?.totalWaived != null ? bdt(h!.totalWaived) : '—',
          accent: scheme.secondary,
        ),
      ]),
      groups: [
        HubGroup('Account', [
          HubFeature(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Balance & Dues',
            subtitle: 'Outstanding amount & balance',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c).push(sharedAxisRoute(const BillPage())),
          ),
          HubFeature(
            icon: Icons.receipt_long_outlined,
            title: 'Payment History',
            subtitle: 'Your transaction ledger',
            status: FeatureStatus.live,
            onTap: (c) => Navigator.of(c).push(sharedAxisRoute(const BillPage())),
          ),
          const HubFeature(
            icon: Icons.request_quote_outlined,
            title: 'Invoices & Fees',
            subtitle: 'Fee structure & invoices',
          ),
        ]),
        const HubGroup('Pay', [
          HubFeature(
            icon: Icons.payment_outlined,
            title: 'Pay Now',
            subtitle: 'Opens UCAM payment gateway',
            status: FeatureStatus.opensInUcam,
          ),
        ]),
      ],
    );
  }
}
