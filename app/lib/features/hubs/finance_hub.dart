import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/accents.dart';
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
    final accents = Accents.of(context);
    final hasDue = h?.hasDue ?? false;

    return HubPage(
      title: 'Finance',
      header: StatRow(tiles: [
        StatTile(
          icon: hasDue ? Icons.error_outline : Icons.check_circle_outline,
          label: hasDue ? 'Due' : 'Balance',
          value: h == null
              ? '—'
              : hasDue
                  ? bdt(h.dueAmount)
                  : 'Clear',
          tone: hasDue ? context.status.badContainer : context.status.goodContainer,
          onTone: hasDue ? context.status.bad : context.status.good,
        ),
        StatTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Total paid',
          value: h?.totalPaid != null ? bdt(h!.totalPaid) : '—',
          tone: accents[1].background,
          onTone: accents[1].foreground,
        ),
        StatTile(
          icon: Icons.savings_outlined,
          label: 'Waived',
          value: h?.totalWaived != null ? bdt(h!.totalWaived) : '—',
          tone: accents[3].background,
          onTone: accents[3].foreground,
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
