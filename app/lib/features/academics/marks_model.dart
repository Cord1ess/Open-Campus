// Marks model — mirrors GET /student/marks?trimester=<v>.

double? _numN(dynamic v) => v is num
    ? v.toDouble()
    : (v is String ? double.tryParse(v.replaceAll(',', '')) : null);
int? _intN(dynamic v) => v is num
    ? v.toInt()
    : (v is String ? int.tryParse(v.replaceAll(',', '')) : null);
String? _strN(dynamic v) => v?.toString();

class MarkComponent {
  final String name;
  final double? obtained;
  final double? max;
  const MarkComponent({required this.name, this.obtained, this.max});

  double get ratio => (max != null && max! > 0 && obtained != null)
      ? (obtained! / max!).clamp(0, 1)
      : 0;

  factory MarkComponent.fromJson(Map<String, dynamic> j) => MarkComponent(
        name: _strN(j['name']) ?? '',
        obtained: _numN(j['obtained']),
        max: _numN(j['max']),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'obtained': obtained, 'max': max};
}

class CourseMarks {
  final String? course;
  final String? trimester;
  final int? totalClass;
  final int? present;
  final List<MarkComponent> components;
  final double? totalObtained;
  final double? totalMax;

  const CourseMarks({
    this.course,
    this.trimester,
    this.totalClass,
    this.present,
    this.components = const [],
    this.totalObtained,
    this.totalMax,
  });

  /// "CSE 2217: Data Structure (A)" -> code "CSE 2217", rest as title.
  String get code {
    final c = course ?? '';
    final m = RegExp(r'^([A-Z]{2,4}\s*\d{3,4})').firstMatch(c);
    return m?.group(1) ?? c;
  }

  String get title {
    final c = course ?? '';
    // Drop a leading "CODE: CODE:" duplication UCAM sometimes emits.
    var s = c.replaceFirst(RegExp(r'^([A-Z]{2,4}\s*\d{3,4}:\s*)+'), '');
    return s.isEmpty ? c : s;
  }

  double get attendancePct => (totalClass != null && totalClass! > 0)
      ? ((present ?? 0) / totalClass! * 100)
      : 0;

  factory CourseMarks.fromJson(Map<String, dynamic> j) => CourseMarks(
        course: _strN(j['course']),
        trimester: _strN(j['trimester']),
        totalClass: _intN(j['total_class']),
        present: _intN(j['present']),
        components: ((j['components'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => MarkComponent.fromJson(e.cast<String, dynamic>()))
            .toList(),
        totalObtained: _numN(j['total_obtained']),
        totalMax: _numN(j['total_max']),
      );

  Map<String, dynamic> toJson() => {
        'course': course,
        'trimester': trimester,
        'total_class': totalClass,
        'present': present,
        'components': components.map((e) => e.toJson()).toList(),
        'total_obtained': totalObtained,
        'total_max': totalMax,
      };
}

class MarksData {
  final List<CourseMarks> courses;
  const MarksData({this.courses = const []});

  factory MarksData.fromJson(Map<String, dynamic> j) => MarksData(
        courses: ((j['courses'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => CourseMarks.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'courses': courses.map((e) => e.toJson()).toList()};
}

class TrimesterOption {
  final String value;
  final String label;
  const TrimesterOption({required this.value, required this.label});

  factory TrimesterOption.fromJson(Map<String, dynamic> j) => TrimesterOption(
        value: _strN(j['value']) ?? '',
        label: _strN(j['label']) ?? '',
      );
}
