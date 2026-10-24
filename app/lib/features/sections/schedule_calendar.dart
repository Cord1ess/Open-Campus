import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'section_catalog_model.dart';
import 'simulator_engine.dart';

/// Weekly calendar grid of one built schedule: days are columns, time runs
/// down, each class is a block positioned/sized by its real start/end time.
///
/// Block top = (start - dayStart) and height = duration on one minutes-per-
/// pixel scale, so overlaps and gaps are truthful. Colours come from the theme
/// palette's series, assigned per course in first-seen order (the legend in
/// schedule_detail_page uses the same rule).
class ScheduleCalendarView extends StatelessWidget {
  final ScheduleCandidate candidate;
  final String? title;

  const ScheduleCalendarView({super.key, required this.candidate, this.title});

  static const _minPerPx = 1.6; // vertical scale: minutes per logical pixel
  static const _hourLabelW = 44.0; // left gutter for hour labels
  static const _headerH = 34.0; // day-name header height
  static const _pad = 6.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final series = context.palette.series;

    final meetings = <_Meeting>[];
    for (final pick in candidate.picks) {
      final s = pick.section;
      for (final slot in s.schedule) {
        final start = slot.startMin, end = slot.endMin;
        if (start == null || end == null) continue;
        meetings.add(_Meeting(
          day: slot.day,
          startMin: start,
          endMin: end,
          courseName: pick.courseName ?? pick.formalCode,
          courseCode: pick.formalCode,
          section: s.section,
          faculty: s.facultyName ?? s.facultyCode,
          room: s.room,
        ));
      }
    }

    final dayset = meetings.map((m) => m.day).toSet().toList()
      ..sort((a, b) => weekdayRank(a).compareTo(weekdayRank(b)));

