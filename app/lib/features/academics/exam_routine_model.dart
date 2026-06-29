// Exam routine model — mirrors GET /student/exam-routine.

String? _strN(dynamic v) => v?.toString();

class ExamRoutineLink {
  final String label;
  final String url;
  const ExamRoutineLink({required this.label, required this.url});

  factory ExamRoutineLink.fromJson(Map<String, dynamic> j) => ExamRoutineLink(
        label: _strN(j['label']) ?? 'Exam Routine',
        url: _strN(j['url']) ?? '',
      );
}

class ExamRoutineData {
  final List<ExamRoutineLink> routines;
  const ExamRoutineData({this.routines = const []});

  factory ExamRoutineData.fromJson(Map<String, dynamic> j) => ExamRoutineData(
        routines: ((j['routines'] as List?) ?? const [])
            .map((e) =>
                ExamRoutineLink.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
