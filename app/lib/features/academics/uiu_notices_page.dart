import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import '../dashboard/dashboard_controller.dart';
import 'uiu_notices_model.dart';

/// UIU public notices — scraped from uiu.ac.bd/notice/, rendered natively with
/// pagination. Each notice deep-links out to the original page.
class UiuNoticesPage extends ConsumerStatefulWidget {
  const UiuNoticesPage({super.key});

  @override
  ConsumerState<UiuNoticesPage> createState() => _UiuNoticesPageState();
}

class _UiuNoticesPageState extends ConsumerState<UiuNoticesPage> {
  int _page = 1;

  void _goTo(int page, int totalPages) {
    final clamped = page.clamp(1, totalPages);
    if (clamped == _page) return;
    setState(() => _page = clamped);
    // Jump back to the top when the page changes.
    _scroll.animateTo(0,
        duration: Motion.medium, curve: Motion.emphasized);
  }

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the notice.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(uiuNoticesProvider(_page));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(uiuNoticesProvider(_page)),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            const SliverCollapsingAppBar(title: 'Notices'),
            SliverPadding(
              padding: const EdgeInsets.all(Spacing.lg),
              sliver: SliverList.list(children: [
                async.when(
                  loading: () => const Center(
                      child: LoadingIndicator(label: 'Loading notices…')),
                  error: (e, _) => StateMessage(
                    icon: Icons.cloud_off,
                    title: 'Couldn’t load notices',
                    subtitle: '$e',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(uiuNoticesProvider(_page)),
                  ),
                  data: (data) => _NoticesList(
                    data: data,
                    onOpen: _open,
                    onPage: (p) => _goTo(p, data.totalPages),
                  ),
                ),
                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticesList extends StatelessWidget {
  final UiuNoticesData data;
  final void Function(String) onOpen;
  final void Function(int) onPage;
  const _NoticesList({
    required this.data,
    required this.onOpen,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    if (data.notices.isEmpty) {
      return const StateMessage(
          icon: Icons.notifications_off_outlined, title: 'No notices');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source attribution.
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: Row(
            children: [
              Icon(Icons.public, size: 14, color: context.scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Live from uiu.ac.bd/notice',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant)),
            ],
          ),
        ),
        for (var i = 0; i < data.notices.length; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.md),
          FadeSlideIn(
            delayMs: 20 * i,
            child: _NoticeCard(data.notices[i], onOpen: onOpen),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        _Pager(
          page: data.page,
          totalPages: data.totalPages,
          onPage: onPage,
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final UiuNotice notice;
  final void Function(String) onOpen;
  const _NoticeCard(this.notice, {required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: () => onOpen(notice.url),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(Icons.campaign_outlined,
                  size: 22, color: scheme.primary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
                  if (notice.dateText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(notice.dateText!,
                            style: context.text.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        const Spacer(),
                        Text('Open',
                            style: context.text.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800)),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: scheme.primary),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prev / page-indicator / Next pager.
class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final void Function(int) onPage;
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final canPrev = page > 1;
    final canNext = page < totalPages;
    return Row(
      children: [
        _navBtn(context, Icons.chevron_left, 'Newer',
            enabled: canPrev, onTap: () => onPage(page - 1)),
        Expanded(
          child: Center(
            child: Text('Page $page of $totalPages',
                style: context.text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        _navBtn(context, Icons.chevron_right, 'Older',
            enabled: canNext, onTap: () => onPage(page + 1), trailing: true),
      ],
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, String label,
      {required bool enabled,
      required VoidCallback onTap,
      bool trailing = false}) {
    final scheme = context.scheme;
    final color = enabled ? scheme.primary : scheme.onSurfaceVariant;
    final children = [
      if (!trailing) Icon(icon, size: 18, color: color),
      Text(label,
          style: context.text.labelLarge
              ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      if (trailing) Icon(icon, size: 18, color: color),
    ];
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SpringTap(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Radii.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