    if (dayset.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Text('This schedule has no timed classes to plot.',
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    var minStart = meetings.map((m) => m.startMin).reduce((a, b) => a < b ? a : b);
    var maxEnd = meetings.map((m) => m.endMin).reduce((a, b) => a > b ? a : b);
    minStart = (minStart ~/ 60) * 60;
    maxEnd = ((maxEnd + 59) ~/ 60) * 60;
    final totalMin = maxEnd - minStart;
    final gridH = totalMin / _minPerPx;

    // Stable per-course colour (same course = same colour), first-seen order.
    final courseColors = <String, Color>{};
    var ci = 0;
    for (final m in meetings) {
      courseColors.putIfAbsent(
          m.courseCode, () => series[ci++ % series.length]);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final avail = constraints.maxWidth - _hourLabelW;
      const minCol = 96.0;
      final colW = (avail / dayset.length).clamp(minCol, 240.0);
      final gridW = _hourLabelW + colW * dayset.length;

      final grid = SizedBox(
        width: gridW,
        height: _headerH + gridH + _pad * 2,
        child: Stack(
          children: [
            ..._hourLines(context, minStart, maxEnd, gridW, colW, dayset.length),
            for (var d = 0; d < dayset.length; d++)
              Positioned(
                left: _hourLabelW + d * colW,
                top: 0,
                width: colW,
                height: _headerH,
                child: Center(
                  child: Text(_shortDay(dayset[d]),
                      style: context.text.titleSmall
                          ?.copyWith(color: scheme.onSurface)),
                ),
              ),
            for (final placed in _layoutLanes(meetings, dayset))
              _positionedBlock(
                context,
                placed.meeting,
                dayIndex: dayset.indexOf(placed.meeting.day),
                colW: colW,
                minStart: minStart,
                color: courseColors[placed.meeting.courseCode]!,
                lane: placed.lane,
                laneCount: placed.laneCount,
              ),
          ],
        ),
      );

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: grid,
      );
    });
  }

  List<Widget> _hourLines(BuildContext context, int minStart, int maxEnd,
      double gridW, double colW, int dayCount) {
    final scheme = context.scheme;
    final lines = <Widget>[];
    for (var t = minStart; t <= maxEnd; t += 60) {
      final y = _headerH + _pad + (t - minStart) / _minPerPx;
      lines.add(Positioned(
        left: 0,
        top: y,
        width: gridW,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _hourLabelW,
              child: Text(
                to12h('${(t ~/ 60).toString().padLeft(2, '0')}:00')
                    .replaceAll(':00', ''),
                textAlign: TextAlign.right,
                style: context.text.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Expanded(
                child: Container(height: 1, color: scheme.outlineVariant)),
          ],
        ),
      ));
    }
    return lines;
  }

  Widget _positionedBlock(
    BuildContext context,
    _Meeting m, {
    required int dayIndex,
    required double colW,
    required int minStart,
    required Color color,
    int lane = 0,
    int laneCount = 1,
  }) {
    final top = _headerH + _pad + (m.startMin - minStart) / _minPerPx;
    final rawH = (m.endMin - m.startMin) / _minPerPx;
    final height = rawH.clamp(16.0, 100000.0);
    final fg = onColor(color);
    final compact = height < 46;

    final laneW = (colW - 4) / laneCount;
    final left = _hourLabelW + dayIndex * colW + 2 + lane * laneW;

    final small = context.text.labelSmall;

    return Positioned(
      left: left,
      top: top,
      width: laneW - (laneCount > 1 ? 2 : 0),
      height: (height - 2).clamp(14.0, 100000.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs + Spacing.xxs, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.courseName,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: small?.copyWith(
                    color: fg, fontWeight: FontWeight.w600, height: 1.1),
              ),
              if (!compact) ...[
                if (m.section != null) ...[
                  const SizedBox(height: 1),
                  Text('Sec ${m.section}',
                      style: small?.copyWith(color: fg, height: 1.1)),
                ],
                const Spacer(),
                Text(
                  '${to12h(_mm(m.startMin))}–${to12h(_mm(m.endMin))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small?.copyWith(
                      color: fg, height: 1.1, fontFeatures: tabularFigures),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _mm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _shortDay(String day) =>
      day.length >= 3 ? day.substring(0, 3) : day;

  /// Assign each meeting a lane within its day so overlapping classes render
  /// side-by-side (the clash case). Non-overlapping classes get lane 0 of 1.
  static List<_PlacedMeeting> _layoutLanes(
      List<_Meeting> meetings, List<String> dayset) {
    final placed = <_PlacedMeeting>[];
    for (final day in dayset) {
      final dayMeetings = meetings.where((m) => m.day == day).toList()
        ..sort((a, b) => a.startMin.compareTo(b.startMin));
      var i = 0;
      while (i < dayMeetings.length) {
        var clusterEnd = dayMeetings[i].endMin;
        var j = i + 1;
        while (j < dayMeetings.length && dayMeetings[j].startMin < clusterEnd) {
          if (dayMeetings[j].endMin > clusterEnd) clusterEnd = dayMeetings[j].endMin;
          j++;
        }
        final cluster = dayMeetings.sublist(i, j);
        final laneEnds = <int>[];
        final laneOf = <int>[];
        for (final m in cluster) {
          var lane = -1;
          for (var l = 0; l < laneEnds.length; l++) {
            if (m.startMin >= laneEnds[l]) {
              lane = l;
              break;
            }
          }
          if (lane == -1) {
            lane = laneEnds.length;
            laneEnds.add(m.endMin);
          } else {
            laneEnds[lane] = m.endMin;
          }
          laneOf.add(lane);
        }
        final laneCount = laneEnds.length;
        for (var k = 0; k < cluster.length; k++) {
          placed.add(_PlacedMeeting(cluster[k], laneOf[k], laneCount));
        }
        i = j;
      }
    }
    return placed;
  }
}

class _PlacedMeeting {
  final _Meeting meeting;
  final int lane;
  final int laneCount;
  _PlacedMeeting(this.meeting, this.lane, this.laneCount);
}

class _Meeting {
  final String day;
  final int startMin;
  final int endMin;
  final String courseName;
  final String courseCode;
  final String? section;
  final String? faculty;
  final String? room;

  _Meeting({
    required this.day,
    required this.startMin,
    required this.endMin,
    required this.courseName,
    required this.courseCode,
    required this.section,
    required this.faculty,
    required this.room,
  });
}
