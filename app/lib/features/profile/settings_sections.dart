import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_config.dart';
import '../../core/app_info.dart';
import '../../core/cache/local_cache.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets.dart';

/// Reusable settings blocks shared by the Profile page (signed in) and the
/// login-screen Settings page (signed out). Each owns its own behaviour.

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------

/// Accent colour swatches + Light / Dark / Black mode.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    return Section(
      title: 'Appearance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accent', style: context.text.labelMedium),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              for (final (name, color) in SeedSwatches.all)
                _Swatch(
                  name: name,
                  color: color,
                  brand: color.toARGB32() == SeedSwatches.custom.toARGB32(),
                  selected: prefs.seed.toARGB32() == color.toARGB32(),
                  onTap: () => controller.setSeed(color),
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text('Theme', style: context.text.labelMedium),
          const SizedBox(height: Spacing.sm),
          FormWidth(
            child: SegmentedControl<AppThemeMode>(
              value: prefs.mode,
              onChanged: controller.setMode,
              options: const [
                SegmentOption(AppThemeMode.light, 'Light',
                    icon: AppIcons.light),
                SegmentOption(AppThemeMode.dark, 'Dark', icon: AppIcons.dark),
                SegmentOption(AppThemeMode.black, 'Black',
                    icon: AppIcons.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;
  final bool brand;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.name,
    required this.color,
    required this.brand,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    const size = 32.0;
    // The brand swatch is half orange / half blue, drawn as two clipped halves.
    final fill = brand
        ? Row(children: [
            Expanded(child: Container(color: AppColors.orange)),
            Expanded(child: Container(color: AppColors.blue)),
          ])
        : Container(color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name accent',
      child: Tooltip(
        message: name,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: size + 8,
            height: size + 8,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fill,
                  if (selected)
                    Center(
                      child:
                          Icon(AppIcons.check, size: 18, color: onColor(color)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/// What is cached on this device, with a confirm-then-clear action.
class StorageSection extends ConsumerStatefulWidget {
  const StorageSection({super.key});

  @override
  ConsumerState<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<StorageSection> {
  CacheSummary? _cache;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(localCacheProvider).summary();
    if (mounted) setState(() => _cache = s);
  }

  Future<void> _clear() async {
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
    await _load();
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cached data cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = _cache;
    final empty = cache == null || cache.isEmpty;
    String summary;
    if (cache == null) {
      summary = 'Checking…';
    } else if (cache.isEmpty) {
      summary = 'Nothing is stored on this device right now.';
    } else {
      final kb = cache.bytes / 1024;
      final size =
          kb < 1 ? '<1 KB' : '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
      final synced = cache.lastSynced != null
          ? FreshnessLine.ago(cache.lastSynced!)
          : 'unknown';
      summary =
          '${cache.resourceCount} item${cache.resourceCount == 1 ? '' : 's'} '
          'cached · $size · last synced $synced';
    }
    return Section(
      title: 'Storage',
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(AppIcons.storage, hue: Hue.aqua),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    child: Text(summary,
                        key: ValueKey(summary), style: context.text.titleSmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Your last-loaded data is saved on this device so the app opens '
              'instantly. The server keeps nothing; this is the only saved copy.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Spacing.lg),
            OutlinedButton.icon(
              onPressed: (empty || _clearing) ? null : _clear,
              icon: _clearing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(AppIcons.delete, size: 18),
              label: Text(_clearing ? 'Clearing…' : 'Clear cached data'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Server status
// ---------------------------------------------------------------------------

/// Live backend status with a re-check action.
class ServerStatusSection extends ConsumerStatefulWidget {
  const ServerStatusSection({super.key});

  @override
  ConsumerState<ServerStatusSection> createState() =>
      _ServerStatusSectionState();
}

class _ServerStatusSectionState extends ConsumerState<ServerStatusSection> {
  ServerStatus? _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _ping();
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

  (StatusTone, String, String) _present() {
    final s = _status;
    if (_checking) {
      return (
        StatusTone.neutral,
        'Checking…',
        'Pinging the server (a sleeping free-tier server can take up to a minute).'
      );
    }
    switch (s?.state) {
      case ServerState.online:
        return (
          StatusTone.success,
          'Online',
          'Responding normally${s?.latencyMs != null ? ' · ${s!.latencyMs} ms' : ''}.'
        );
      case ServerState.waking:
        return (
          StatusTone.warning,
          'Waking up',
          'The free-tier server is starting. Give it a minute, then retry.'
        );
      case ServerState.offline:
      default:
        return (
          StatusTone.danger,
          'Unreachable',
          'Couldn’t reach the server. Check your connection and retry.'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (tone, label, detail) = _present();
    final ink = context.palette.inkFor(tone, context.scheme);
    return RowGroup(
      title: 'Server status',
      children: [
        ListRow(
          leading: SizedBox(
            width: 24,
            child: Center(
              child: tone == StatusTone.success
                  ? LiveDot(color: ink, size: 9)
                  : StatusDot(ink, size: 10),
            ),
          ),
          title: label,
          titleColor: tone == StatusTone.neutral ? null : ink,
          subtitle: detail,
          subtitleLines: 2,
          chevron: false,
          trailing: _checking
              ? const ExpressiveLoader(size: 22)
              : IconButton(
                  onPressed: _ping,
                  tooltip: 'Re-check',
                  icon: const Icon(AppIcons.refresh),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

/// Version, updates, links, and the one-paragraph description.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowGroup(
          title: 'About',
          children: [
            const ListRow(
              icon: AppIcons.info,
              title: 'Version',
              value: '${AppInfo.version} ${AppInfo.buildChannel}',
              chevron: false,
            ),
            ListRow(
              icon: AppIcons.update,
              title: 'Check for updates',
              subtitle: 'New versions are published on GitHub Releases',
              external: true,
              onTap: () => _open(context, AppInfo.releasesUrl),
            ),
            ListRow(
              icon: AppIcons.code,
              title: 'Source code',
              subtitle: 'Open source on GitHub',
              external: true,
              onTap: () => _open(context, AppInfo.repoUrl),
            ),
            ListRow(
              icon: AppIcons.link,
              title: 'Open UCAM portal',
              subtitle: 'The official site',
              external: true,
              onTap: () => _open(context, ApiConfig.ucamUrl),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        const InfoNote(
          text:
              'Open Campus is an independent, unofficial companion app for the '
              'UCAM student portal. You sign in with your own UCAM account and '
              'the app fetches your data live, on demand, and shows the same '
              'information you would see when you log in yourself.',
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Not affiliated with or endorsed by the university. All names and '
          'marks belong to their respective owners.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}
