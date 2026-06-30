import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../common/collapsing_title.dart';

/// The two modes every Services tool offers.
enum ToolMode { auto, manual }

/// Shared scaffold for the Services tools (GPA, Tuition). A collapsing title, a
/// themed Auto/Manual segmented control, then the active mode's content. Keeps
/// both tools visually identical.
class ToolScaffold extends StatefulWidget {
  final String title;
  /// Builds the body for a given mode. Called on every mode switch.
  final Widget Function(BuildContext, ToolMode) builder;
  final ToolMode initial;
  final String autoLabel;
  final String manualLabel;
  const ToolScaffold({
    super.key,
    required this.title,
    required this.builder,
    this.initial = ToolMode.auto,
    this.autoLabel = 'Auto',
    this.manualLabel = 'Manual',
  });

  @override
  State<ToolScaffold> createState() => _ToolScaffoldState();
}

class _ToolScaffoldState extends State<ToolScaffold> {
  late ToolMode _mode = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverCollapsingAppBar(title: widget.title),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, 0),
            sliver: SliverToBoxAdapter(
              child: _ModeSwitch(
                mode: _mode,
                autoLabel: widget.autoLabel,
                manualLabel: widget.manualLabel,
                onChanged: (m) => setState(() => _mode = m),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.lg, Spacing.lg, 96),
            sliver: SliverToBoxAdapter(
              // Re-key per mode so entrance animations replay on switch.
              child: KeyedSubtree(
                key: ValueKey(_mode),
                child: widget.builder(context, _mode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Themed two-option segmented control (Auto | Manual). The selected segment is
/// filled with the accent; the pill slides between them.
class _ModeSwitch extends StatelessWidget {
  final ToolMode mode;
  final String autoLabel;
  final String manualLabel;
  final ValueChanged<ToolMode> onChanged;
  const _ModeSwitch({
    required this.mode,
    required this.autoLabel,
    required this.manualLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          _seg(context, ToolMode.auto, Icons.bolt_rounded, autoLabel),
          _seg(context, ToolMode.manual, Icons.edit_outlined, manualLabel),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, ToolMode m, IconData icon, String label) {
    final scheme = context.scheme;
    final selected = mode == m;
    return Expanded(
      child: SpringTap(
        onTap: selected ? null : () => onChanged(m),
        haptic: !selected,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? onAccent(scheme.primary) : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: context.text.labelLarge?.copyWith(
                      color: selected
                          ? onAccent(scheme.primary)
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsible "Data we're using" panel for Auto modes — shows the raw live
/// values feeding the calculation so the user can spot a wrong number. Intended
/// to be removed once Auto is proven; kept prominent for now.
class DataUsedPanel extends StatelessWidget {
  final List<(String, String)> rows;
  final String note;
  const DataUsedPanel({
    super.key,
    required this.rows,
    this.note = 'Pulled live from your UCAM data. If anything looks wrong, '
        'open the matching page to refresh it.',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Data we’re using',
                  style: context.text.labelLarge?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(r.$1,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(r.$2,
                        textAlign: TextAlign.right,
                        style: context.text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.sm),
          Text(note,
              style: context.text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }
}
