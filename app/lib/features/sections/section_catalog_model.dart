// Section catalog model — mirrors GET /catalog/sections.
//
// The catalog is the shared, per-trimester list of every course and its
// sections (faculty, room, schedule, capacity). It is the SAME for all
// students; the app filters it against the student's own pre-advised courses
// (from GET /student/advising) to build "Your Sections", and feeds it to the
// selection simulator. No live seat occupancy — `capacity` is the section's
// fixed size, not how many seats remain.

int? _intN(dynamic v) => v is num
    ? v.toInt()
    : (v is String ? int.tryParse(v) : null);
double? _numN(dynamic v) => v is num
    ? v.toDouble()
    : (v is String ? double.tryParse(v.replaceAll(',', '')) : null);
String? _strN(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Canonical week order (UIU weeks run Sat..Wed, occasionally Mon/Thu).
const List<String> kWeekDays = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];

int weekdayRank(String day) {
  final i = kWeekDays.indexOf(day);
  return i < 0 ? 99 : i;
}

/// Convert a "HH:MM" (24h) or "H:MM AM/PM" (12h) string to a friendly 12-hour
/// label, e.g. "08:30" -> "8:30 AM", "13:50" -> "1:50 PM", "00:15" -> "12:15 AM".
/// Returns the input unchanged if it can't be parsed — and uses the exact same
/// parser as conflict detection, so display and scheduling never disagree.
String to12h(String hhmm) {
  final mins = ScheduleSlot._toMinutes(hhmm);
  if (mins == null) return hhmm.trim();
  final h = mins ~/ 60;
  final m = mins % 60;
  final period = h < 12 ? 'AM' : 'PM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// A single class meeting: a day plus a [start, end) minute-of-day interval.
class ScheduleSlot {
  final String day;
  final String start; // "HH:MM"
  final String end; // "HH:MM"

  const ScheduleSlot({required this.day, required this.start, required this.end});

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) => ScheduleSlot(
        day: _strN(j['day']) ?? '',
        start: _strN(j['start']) ?? '',
        end: _strN(j['end']) ?? '',
      );

  Map<String, dynamic> toJson() => {'day': day, 'start': start, 'end': end};

  /// Minutes since midnight for [start]; null if unparseable.
  int? get startMin => _toMinutes(start);
  int? get endMin => _toMinutes(end);

  /// True when both endpoints parse to a valid minute-of-day and start < end.
  bool get hasValidTimes {
    final s = startMin, e = endMin;
    return s != null && e != null && s < e;
  }

  /// Parse a clock string to minutes-since-midnight. Accepts "HH:MM" (24h) and
  /// "H:MM AM/PM" (12h), tolerating surrounding whitespace. Returns null if it
  /// can't be parsed to a valid time in [0, 24h).
  static int? _toMinutes(String raw) {
    final s = raw.trim().toUpperCase();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{1,2})\s*(AM|PM)?$').firstMatch(s);
    if (m == null) return null;
    var h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null) return null;
    final period = m.group(3);
    if (period == 'PM' && h != 12) h += 12;
    if (period == 'AM' && h == 12) h = 0;
    // Reject out-of-range values (e.g. "24:00", "9:70") rather than mis-schedule.
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
  }

  /// True if this slot and [other] share a day and their time intervals
  /// overlap. Intervals are half-open [start, end): back-to-back classes
  /// (one ends 09:50, next starts 09:51) do NOT conflict.
  ///
  /// SAFETY: if either slot's time can't be parsed, we CANNOT prove they're
  /// safe, so on the SAME day we treat them as conflicting (fail safe) rather
  /// than silently scheduling one on top of the other and calling it
  /// "conflict-free". Different days never conflict regardless.
  bool conflictsWith(ScheduleSlot other) {
    if (day != other.day) return false;
    final aS = startMin, aE = endMin, bS = other.startMin, bE = other.endMin;
    if (aS == null || aE == null || bS == null || bE == null) {
      return true; // same day, unverifiable time → assume clash
    }
    return aS < bE && bS < aE;
  }
}

/// A section of a course: the atom the student actually selects.
class CatalogSection {
  final String? section;
  final String? facultyName;
  final String? facultyCode;
  final String? room;
  final double? credits;
  final int? capacity; // fixed section size, NOT remaining seats
  final List<ScheduleSlot> schedule;
  final String kind; // theory | lab | unscheduled | other

  const CatalogSection({
    this.section,
    this.facultyName,
    this.facultyCode,
    this.room,
    this.credits,
    this.capacity,
    this.schedule = const [],
    this.kind = 'other',
  });

