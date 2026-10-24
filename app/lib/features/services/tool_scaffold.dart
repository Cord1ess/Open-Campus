import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// The two modes every Services tool offers.
enum ToolMode { auto, manual }

/// Shared frame for the Services tools (GPA, Tuition): a page with an
/// Auto / Manual segmented control at the top, then the active mode's content.
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
    return PageScaffold(
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormWidth(
            maxWidth: 360,
            child: SegmentedControl<ToolMode>(
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
              options: [
                SegmentOption(ToolMode.auto, widget.autoLabel),
                SegmentOption(ToolMode.manual, widget.manualLabel),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Cross-fade between Auto and Manual; each body staggers its own
          // sections in with Reveal.
          AnimatedSwitcher(
            duration: Motion.medium,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: KeyedSubtree(
              key: ValueKey(_mode),
              child: widget.builder(context, _mode),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Data we're using" — the live values feeding an Auto calculation, so the
/// user can spot a wrong number.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowGroup(
          title: 'Data we’re using',
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: KeyValueRow(label: r.$1, value: r.$2),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Text(note, style: context.text.bodySmall),
      ],
    );
  }
}
