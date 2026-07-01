// Advising model — mirrors GET /student/advising.

double? _numN(dynamic v) => v is num
    ? v.toDouble()
    : (v is String ? double.tryParse(v.replaceAll(',', '')) : null);
String? _strN(dynamic v) => v?.toString();

class OfferedCourse {
  final String? code;
  final String? title;
  final double? credit;
  final String? group;
  final String? offeredTrimester;
  final bool mandatory;

  const OfferedCourse({
    this.code,
    this.title,
    this.credit,
    this.group,
    this.offeredTrimester,
    this.mandatory = false,
  });

  factory OfferedCourse.fromJson(Map<String, dynamic> j) => OfferedCourse(
        code: _strN(j['code']),
        title: _strN(j['title']),
        credit: _numN(j['credit']),
        group: _strN(j['group']),
        offeredTrimester: _strN(j['offered_trimester']),
        mandatory: j['mandatory'] == true,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'credit': credit,
        'group': group,
        'offered_trimester': offeredTrimester,
        'mandatory': mandatory,
      };
}

class AdvisingData {
  final List<OfferedCourse> offered;
  final List<OfferedCourse> taken;
  const AdvisingData({this.offered = const [], this.taken = const []});

  factory AdvisingData.fromJson(Map<String, dynamic> j) => AdvisingData(
        offered: ((j['offered'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => OfferedCourse.fromJson(e.cast<String, dynamic>()))
            .toList(),
        taken: ((j['taken'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => OfferedCourse.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'offered': offered.map((e) => e.toJson()).toList(),
        'taken': taken.map((e) => e.toJson()).toList(),
      };
}