  factory CatalogSection.fromJson(Map<String, dynamic> j) => CatalogSection(
        section: _strN(j['section']),
        facultyName: _strN(j['faculty_name']),
        facultyCode: _strN(j['faculty_code']),
        room: _strN(j['room']),
        credits: _numN(j['credits']),
        capacity: _intN(j['capacity']),
        schedule: ((j['schedule'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ScheduleSlot.fromJson(e.cast<String, dynamic>()))
            .toList(),
        kind: _strN(j['kind']) ?? 'other',
      );

  Map<String, dynamic> toJson() => {
        'section': section,
        'faculty_name': facultyName,
        'faculty_code': facultyCode,
        'room': room,
        'credits': credits,
        'capacity': capacity,
        'schedule': schedule.map((e) => e.toJson()).toList(),
        'kind': kind,
      };

  bool get isUnscheduled => schedule.isEmpty;

  /// The distinct days this section meets, in week order.
  List<String> get days {
    final set = schedule.map((s) => s.day).toSet().toList();
    set.sort((a, b) => weekdayRank(a).compareTo(weekdayRank(b)));
    return set;
  }

  /// True if any slot of this section conflicts with any slot of [other].
  bool conflictsWith(CatalogSection other) {
    for (final a in schedule) {
      for (final b in other.schedule) {
        if (a.conflictsWith(b)) return true;
      }
    }
    return false;
  }
}

/// A course and all its offered sections.
class CatalogCourse {
  final String formalCode;
  final String? name;
  final double? credits;
  final List<CatalogSection> sections;

  const CatalogCourse({
    required this.formalCode,
    this.name,
    this.credits,
    this.sections = const [],
  });

  factory CatalogCourse.fromJson(Map<String, dynamic> j) => CatalogCourse(
        formalCode: _strN(j['formal_code']) ?? '',
        name: _strN(j['name']),
        credits: _numN(j['credits']),
        sections: ((j['sections'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => CatalogSection.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'formal_code': formalCode,
        'name': name,
        'credits': credits,
        'sections': sections.map((e) => e.toJson()).toList(),
      };

  /// Distinct faculty (code -> display name) teaching this course, for filters.
  Map<String, String> get facultyByCode {
    final map = <String, String>{};
    for (final s in sections) {
      final code = s.facultyCode;
      if (code != null && !map.containsKey(code)) {
        map[code] = s.facultyName ?? code;
      }
    }
    return map;
  }
}

/// The whole catalog, plus provenance so the UI can show its capture date.
class SectionCatalogData {
  final String? trimester;
  final String? capturedAt; // when the source console data was captured
  final List<String> departments;
  final List<CatalogCourse> courses;

  const SectionCatalogData({
    this.trimester,
    this.capturedAt,
    this.departments = const [],
    this.courses = const [],
  });

  factory SectionCatalogData.fromJson(Map<String, dynamic> j) =>
      SectionCatalogData(
        trimester: _strN(j['trimester']),
        capturedAt: _strN(j['captured_at']),
        departments: ((j['departments'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        courses: ((j['courses'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => CatalogCourse.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'trimester': trimester,
        'captured_at': capturedAt,
        'departments': departments,
        'courses': courses.map((e) => e.toJson()).toList(),
      };

  /// The subject prefix of a course code, e.g. "CSE 1111" -> "CSE". This is how
  /// students actually group courses ("my CSE courses"), and is more meaningful
  /// than the internal numeric department id.
  static String subjectOf(String formalCode) {
    final m = RegExp(r'^([A-Za-z]+)').firstMatch(formalCode.trim());
    return m != null ? m.group(1)!.toUpperCase() : '#';
  }

  /// Courses grouped by subject prefix, each group sorted by code. Groups are
  /// returned in alphabetical subject order. Used to render the full catalog
  /// lazily, one subject at a time, instead of one giant list.
  List<MapEntry<String, List<CatalogCourse>>> get coursesBySubject {
    final map = <String, List<CatalogCourse>>{};
    for (final c in courses) {
      map.putIfAbsent(subjectOf(c.formalCode), () => []).add(c);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      e.value.sort((a, b) => a.formalCode.compareTo(b.formalCode));
    }
    return entries;
  }

  /// Case/space-insensitive lookup of a course by its formal code (e.g. the
  /// pre-advising list may format "CSE1111" vs the catalog's "CSE 1111").
  CatalogCourse? courseByCode(String code) {
    final want = normalize(code);
    for (final c in courses) {
      if (normalize(c.formalCode) == want) return c;
    }
    return null;
  }

  /// Canonical form of a course code for matching across sources (the
  /// pre-advising grid and the catalog may differ in spacing/case).
  static String normalize(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}
