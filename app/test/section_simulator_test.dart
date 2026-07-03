import 'package:flutter_test/flutter_test.dart';
import 'package:open_campus/features/sections/section_catalog_model.dart';
import 'package:open_campus/features/sections/simulator_engine.dart';

// Helpers to build catalog data tersely.
ScheduleSlot slot(String day, String start, String end) =>
    ScheduleSlot(day: day, start: start, end: end);

CatalogSection sec(String name, String facCode,
        {List<ScheduleSlot> sched = const [], int cap = 40}) =>
    CatalogSection(
      section: name,
      facultyCode: facCode,
      facultyName: facCode,
      capacity: cap,
      schedule: sched,
      kind: sched.length == 2
          ? 'theory'
          : sched.length == 1
              ? 'lab'
              : 'unscheduled',
    );

CatalogCourse course(String code, List<CatalogSection> secs) =>
    CatalogCourse(formalCode: code, sections: secs);

void main() {
  group('ScheduleSlot conflict', () {
    test('same day overlapping intervals conflict', () {
      expect(slot('Saturday', '08:30', '09:50')
          .conflictsWith(slot('Saturday', '09:00', '10:20')), isTrue);
    });
    test('same day back-to-back (half-open) do NOT conflict', () {
      expect(slot('Saturday', '08:30', '09:50')
          .conflictsWith(slot('Saturday', '09:51', '11:10')), isFalse);
    });
    test('different days never conflict', () {
      expect(slot('Saturday', '08:30', '09:50')
          .conflictsWith(slot('Sunday', '08:30', '09:50')), isFalse);
    });
  });

  group('Section conflict (theory two-day blocks)', () {
    test('Sat-Tue vs Sun-Wed at same time do not conflict', () {
      final a = sec('A', 'X', sched: [
        slot('Saturday', '08:30', '09:50'),
        slot('Tuesday', '08:30', '09:50'),
      ]);
      final b = sec('B', 'Y', sched: [
        slot('Sunday', '08:30', '09:50'),
        slot('Wednesday', '08:30', '09:50'),
      ]);
      expect(a.conflictsWith(b), isFalse);
    });
    test('two Sat-Tue sections at same time conflict', () {
      final a = sec('A', 'X', sched: [
        slot('Saturday', '08:30', '09:50'),
        slot('Tuesday', '08:30', '09:50'),
      ]);
      final b = sec('B', 'Y', sched: [
        slot('Saturday', '09:00', '10:20'),
        slot('Tuesday', '09:00', '10:20'),
      ]);
      expect(a.conflictsWith(b), isTrue);
    });
  });

  group('Engine: conflict-free selection', () {
    test('finds a perfect conflict-free combination when one exists', () {
      final c1 = course('CSE 1111', [
        sec('A', 'ATR', sched: [
          slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50'),
        ]),
      ]);
      final c2 = course('CSE 2233', [
        // conflicts with c1.A (same Sat-Tue slot)
        sec('A', 'MNH', sched: [
          slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50'),
        ]),
        // clean: Sun-Wed
        sec('B', 'MNH', sched: [
          slot('Sunday', '08:30', '09:50'),
          slot('Wednesday', '08:30', '09:50'),
        ]),
      ]);
      final engine = SimulatorEngine(
        wanted: [
          CoursePreference(formalCode: 'CSE 1111', course: c1),
          CoursePreference(formalCode: 'CSE 2233', course: c2),
        ],
        prefs: const SimulatorPreferences(),
      );
      final results = engine.build();
      expect(results, isNotEmpty);
      final best = results.first;
      expect(best.conflictFree, isTrue);
      expect(best.isPerfect, isTrue);
      // The clean pick for c2 must be section B.
      final c2pick = best.picks.firstWhere((p) => p.formalCode == 'CSE 2233');
      expect(c2pick.section.section, 'B');
    });
  });

  group('Engine: faculty preference ranking', () {
    test('prefers the wanted faculty even across multiple sections', () {
      final c = course('CSE 1111', [
        sec('A', 'AAA', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
        sec('B', 'WANT', sched: [slot('Sunday', '08:30', '09:50'),
          slot('Wednesday', '08:30', '09:50')]),
      ]);
      final engine = SimulatorEngine(
        wanted: [
          CoursePreference(
              formalCode: 'CSE 1111',
              course: c,
              preferredFacultyCodes: const ['WANT']),
        ],
        prefs: const SimulatorPreferences(),
      );
      final best = engine.build().first;
      expect(best.picks.single.section.facultyCode, 'WANT');
      expect(best.isPerfect, isTrue);
    });
  });

  group('Engine: never emits a clash when a clean combo exists', () {
    test('theory (Sat+Tue) that would clash with a lab is avoided', () {
      // Mirrors the real bug: AI theory Sec D (Sat+Tue 11:11) overlaps AI Lab
      // Sec B (Sat 11:11). A conflict-free pick exists (AI Sun+Wed, or a
      // non-overlapping lab), so NO result may contain the clash.
      final aiTheory = course('CSE 3811', [
        // Sec D — clashes with the lab on Saturday 11:11.
        sec('D', 'ShAhd', sched: [
          slot('Saturday', '11:11', '12:30'),
          slot('Tuesday', '11:11', '12:30'),
        ]),
        // Sec F — clean (Sun+Wed).
        sec('F', 'NaFA', sched: [
          slot('Sunday', '15:11', '16:30'),
          slot('Wednesday', '15:11', '16:30'),
        ]),
      ]);
      final aiLab = course('CSE 3812', [
        sec('B', 'FzAn', sched: [slot('Saturday', '11:11', '13:40')]),
      ]);
      final engine = SimulatorEngine(
        wanted: [
          CoursePreference(formalCode: 'CSE 3811', course: aiTheory),
          CoursePreference(formalCode: 'CSE 3812', course: aiLab),
        ],
        prefs: const SimulatorPreferences(),
      );
      final results = engine.build();
      expect(results, isNotEmpty);
      // EVERY returned schedule must be conflict-free.
      expect(results.every((r) => r.conflictFree), isTrue,
          reason: 'a clash was emitted despite a conflict-free option');
      // And the AI theory pick must be the clean Sun+Wed section F.
      final aiPick =
          results.first.picks.firstWhere((p) => p.formalCode == 'CSE 3811');
      expect(aiPick.section.section, 'F');
    });

    test('TBA-faculty sections are still schedulable', () {
      // A section with no announced faculty is a real, takeable section.
      final c = course('CSE 3811', [
        CatalogSection(
          section: 'A',
          facultyName: null,
          facultyCode: null, // TBA
          schedule: [
            slot('Saturday', '08:30', '09:50'),
            slot('Tuesday', '08:30', '09:50'),
          ],
          kind: 'theory',
        ),
      ]);
      final engine = SimulatorEngine(
        wanted: [CoursePreference(formalCode: 'CSE 3811', course: c)],
        prefs: const SimulatorPreferences(),
      );
      final results = engine.build();
      expect(results, isNotEmpty);
      expect(results.first.picks.single.section.section, 'A');
    });
  });

  group('Engine: best-partial when no perfect combo', () {
    test('reports sacrifice when preferred faculty is unavailable conflict-free',
        () {
      // Two courses. The ONLY way to be conflict-free forces course2 off its
      // preferred faculty.
      final c1 = course('C1', [
        sec('A', 'F1', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
      ]);
      final c2 = course('C2', [
        // preferred faculty PREF but clashes with c1.A
        sec('A', 'PREF', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
        // non-preferred faculty OTHER but conflict-free
        sec('B', 'OTHER', sched: [slot('Sunday', '08:30', '09:50'),
          slot('Wednesday', '08:30', '09:50')]),
      ]);
      final engine = SimulatorEngine(
        wanted: [
          CoursePreference(formalCode: 'C1', course: c1),
          CoursePreference(
              formalCode: 'C2', course: c2, preferredFacultyCodes: const ['PREF']),
        ],
        prefs: const SimulatorPreferences(),
      );
      final best = engine.build().first;
      // Best conflict-free option sacrifices the preferred faculty.
      expect(best.conflictFree, isTrue);
      expect(best.isPerfect, isFalse);
      expect(best.sacrifices.any((s) => s.contains('C2')), isTrue);
      final c2pick = best.picks.firstWhere((p) => p.formalCode == 'C2');
      expect(c2pick.facultyMissed, isTrue);
    });
  });

  group('Engine: avoid blocks and time window', () {
    test('never picks a section inside a hard avoid block', () {
      final c = course('C1', [
        sec('A', 'X', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
        sec('B', 'Y', sched: [slot('Sunday', '14:00', '15:20'),
          slot('Wednesday', '14:00', '15:20')]),
      ]);
      // Block all of Saturday morning -> section A becomes unusable.
      final engine = SimulatorEngine(
        wanted: [CoursePreference(formalCode: 'C1', course: c)],
        prefs: const SimulatorPreferences(avoid: [
          AvoidBlock(day: 'Saturday', startMin: 8 * 60, endMin: 12 * 60),
        ]),
      );
      final best = engine.build().first;
      expect(best.picks.single.section.section, 'B');
    });

    test('penalizes sections outside the preferred time window', () {
      final c = course('C1', [
        sec('early', 'X', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
        sec('late', 'Y', sched: [slot('Saturday', '11:11', '12:30'),
          slot('Tuesday', '11:11', '12:30')]),
      ]);
      // Prefer classes starting 09:00 or later -> 'early' violates.
      final engine = SimulatorEngine(
        wanted: [CoursePreference(formalCode: 'C1', course: c)],
        prefs: const SimulatorPreferences(
            timeWindow: TimeWindow(earliestMin: 9 * 60, latestMin: 18 * 60)),
      );
      final best = engine.build().first;
      expect(best.picks.single.section.section, 'late');
    });
  });

  group('Catalog code matching', () {
    test('courseByCode is space/case insensitive', () {
      final cat = SectionCatalogData(courses: [course('CSE 1111', const [])]);
      expect(cat.courseByCode('cse1111')?.formalCode, 'CSE 1111');
      expect(cat.courseByCode('CSE  1111')?.formalCode, 'CSE 1111');
      expect(cat.courseByCode('CSE 9999'), isNull);
    });
  });

  group('12-hour clock formatting', () {
    test('converts 24h to friendly 12h', () {
      expect(to12h('08:30'), '8:30 AM');
      expect(to12h('13:50'), '1:50 PM');
      expect(to12h('00:15'), '12:15 AM');
      expect(to12h('12:00'), '12:00 PM');
      expect(to12h('23:59'), '11:59 PM');
    });
    test('accepts already-12h input and normalizes it', () {
      expect(to12h('9:00 AM'), '9:00 AM');
      expect(to12h('1:50 PM'), '1:50 PM');
    });
    test('returns input unchanged when unparseable or out of range', () {
      expect(to12h('nope'), 'nope');
      expect(to12h('24:00'), '24:00'); // out of range → not silently mangled
      expect(to12h('9:70'), '9:70');
    });
  });

  group('Time parsing safety', () {
    test('unparseable time on the same day is treated as a CLASH (fail-safe)', () {
      // A section with a broken time must NOT be silently scheduled on top of
      // another and called "conflict-free".
      final good = slot('Saturday', '08:30', '09:50');
      const broken = ScheduleSlot(day: 'Saturday', start: 'TBA', end: '');
      expect(good.conflictsWith(broken), isTrue);
      expect(broken.conflictsWith(good), isTrue);
    });
    test('out-of-range times are rejected (no minutes)', () {
      expect(
          const ScheduleSlot(day: 'Sat', start: '24:00', end: '25:00')
              .hasValidTimes,
          isFalse);
      expect(
          const ScheduleSlot(day: 'Sat', start: '08:30', end: '09:50')
              .hasValidTimes,
          isTrue);
    });
  });

  group('Engine: deep conflict-free find + dedup', () {
    test('finds a conflict-free schedule even when cheap sections all clash', () {
      // Two courses whose FIRST (cheapest) sections clash; the only clean combo
      // needs the later sections. The engine must find it, not fall back to a
      // clash.
      final a = course('A', [
        sec('1', 'X', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
        sec('2', 'X', sched: [slot('Sunday', '08:30', '09:50'),
          slot('Wednesday', '08:30', '09:50')]),
      ]);
      final b = course('B', [
        sec('1', 'Y', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]), // clashes with A.1
        sec('2', 'Y', sched: [slot('Saturday', '11:11', '12:30'),
          slot('Tuesday', '11:11', '12:30')]), // clean vs A.1
      ]);
      final engine = SimulatorEngine(
        wanted: [
          CoursePreference(formalCode: 'A', course: a),
          CoursePreference(formalCode: 'B', course: b),
        ],
        prefs: const SimulatorPreferences(),
      );
      final results = engine.build();
      expect(results.every((r) => r.conflictFree), isTrue);
      expect(results.first.isPerfect, isTrue);
    });

    test('does not return duplicate identical schedules', () {
      // Two sections of B with the SAME schedule but different letters → picking
      // either yields an identical calendar; only ONE should appear.
      final a = course('A', [
        sec('1', 'X', sched: [slot('Saturday', '08:30', '09:50'),
          slot('Tuesday', '08:30', '09:50')]),
      ]);
      final b = course('B', [
        sec('1', 'Y', sched: [slot('Sunday', '08:30', '09:50'),
          slot('Wednesday', '08:30', '09:50')]),
        sec('2', 'Z', sched: [slot('Sunday', '08:30', '09:50'),
          slot('Wednesday', '08:30', '09:50')]), // identical schedule to B.1
      ]);
      final engine = SimulatorEngine(
        wanted: [
          CoursePreference(formalCode: 'A', course: a),
          CoursePreference(formalCode: 'B', course: b),
        ],
        prefs: const SimulatorPreferences(),
      );
      final results = engine.build();
      // Only one distinct schedule (A.1 + B at Sun/Wed 8:30), not two.
      expect(results.length, 1);
    });
  });

  group('Catalog subject grouping', () {
    test('subjectOf extracts the letter prefix', () {
      expect(SectionCatalogData.subjectOf('CSE 1111'), 'CSE');
      expect(SectionCatalogData.subjectOf('MATH 2205'), 'MATH');
      expect(SectionCatalogData.subjectOf('  eee 101 '), 'EEE');
    });

    test('coursesBySubject groups and sorts by subject then code', () {
      final cat = SectionCatalogData(courses: [
        course('EEE 2101', const []),
        course('CSE 2233', const []),
        course('CSE 1111', const []),
      ]);
      final groups = cat.coursesBySubject;
      expect(groups.map((e) => e.key).toList(), ['CSE', 'EEE']);
      expect(groups.first.value.map((c) => c.formalCode).toList(),
          ['CSE 1111', 'CSE 2233']);
    });
  });
}
