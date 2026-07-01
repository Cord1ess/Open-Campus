import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_config.dart';
import '../../core/app_info.dart';
import '../../core/cache/local_cache.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';
import '../profile/appearance_settings.dart';

/// About / status page reachable from the login screen. Shows live server
/// status, version + build info, a manual "check for updates" link, a vague
/// (non-revealing) explanation of what the app does, and useful links.
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  ServerStatus? _status;
  bool _checking = false;
  CacheSummary? _cache;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _ping();
    _loadCacheSummary();
  }

  Future<void> _loadCacheSummary() async {
    final s = await ref.read(localCacheProvider).summary();
    if (mounted) setState(() => _cache = s);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text(
          'This removes the saved copy of your data from this device. Your '
          'information stays safe in UCAM and will be fetched again next time '
          'you open the app or pull to refresh.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    await ref.read(localCacheProvider).clearAll();
    await _loadCacheSummary();
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cached data cleared.')),
      );
    }
  }

  Future<void> _ping() async {
    setState(() => _checking = true);
    final s = await ref.read(apiClientProvider).healthCheck();
    if (mounted) {
      setState(() {
        _status = s;
        _checking = false;
      });
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      body: CollapsingTitleScrollView(
        title: 'Settings',
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: wide ? 760 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeSlideIn(child: AppearanceSettings()),
                      const SizedBox(height: Spacing.lg),
                      FadeSlideIn(
                          delayMs: 40,
                          child: _ServerStatusCard(
                            status: _status,
                            checking: _checking,
                            onRefresh: _ping,
                          )),
                      const SizedBox(height: Spacing.lg),
                      // Two-up on desktop, stacked on phones.
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: FadeSlideIn(
                                      delayMs: 80, child: _versionCard())),
                              const SizedBox(width: Spacing.lg),
                              Expanded(
                                  child: FadeSlideIn(
                                      delayMs: 110, child: _updatesCard())),
                            ],
                          ),
                        )
                      else ...[
                        FadeSlideIn(delayMs: 80, child: _versionCard()),
                        const SizedBox(height: Spacing.lg),
                        FadeSlideIn(delayMs: 110, child: _updatesCard()),
                      ],
                      const SizedBox(height: Spacing.lg),
                      FadeSlideIn(delayMs: 140, child: _aboutCard()),
                      const SizedBox(height: Spacing.lg),
                      FadeSlideIn(delayMs: 170, child: _linksCard()),
                      const SizedBox(height: Spacing.lg),
                      FadeSlideIn(delayMs: 200, child: _storageCard()),
                      const SizedBox(height: Spacing.lg),
                      FadeSlideIn(delayMs: 230, child: _privacyNote()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionCard() {
    return SectionCard(
      title: 'Version',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _kv('App', AppInfo.name),
          _kv('Version', AppInfo.version),
          _kv('Channel', AppInfo.buildChannel),
        ],
      ),
    );
  }

  Widget _updatesCard() {
    return SectionCard(
      title: 'Updates',
      icon: Icons.system_update_alt_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This is a beta. New versions are published on GitHub Releases.',
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.md),
          _LinkButton(
            icon: Icons.open_in_new_rounded,
            label: 'Check for updates',
            onTap: () => _open(AppInfo.releasesUrl),
          ),
        ],
      ),
    );
  }

  Widget _storageCard() {
    final scheme = context.scheme;
    final cache = _cache;
    final empty = cache == null || cache.isEmpty;

    String subtitle;
    if (cache == null) {
      subtitle = 'Checking…';
    } else if (cache.isEmpty) {
      subtitle = 'Nothing is stored on this device right now.';
    } else {
      final kb = (cache.bytes / 1024).clamp(0, double.infinity);
      final size = kb < 1 ? '<1 KB' : '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
      final synced =
          cache.lastSynced != null ? _ago(cache.lastSynced!) : 'unknown';
      subtitle =
          '${cache.resourceCount} item${cache.resourceCount == 1 ? '' : 's'} '
          'cached · $size · last synced $synced';
    }

    return SectionCard(
      title: 'Storage',
      icon: Icons.sd_storage_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open Campus saves your last-loaded data on this device so the app '
            'opens instantly and works briefly offline. The server keeps '
            'nothing — this is the only saved copy, and it refreshes itself.',
            style: context.text.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: Spacing.md),
          Text(subtitle,
              style: context.text.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.md),
          // Destructive-tinted clear action; disabled while empty or in flight.
          Align(
            alignment: Alignment.centerLeft,
            child: SpringTap(
              onTap: (empty || _clearing) ? null : _clearCache,
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: scheme.errorContainer
                      .withValues(alpha: (empty || _clearing) ? 0.4 : 1),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_clearing)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.onErrorContainer),
                      )
                    else
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: scheme.onErrorContainer),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      _clearing ? 'Clearing…' : 'Clear cached data',
                      style: context.text.labelLarge?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact relative time ("just now", "5 min ago", "2 h ago", "3 d ago").
  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Widget _aboutCard() {
    return SectionCard(
      title: 'What is Open Campus?',
      icon: Icons.help_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _para(
            'Open Campus is an independent, unofficial companion app for the '
            'UCAM student portal. It gives you a faster, cleaner way to view '
            'your own university information — results, attendance, routine, '
            'dues and notices.',
          ),
          const SizedBox(height: Spacing.md),
          _para(
            'You sign in with your own UCAM account. The app fetches your data '
            'live, on demand, and presents it in a modern interface. It shows '
            'the same information you would see when you log in yourself — '
            'organized and easy to read.',
          ),
          const SizedBox(height: Spacing.md),
          _para(
            'It is not affiliated with or endorsed by the university. All names '
            'and marks belong to their respective owners.',
          ),
        ],
      ),
    );
  }

  Widget _linksCard() {
    return SectionCard(
      title: 'Links',
      icon: Icons.link_rounded,
      child: Column(
        children: [
          _LinkRow(
            icon: Icons.code_rounded,
            label: 'Source code',
            sub: 'Open source on GitHub',
            onTap: () => _open(AppInfo.repoUrl),
          ),
          Divider(height: Spacing.xl, color: context.scheme.outlineVariant),
          _LinkRow(
            icon: Icons.account_balance_rounded,
            label: 'Open UCAM portal',
            sub: 'The official site',
            onTap: () => _open(ApiConfig.ucamUrl),
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Your password is never stored, and our servers keep none of your '
              'data. Everything is fetched live and shown only to you.',
              style: context.text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
                width: 84,
                child: Text(k,
                    style: context.text.labelMedium
                        ?.copyWith(color: context.scheme.onSurfaceVariant))),
            Expanded(
                child: Text(v,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _para(String text) => Text(text,
      style: context.text.bodyMedium
          ?.copyWith(color: context.scheme.onSurfaceVariant, height: 1.55));
}

/// Live server-status card with a colored indicator and latency.
class _ServerStatusCard extends StatelessWidget {
  final ServerStatus? status;
  final bool checking;
  final VoidCallback onRefresh;
  const _ServerStatusCard({
    required this.status,
    required this.checking,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final (color, label, detail) = _present(context);

    return SectionCard(
      title: 'Server status',
      icon: Icons.dns_rounded,
      trailing: IconButton(
        onPressed: checking ? null : onRefresh,
        icon: checking
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: scheme.primary))
            : const Icon(Icons.refresh_rounded),
        tooltip: 'Re-check',
      ),
      child: Row(
        children: [
          _Pulse(color: color, active: status?.state == ServerState.online),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, color: color)),
                Text(detail,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, String, String) _present(BuildContext context) {
    final s = status;
    if (checking) {
      // While a ping is in flight, always show "Checking" — a cold start can take
      // up to a minute, so don't leave a stale Online/Unreachable label showing.
      return (
        context.scheme.onSurfaceVariant,
        'Checking…',
        'Pinging the server (a sleeping free-tier server can take up to a minute).'
      );
    }
    switch (s?.state) {
      case ServerState.online:
        return (
          context.status.good,
          'Online',
          'Responding normally${s?.latencyMs != null ? ' · ${s!.latencyMs} ms' : ''}.'
        );
      case ServerState.waking:
        return (
          context.status.warn,
          'Waking up',
          'The free-tier server is starting — give it a minute, then retry.'
        );
      case ServerState.offline:
      default:
        return (
          context.status.bad,
          'Unreachable',
          'Couldn\'t reach the server. Check your connection and retry.'
        );
    }
  }
}

/// A breathing status dot.
class _Pulse extends StatefulWidget {
  final Color color;
  final bool active;
  const _Pulse({required this.color, required this.active});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    // Only run the expanding-ring animation when active; otherwise it would
    // repaint every frame for no visible effect.
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _dot() => Container(
        width: 14,
        height: 14,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: widget.color),
      );

  @override
  Widget build(BuildContext context) {
    // Inactive: just the static dot, no animation driving rebuilds.
    if (!widget.active) {
      return SizedBox(width: 28, height: 28, child: Center(child: _dot()));
    }
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 14 + 14 * t,
                height: 14 + 14 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25 * (1 - t)),
                ),
              ),
              _dot(),
            ],
          );
        },
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SpringTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(sub,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded,
              size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
