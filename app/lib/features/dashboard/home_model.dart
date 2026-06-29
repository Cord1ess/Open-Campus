// Home summary model — mirrors the backend GET /student/home response
// (parsed from StudentHome.aspx). Null-tolerant, like the other models.

double? _numN(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

String? _strN(dynamic v) => v?.toString();

class Term {
  final String? code;
  final String? name;
  const Term({this.code, this.name});

  factory Term.fromJson(Map<String, dynamic> j) =>
      Term(code: _strN(j['code']), name: _strN(j['name']));

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

class Advisor {
  final String? name, initial, room, email, phone;
  const Advisor({this.name, this.initial, this.room, this.email, this.phone});

  factory Advisor.fromJson(Map<String, dynamic> j) => Advisor(
        name: _strN(j['name']),
        initial: _strN(j['initial']),
        room: _strN(j['room']),
        email: _strN(j['email']),
        phone: _strN(j['phone']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'initial': initial,
        'room': room,
        'email': email,
        'phone': phone,
      };
}

class ClassSession {
  final String day;
  final String courseCode;
  final String? section, start, end;
  const ClassSession({
    required this.day,
    required this.courseCode,
    this.section,
    this.start,
    this.end,
  });

  factory ClassSession.fromJson(Map<String, dynamic> j) => ClassSession(
        day: _strN(j['day']) ?? '',
        courseCode: _strN(j['course_code']) ?? '',
        section: _strN(j['section']),
        start: _strN(j['start']),
        end: _strN(j['end']),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'course_code': courseCode,
        'section': section,
        'start': start,
        'end': end,
      };
}

class HomeSummary {
  final String? name;
  final String? roll;
  final String? photoUrl;
  final String? dob;
  final String? bloodGroup;
  final String? phone;
  final String? fatherName;
  final String? motherName;
  final Term? currentTerm;
  final List<Term> nextTerms;
  final double? cgpa;
  final double? completedCredits;
  final double? currentBalance; // negative => advance (no due)
  final double? totalBilled;
  final double? totalPaid;
  final double? totalWaived;
  final Advisor? advisor;
  final List<ClassSession> routine;

  const HomeSummary({
    this.name,
    this.roll,
    this.photoUrl,
    this.dob,
    this.bloodGroup,
    this.phone,
    this.fatherName,
    this.motherName,
    this.currentTerm,
    this.nextTerms = const [],
    this.cgpa,
    this.completedCredits,
    this.currentBalance,
    this.totalBilled,
    this.totalPaid,
    this.totalWaived,
    this.advisor,
    this.routine = const [],
  });

  /// Amount still owed: a positive balance is a due; negative means advance.
  double get dueAmount =>
      (currentBalance != null && currentBalance! > 0) ? currentBalance! : 0;

  bool get hasDue => dueAmount > 0;

  factory HomeSummary.fromJson(Map<String, dynamic> j) => HomeSummary(
        name: _strN(j['name']),
        roll: _strN(j['roll']),
        photoUrl: _strN(j['photo_url']),
        dob: _strN(j['dob']),
        bloodGroup: _strN(j['blood_group']),
        phone: _strN(j['phone']),
        fatherName: _strN(j['father_name']),
        motherName: _strN(j['mother_name']),
        currentTerm: j['current_term'] is Map
            ? Term.fromJson((j['current_term'] as Map).cast<String, dynamic>())
            : null,
        nextTerms: ((j['next_terms'] as List?) ?? const [])
            .map((e) => Term.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        cgpa: _numN(j['cgpa']),
        completedCredits: _numN(j['completed_credits']),
        currentBalance: _numN(j['current_balance']),
        totalBilled: _numN(j['total_billed']),
        totalPaid: _numN(j['total_paid']),
        totalWaived: _numN(j['total_waived']),
        advisor: j['advisor'] is Map
            ? Advisor.fromJson((j['advisor'] as Map).cast<String, dynamic>())
            : null,
        routine: ((j['routine'] as List?) ?? const [])
            .map((e) => ClassSession.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'roll': roll,
        'photo_url': photoUrl,
        'dob': dob,
        'blood_group': bloodGroup,
        'phone': phone,
        'father_name': fatherName,
        'mother_name': motherName,
        'current_term': currentTerm?.toJson(),
        'next_terms': nextTerms.map((e) => e.toJson()).toList(),
        'cgpa': cgpa,
        'completed_credits': completedCredits,
        'current_balance': currentBalance,
        'total_billed': totalBilled,
        'total_paid': totalPaid,
        'total_waived': totalWaived,
        'advisor': advisor?.toJson(),
        'routine': routine.map((e) => e.toJson()).toList(),
      };
}
