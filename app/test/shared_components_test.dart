import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/core/theme/app_theme.dart';
import 'package:open_campus/shared/widgets.dart';

/// Widget tests for the design-system components: they render, respond to
/// taps, and the theme's contrast guarantees hold.
Widget _wrap(Widget child, {Size size = const Size(390, 844), ThemeData? theme}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AppTheme contrast', () {
    test('accent ink reads on the light surface (>= 4.5:1)', () {
      final t = AppTheme.light();
      final p = t.extension<AppPalette>()!;
      expect(contrastRatio(p.accentInk, t.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(p.infoInk, t.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(p.successInk, t.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(p.warningInk, t.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(p.dangerInk, t.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('accent ink reads on dark and black surfaces', () {
      for (final t in [AppTheme.dark(), AppTheme.dark(black: true)]) {
        final p = t.extension<AppPalette>()!;
        expect(contrastRatio(p.accentInk, t.colorScheme.surface),
            greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.infoInk, t.colorScheme.surface),
            greaterThanOrEqualTo(4.5));
      }
    });

    test('text on the accent fill is readable for every seed', () {
      const seeds = [
        AppColors.customSeed,
        Color(0xFF05BADD),
        Color(0xFFE8A100),
        Color(0xFF7C3AED),
        Color(0xFF546A7B),
      ];
      for (final s in seeds) {
        final t = AppTheme.light(seed: s);
        expect(contrastRatio(t.colorScheme.onPrimary, t.colorScheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: 'seed $s');
        final p = t.extension<AppPalette>()!;
        expect(contrastRatio(p.accentInk, t.colorScheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'ink for seed $s');
      }
    });

    test('type scale uses Inter with neutral tracking', () {
      final t = AppTheme.light();
      expect(t.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(t.textTheme.titleLarge?.letterSpacing, 0);
      expect(t.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    });
  });

  group('States', () {
    testWidgets('ErrorState shows message and fires retry', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(ErrorState(
        message: 'Network down',
        onRetry: () => tapped++,
      )));
      expect(find.text('Couldn’t load'), findsOneWidget);
      expect(find.text('Network down'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(tapped, 1);
    });

    testWidgets('EmptyState without action has no button', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(title: 'Nothing here')));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('FreshnessLine hides when live and shows saved copy when cached',
        (tester) async {
      await tester.pumpWidget(_wrap(const FreshnessLine(live: true)));
      expect(find.byType(Icon), findsNothing);

      await tester.pumpWidget(_wrap(FreshnessLine(
        at: DateTime.now().subtract(const Duration(minutes: 5)),
        error: 'offline',
        onRetry: () {},
      )));
      expect(find.textContaining('Couldn’t refresh'), findsOneWidget);
      expect(find.textContaining('5 min ago'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('SegmentedControl', () {
    testWidgets('selects on tap and ignores disabled options', (tester) async {
      String? picked;
      await tester.pumpWidget(_wrap(SegmentedControl<String>(
        options: const [
          SegmentOption('a', 'All'),
          SegmentOption('b', 'Mine'),
          SegmentOption('c', 'Off', enabled: false),
        ],
        value: 'a',
        onChanged: (v) => picked = v,
      )));
      await tester.tap(find.text('Mine'));
      expect(picked, 'b');
      picked = null;
      await tester.tap(find.text('Off'));
      expect(picked, isNull);
    });
  });

  group('ListRow / RowGroup', () {
    testWidgets('renders title, subtitle, value and taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(RowGroup(
        title: 'Group',
        children: [
          ListRow(
            icon: AppIcons.results,
            title: 'Results',
            subtitle: 'GPA and CGPA',
            value: '3.80',
            onTap: () => taps++,
          ),
          const ListRow(title: 'Static'),
        ],
      )));
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('GPA and CGPA'), findsOneWidget);
      expect(find.text('3.80'), findsOneWidget);
      await tester.tap(find.text('Results'));
      expect(taps, 1);
      // Rows meet the 48-px touch minimum.
      final size = tester.getSize(find.byType(ListRow).first);
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('StatStrip', () {
    testWidgets('wraps to two columns on a phone with four items',
        (tester) async {
      await tester.pumpWidget(_wrap(const StatStrip(items: [
        StatBlock(label: 'A', value: '1'),
        StatBlock(label: 'B', value: '2'),
        StatBlock(label: 'C', value: '3'),
        StatBlock(label: 'D', value: '4'),
      ])));
      expect(find.byType(StatBlock), findsNWidgets(4));
      final a = tester.getTopLeft(find.text('A'));
      final c = tester.getTopLeft(find.text('C'));
      expect(c.dy, greaterThan(a.dy)); // C is on the second row
    });

    testWidgets('stays on one row on a wide screen', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const StatStrip(items: [
          StatBlock(label: 'A', value: '1'),
          StatBlock(label: 'B', value: '2'),
          StatBlock(label: 'C', value: '3'),
          StatBlock(label: 'D', value: '4'),
        ]),
        size: const Size(1400, 900),
      ));
      final a = tester.getTopLeft(find.text('A'));
      final d = tester.getTopLeft(find.text('D'));
      expect(d.dy, a.dy);
    });
  });

  group('SimpleTable', () {
    testWidgets('renders header and rows', (tester) async {
      await tester.pumpWidget(_wrap(const SimpleTable(
        columns: ['Term', 'GPA', 'CGPA'],
        rows: [
          ['Spring 2026', '3.75', '3.60'],
          ['Fall 2025', '3.50', '3.55'],
        ],
      )));
      expect(find.text('Term'), findsOneWidget);
      expect(find.text('3.75'), findsOneWidget);
      expect(find.text('Fall 2025'), findsOneWidget);
    });
  });

  group('PageScaffold', () {
    testWidgets('centres content on a desktop width and keeps gutters on phones',
        (tester) async {
      Future<double> leftOf(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_wrap(
          const PageScaffold(
            title: 'T',
            body: SizedBox(key: Key('body'), height: 10),
          ),
          size: size,
        ));
        return tester.getTopLeft(find.byKey(const Key('body'))).dx;
      }

      addTearDown(tester.view.reset);
      final phone = await leftOf(const Size(390, 844));
      expect(phone, Spacing.lg);
      final desktop = await leftOf(const Size(1600, 900));
      expect(desktop, (1600 - Breakpoints.contentMaxWidth) / 2);
    });
  });

  group('StatusBadge', () {
    testWidgets('renders label with the tone ink', (tester) async {
      await tester.pumpWidget(
          _wrap(const StatusBadge('Due', tone: StatusTone.warning)));
      final text = tester.widget<Text>(find.text('Due'));
      final theme = AppTheme.light();
      expect(text.style?.color, theme.extension<AppPalette>()!.warningInk);
    });
  });
}
