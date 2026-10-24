// Selection simulator engine — pure logic, no Flutter imports (so it's fully
// unit-testable).
//
// Given the courses a student wants to take and the sections available for each
// (from the catalog), it builds conflict-free combinations — one section picked
// per course — and ranks them by the student's stated preferences:
//   - preferred faculty per course (ranked),
//   - preferred time windows (e.g. "no class before 09:00"),
//   - compactness / fewest days on campus,
//   - hard-avoided day+time blocks.
//
// When NO combination can satisfy every preference conflict-free, it still
// returns the best partial combinations, each annotated with what it sacrificed
// (which preferred faculty missed, which time rule broken) so the UI can show
// "closest options" honestly instead of an empty result.

import 'section_catalog_model.dart';

/// A hard block the student is unavailable for (e.g. a job, commute). Any
/// section touching this day within [startMin, endMin) is disallowed outright.
class AvoidBlock {
  final String day;
  final int startMin; // minutes since midnight
  final int endMin;
  const AvoidBlock(
      {required this.day, required this.startMin, required this.endMin});

  bool blocks(ScheduleSlot slot) {
    if (slot.day != day) return false;
    final s = slot.startMin, e = slot.endMin;
    if (s == null || e == null) return false;
    return s < endMin && startMin < e;
  }
}

/// A soft "prefer classes within this window" rule. Sections with any slot
/// outside [earliestMin, latestMin) are penalized (not excluded).
class TimeWindow {
  final int earliestMin; // no class should START before this
  final int latestMin; // no class should END after this
  const TimeWindow({this.earliestMin = 0, this.latestMin = 24 * 60});

  /// How many of a section's slots fall outside the preferred window.
  int violations(CatalogSection s) {
    var n = 0;
    for (final slot in s.schedule) {
      final st = slot.startMin, en = slot.endMin;
      if (st == null || en == null) continue;
      if (st < earliestMin || en > latestMin) n++;
    }
    return n;
  }
}

/// What the student wants for ONE course they're taking.
class CoursePreference {
  final String formalCode;
  final CatalogCourse course;

  /// Faculty codes in priority order (most-wanted first). Empty = no preference.
  final List<String> preferredFacultyCodes;

  const CoursePreference({
    required this.formalCode,
    required this.course,
    this.preferredFacultyCodes = const [],
  });

  /// Rank of a section's faculty in this preference (0 = top choice). Returns
  /// null if the faculty isn't in the preferred list (or no preference set).
  int? facultyRank(CatalogSection s) {
    if (preferredFacultyCodes.isEmpty) return null;
    final i = preferredFacultyCodes.indexOf(s.facultyCode ?? '');
    return i < 0 ? null : i;
  }
}

/// The knobs that shape ranking, with sensible defaults.
class SimulatorPreferences {
  final TimeWindow? timeWindow;
  final List<AvoidBlock> avoid;

  /// Prefer schedules that use fewer distinct days on campus.
  final bool preferFewerDays;

  /// Relative weights (higher = matters more). Faculty preference usually
  /// dominates because it's the whole point of the section race.
  final double wFacultyMiss; // per rank-weighted faculty miss
  final double wTimeWindow; // per slot outside the preferred window
  final double wDaysOnCampus; // per distinct day used

  const SimulatorPreferences({
    this.timeWindow,
    this.avoid = const [],
    this.preferFewerDays = true,
    this.wFacultyMiss = 100.0,
    this.wTimeWindow = 8.0,
    this.wDaysOnCampus = 3.0,
  });
}

/// One picked section within a combination, plus why it did/didn't match.
class PickedSection {
  final String formalCode;

  /// Human-readable course name (for display); falls back to the code.
  final String? courseName;
  final CatalogSection section;

  /// null = faculty preference met (or none set); otherwise the rank the
  /// student had to settle for (0 = still got top choice).
  final int? facultyRank;

  /// True if this course had a faculty preference but this section matched none.
  final bool facultyMissed;

  const PickedSection({
    required this.formalCode,
    this.courseName,
    required this.section,
    required this.facultyRank,
    required this.facultyMissed,
  });
}

/// A full candidate schedule: one section per course, scored and explained.
class ScheduleCandidate {
  final List<PickedSection> picks;
  final double score; // lower is better (0 = perfect)
  final bool conflictFree;

  /// Human-facing sacrifices, e.g. "CSE 3421: got 2nd-choice faculty",
  /// "Sat 08:30 is outside your preferred time". Empty for a perfect schedule.
  final List<String> sacrifices;

  /// Distinct days this schedule requires on campus, in week order.
  final List<String> daysOnCampus;

  const ScheduleCandidate({
    required this.picks,
    required this.score,
    required this.conflictFree,
    required this.sacrifices,
    required this.daysOnCampus,
  });

  bool get isPerfect => conflictFree && sacrifices.isEmpty;
}

/// Builds and ranks schedules. See [build].
class SimulatorEngine {
  final List<CoursePreference> wanted;
  final SimulatorPreferences prefs;

