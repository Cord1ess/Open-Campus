// Course history model — mirrors GET /student/course-history.

double? _numN(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _strN(dynamic v) => v?.toString();

class HistoryCourse {
  final String? trimester;
  final String? courseCode;
  final String? courseName;
  final double? credit;
  final String? grade;
  final double? point;
  final bool isRunning;

  const HistoryCourse({
    this.trimester,
    this.courseCode,
    this.courseName,
    this.credit,
    this.grade,
    this.point,
    this.isRunning = false,
  });

  factory HistoryCourse.fromJson(Map<String, dynamic> j) => HistoryCourse(
        trimester: _strN(j['trimester']),
        courseCode: _strN(j['course_code']),
        courseName: _strN(j['course_name']),
        credit: _numN(j['credit']),
        grade: _strN(j['grade']),
        point: _numN(j['point']),
        isRunning: j['is_running'] == true,
      );

  Map<String, dynamic> toJson() => {
        'trimester': trimester,
        'course_code': courseCode,
        'course_name': courseName,
        'credit': credit,
        'grade': grade,
        'point': point,
        'is_running': isRunning,
      };
}

class TrimesterGpa {
  final String? trimester;
  final double? credit;
  final double? gpa;
  final double? cgpa;

  const TrimesterGpa({this.trimester, this.credit, this.gpa, this.cgpa});

  factory TrimesterGpa.fromJson(Map<String, dynamic> j) => TrimesterGpa(
        trimester: _strN(j['trimester']),
        credit: _numN(j['credit']),
        gpa: _numN(j['gpa']),
        cgpa: _numN(j['cgpa']),
      );

  Map<String, dynamic> toJson() => {
        'trimester': trimester,
        'credit': credit,
        'gpa': gpa,
        'cgpa': cgpa,
      };
}

class CourseHistoryData {
  final String? program;
  final String? batch;
  final double? cgpa;
  final double? degreeRequirement;
  final double? completedCredits;
  final double? attemptedCredits;
  final double? waivedCredits;
  final String? probation;
  final List<HistoryCourse> courses;
  final List<TrimesterGpa> trimesterGpas;

  const CourseHistoryData({
    this.program,
    this.batch,
    this.cgpa,
    this.degreeRequirement,
    this.completedCredits,
    this.attemptedCredits,
    this.waivedCredits,
    this.probation,
    this.courses = const [],
    this.trimesterGpas = const [],
  });

  /// Courses grouped by trimester, preserving first-seen order.
  Map<String, List<HistoryCourse>> get byTrimester {
    final map = <String, List<HistoryCourse>>{};
    for (final c in courses) {
      (map[c.trimester ?? '—'] ??= []).add(c);
    }
    return map;
  }

  double get progress => (degreeRequirement != null &&
          degreeRequirement! > 0 &&
          completedCredits != null)
      ? (completedCredits! / degreeRequirement!).clamp(0, 1)
      : 0;

  factory CourseHistoryData.fromJson(Map<String, dynamic> j) =>
      CourseHistoryData(
        program: _strN(j['program']),
        batch: _strN(j['batch']),
        cgpa: _numN(j['cgpa']),
        degreeRequirement: _numN(j['degree_requirement']),
        completedCredits: _numN(j['completed_credits']),
        attemptedCredits: _numN(j['attempted_credits']),
        waivedCredits: _numN(j['waived_credits']),
        probation: _strN(j['probation']),
        courses: ((j['courses'] as List?) ?? const [])
            .map((e) => HistoryCourse.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        trimesterGpas: ((j['trimester_gpas'] as List?) ?? const [])
            .map((e) => TrimesterGpa.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'program': program,
        'batch': batch,
        'cgpa': cgpa,
        'degree_requirement': degreeRequirement,
        'completed_credits': completedCredits,
        'attempted_credits': attemptedCredits,
        'waived_credits': waivedCredits,
        'probation': probation,
        'courses': courses.map((e) => e.toJson()).toList(),
        'trimester_gpas': trimesterGpas.map((e) => e.toJson()).toList(),
      };
}
