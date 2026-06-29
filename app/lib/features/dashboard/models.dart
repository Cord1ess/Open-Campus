// Data models mirroring the backend's student JSON responses.
//
// Parsers are null-tolerant: real UCAM data has edge cases the sample HAR didn't
// (e.g. an in-progress semester with no GPA yet), so missing/null fields default
// rather than throw.

double _num(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? fallback : fallback);

int _int(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

String _str(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

class SemesterResult {
  final int year;
  final String semester;
  final double gpa;
  final double cgpa;

  const SemesterResult({
    required this.year,
    required this.semester,
    required this.gpa,
    required this.cgpa,
  });

  factory SemesterResult.fromJson(Map<String, dynamic> j) => SemesterResult(
        year: _int(j['year']),
        semester: _str(j['semester']),
        gpa: _num(j['gpa']),
        cgpa: _num(j['cgpa']),
      );

  Map<String, dynamic> toJson() =>
      {'year': year, 'semester': semester, 'gpa': gpa, 'cgpa': cgpa};
}

class ResultsData {
  final List<SemesterResult> semesters;
  final double? latestCgpa;
  const ResultsData({required this.semesters, this.latestCgpa});

  factory ResultsData.fromJson(Map<String, dynamic> j) => ResultsData(
        semesters: ((j['semesters'] as List?) ?? const [])
            .map((e) => SemesterResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        latestCgpa: (j['latest_cgpa'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'semesters': semesters.map((e) => e.toJson()).toList(),
        'latest_cgpa': latestCgpa,
      };
}

class CourseAttendance {
  final String courseCode;
  final String title;
  final String section;
  final int absent;
  final int present;
  final int totalHeld;

  const CourseAttendance({
    required this.courseCode,
    required this.title,
    required this.section,
    required this.absent,
    required this.present,
    required this.totalHeld,
  });

  double get pct => totalHeld == 0 ? 0 : (present / totalHeld) * 100;

  factory CourseAttendance.fromJson(Map<String, dynamic> j) => CourseAttendance(
        courseCode: _str(j['course_code']),
        title: _str(j['title']),
        section: _str(j['section']),
        absent: _int(j['absent']),
        present: _int(j['present']),
        totalHeld: _int(j['total_held']),
      );

  Map<String, dynamic> toJson() => {
        'course_code': courseCode,
        'title': title,
        'section': section,
        'absent': absent,
        'present': present,
        'total_held': totalHeld,
      };
}

class AttendanceData {
  final List<CourseAttendance> courses;
  const AttendanceData({required this.courses});

  factory AttendanceData.fromJson(Map<String, dynamic> j) => AttendanceData(
        courses: ((j['courses'] as List?) ?? const [])
            .map((e) => CourseAttendance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'courses': courses.map((e) => e.toJson()).toList()};
}
