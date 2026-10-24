import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
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
  final _scroll = ScrollController();

  void _goTo(int page, int totalPages) {
    final clamped = page.clamp(1, totalPages);
    if (clamped == _page) return;
    setState(() => _page = clamped);
    // Jump back to the top when the page changes.
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: Motion.medium, curve: Motion.emphasized);
    }
  }

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
    return PageScaffold(
      title: 'Notices',
      controller: _scroll,
      onRefresh: () async => ref.invalidate(uiuNoticesProvider(_page)),
      body: async.when(
        loading: () => const LoadingState(label: 'Loading notices…'),
        error: (e, _) => ErrorState(
          title: 'Couldn’t load notices',
          message: '$e',
          onRetry: () => ref.invalidate(uiuNoticesProvider(_page)),
        ),
        data: (data) => _NoticesList(
          data: data,
          onOpen: _open,
          onPage: (p) => _goTo(p, data.totalPages),
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
    final scheme = context.scheme;
    if (data.notices.isEmpty) {
      return const EmptyState(
          icon: AppIcons.notices, title: 'No notices');
    }
    return Stacked(
      gap: Spacing.lg,
      children: [
        // Source attribution.
        Row(
          children: [
            Icon(AppIcons.link, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.sm),
            Text('Live from uiu.ac.bd/notice', style: context.text.bodySmall),
          ],
        ),
        RowGroup(
          children: [
            for (final n in data.notices)
              ListRow(
                title: n.title,
                subtitle: n.dateText,
                external: true,
                onTap: () => onOpen(n.url),
              ),
          ],
        ),
        _Pager(
          page: data.page,
          totalPages: data.totalPages,
          onPage: onPage,
        ),
      ],
    );
  }
}

/// Newer / page-indicator / Older pager.
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
    final canPrev = page > 1;
    final canNext = page < totalPages;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: canPrev ? () => onPage(page - 1) : null,
          icon: const Icon(AppIcons.chevronLeft, size: 18),
          label: const Text('Newer'),
        ),
        Expanded(
          child: Center(
            child: Text('Page $page of $totalPages',
                style: context.text.labelMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                    fontFeatures: tabularFigures)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: canNext ? () => onPage(page + 1) : null,
          icon: const Icon(AppIcons.chevron, size: 18),
          label: const Text('Older'),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }
}