  SimulatorEngine({required this.wanted, required this.prefs});

  /// Return up to [limit] best candidates, best (lowest score) first.
  ///
  /// Strategy: for each course, order its sections by how well they match that
  /// course's own preferences (so we explore promising picks first), drop any
  /// section that hits a hard AvoidBlock, then do a bounded search over the
  /// cartesian product pruning on conflict as we go. Because the per-course
  /// lists are pre-sorted, the first conflict-free full assignment found tends
  /// to be near-optimal; we keep the best [limit] by score.
  List<ScheduleCandidate> build({int limit = 20}) {
    // Per-course candidate sections (avoid-filtered, preference-ordered).
    final perCourse = <_CourseCandidates>[];
    for (final w in wanted) {
      final usable = w.course.sections.where((s) => !_hitsAvoid(s)).toList()
        ..sort((a, b) => _sectionCost(w, a).compareTo(_sectionCost(w, b)));
      perCourse.add(_CourseCandidates(w, usable));
    }

    // First pass: emit ONLY conflict-free schedules — clashes are pruned during
    // the search, so a clashing combination can never become a result.
    //
    // We collect a generous multiple of `limit` distinct schedules (not just
    // `limit`), then keep the best. Collecting more than we show guards against
    // a subtle bug: because sections are ordered by preference cost (not by how
    // "schedulable" they are), the cheapest-first branches can clash and be
    // pruned; a fixed tiny budget could stop before reaching the conflict-free
    // combination that lives deeper in the product, wrongly concluding "no
    // conflict-free schedule exists" and falling through to the clash fallback.
    // The node cap below is high and counts VISITS (not just leaves), so the
    // search is bounded but won't quit before exhausting a realistic course
    // load's product.
    final target = (limit * 4).clamp(20, 200);
    _visits = 0;
    _seen.clear();
    final clean = <ScheduleCandidate>[];
    _search(perCourse, 0, <_Assigned>[], clean,
        allowConflicts: false, stopAt: target);

    if (clean.isNotEmpty) {
      clean.sort((a, b) => a.score.compareTo(b.score));
      return clean.take(limit).toList();
    }

    // Fallback: no conflict-free arrangement exists for this course set. Show
    // the closest-possible options (clearly labelled "Has a time clash") so the
    // user can drop/swap a course. Only runs when truly unavoidable.
    _visits = 0;
    _seen.clear();
    final any = <ScheduleCandidate>[];
    _search(perCourse, 0, <_Assigned>[], any,
        allowConflicts: true, stopAt: target);
    any.sort((a, b) {
      if (a.conflictFree != b.conflictFree) return a.conflictFree ? -1 : 1;
      return a.score.compareTo(b.score);
    });
    return any.take(limit).toList();
  }

  // --- internals -------------------------------------------------------------

  bool _hitsAvoid(CatalogSection s) {
    for (final slot in s.schedule) {
      for (final block in prefs.avoid) {
        if (block.blocks(slot)) return true;
      }
    }
    return false;
  }

  /// Cost of choosing [s] for course [w], ignoring cross-course conflicts.
  double _sectionCost(CoursePreference w, CatalogSection s) {
    var cost = 0.0;
    final rank = w.facultyRank(s);
    if (w.preferredFacultyCodes.isNotEmpty) {
      if (rank == null) {
        cost += prefs.wFacultyMiss * (w.preferredFacultyCodes.length + 1);
      } else {
        cost += prefs.wFacultyMiss * rank; // 0 for top choice
      }
    }
    if (prefs.timeWindow != null) {
      cost += prefs.wTimeWindow * prefs.timeWindow!.violations(s);
    }
    return cost;
  }

  /// Bounded DFS over courses. `_visits` counts every node entered (not just
  /// leaves), so a pathological input (many courses x many sections) can't hang
  /// the UI. The cap is high enough that a realistic course load is fully
  /// explored; conflict pruning keeps the real visit count far below it.
  static const int _maxVisits = 200000;
  int _visits = 0;

  /// Signatures of schedules already emitted, so identical schedules (e.g.
  /// tie-ranked faculty producing the same days/times) aren't repeated.
  final Set<String> _seen = <String>{};

  void _search(
    List<_CourseCandidates> perCourse,
    int idx,
    List<_Assigned> chosen,
    List<ScheduleCandidate> out, {
    required bool allowConflicts,
    required int stopAt,
  }) {
    if (_visits >= _maxVisits || out.length >= stopAt) return;
    _visits++;
    if (idx == perCourse.length) {
      final candidate = _materialize(chosen);
      final sig = _signature(chosen);
      if (_seen.add(sig)) out.add(candidate); // dedup identical schedules
      return;
    }
    final cc = perCourse[idx];
    if (cc.sections.isEmpty) {
      // No usable section for this course (all avoid-blocked): skip it, but the
      // schedule is necessarily imperfect. Represent as a null pick.
      chosen.add(_Assigned(cc.pref, null, conflictsSoFar: false));
      _search(perCourse, idx + 1, chosen, out,
          allowConflicts: allowConflicts, stopAt: stopAt);
      chosen.removeLast();
      return;
    }
    for (final s in cc.sections) {
      if (out.length >= stopAt || _visits >= _maxVisits) return;
      final conflicts = chosen.any(
        (a) => a.section != null && a.section!.conflictsWith(s),
      );
      // In the conflict-free pass, prune this branch entirely if the section
      // clashes with anything already chosen — so no clashing combination can
      // reach a leaf and become a result.
      if (conflicts && !allowConflicts) continue;
      chosen.add(_Assigned(cc.pref, s, conflictsSoFar: conflicts));
      _search(perCourse, idx + 1, chosen, out,
          allowConflicts: allowConflicts, stopAt: stopAt);
      chosen.removeLast();
    }
  }

