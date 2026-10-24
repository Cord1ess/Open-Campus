/// Barrel for the design-system widgets. Import this one file from a screen.
library;

export '../core/theme/motion.dart'
    show appRoute, Reveal, PressScale, CountUp, IdleSpin, LiveDot, reduceMotion;
export 'app_icons.dart';
export 'expressive_shape.dart';
export 'info_note.dart';
export 'list_row.dart';
export 'page_scaffold.dart';
export 'responsive.dart';
export 'secret_value.dart';
export 'charts.dart';
export 'segmented_control.dart';
export 'simple_table.dart';
export 'stat_block.dart';
export 'states.dart';
export 'status_badge.dart';

/// Freshness state for a resource (live vs. on-device copy).
enum Freshness { live, cached }