  /// A stable identity for a schedule: the picked section per course, keyed by
  /// course and by the section's day/time footprint (so two different section
  /// letters with the same schedule collapse to one result).
  String _signature(List<_Assigned> chosen) {
    final parts = <String>[];
    for (final a in chosen) {
      final s = a.section;
      if (s == null) {
        parts.add('${a.pref.formalCode}=none');
      } else {
        final slots = s.schedule
            .map((x) => '${x.day}:${x.start}-${x.end}')
            .toList()
          ..sort();
        parts.add('${a.pref.formalCode}=${slots.join(",")}');
      }
    }
    parts.sort();
    return parts.join('|');
  }

  ScheduleCandidate _materialize(List<_Assigned> chosen) {
    final picks = <PickedSection>[];
    final sacrifices = <String>[];
    final daySet = <String>{};
    var score = 0.0;
    var anyConflict = false;

    for (final a in chosen) {
      final w = a.pref;
      final s = a.section;
      // Prefer the human course name in messages; fall back to the code.
      final label = w.course.name ?? w.formalCode;
      if (s == null) {
        sacrifices
            .add('No section of $label fits your constraints — try relaxing a '
                'day-block or time window.');
        score += prefs.wFacultyMiss * 10; // heavy — a course went unscheduled
        picks.add(PickedSection(
            formalCode: w.formalCode,
            courseName: w.course.name,
            section: const CatalogSection(),
            facultyRank: null,
            facultyMissed: true));
        continue;
      }
      for (final slot in s.schedule) {
        daySet.add(slot.day);
      }
      final rank = w.facultyRank(s);
      final missed = w.preferredFacultyCodes.isNotEmpty && rank == null;
      score += _sectionCost(w, s);
      // A readable faculty name, never a bare "?".
      final facLabel = s.facultyName ?? s.facultyCode ?? 'the assigned faculty';
      final secLabel =
          s.section != null ? 'section ${s.section}' : 'this section';
      if (missed) {
        sacrifices.add('For $label, none of your preferred faculty were free — '
            'this uses $facLabel instead.');
      } else if (rank != null && rank > 0) {
        final ordinal = rank == 1
            ? '2nd'
            : rank == 2
                ? '3rd'
                : '${rank + 1}th';
        sacrifices
            .add('For $label, your top faculty wasn\'t free — this uses your '
                '$ordinal choice, $facLabel.');
      }
      if (prefs.timeWindow != null) {
        final v = prefs.timeWindow!.violations(s);
        if (v > 0) {
          sacrifices
              .add('For $label, $secLabel falls outside your preferred hours.');
        }
      }
      picks.add(PickedSection(
          formalCode: w.formalCode,
          courseName: w.course.name,
          section: s,
          facultyRank: rank,
          facultyMissed: missed));
    }

    // Conflict penalty (only reached if a conflicted assignment slipped in;
    // build() prefers conflict-free, but keeps conflicted ones as last resort).
    anyConflict = _hasInternalConflict(chosen);
    if (anyConflict) {
      score += prefs.wFacultyMiss * 50;
      sacrifices.add('Two classes in this schedule overlap in time.');
    }

    if (prefs.preferFewerDays) {
      score += prefs.wDaysOnCampus * daySet.length;
    }

    final days = daySet.toList()
      ..sort((a, b) => weekdayRank(a).compareTo(weekdayRank(b)));

    return ScheduleCandidate(
      picks: picks,
      score: score,
      conflictFree: !anyConflict,
      sacrifices: sacrifices,
      daysOnCampus: days,
    );
  }

  bool _hasInternalConflict(List<_Assigned> chosen) {
    final secs =
        chosen.map((a) => a.section).whereType<CatalogSection>().toList();
    for (var i = 0; i < secs.length; i++) {
      for (var j = i + 1; j < secs.length; j++) {
        if (secs[i].conflictsWith(secs[j])) return true;
      }
    }
    return false;
  }
}

class _CourseCandidates {
  final CoursePreference pref;
  final List<CatalogSection> sections;
  _CourseCandidates(this.pref, this.sections);
}

class _Assigned {
  final CoursePreference pref;
  final CatalogSection? section;
  final bool conflictsSoFar;
  _Assigned(this.pref, this.section, {required this.conflictsSoFar});
}
