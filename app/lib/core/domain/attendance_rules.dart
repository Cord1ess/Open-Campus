// UIU attendance mark-deduction rules.
//
// At UIU, attendance carries marks. A number of absences are "free"; beyond that
// threshold each further absence deducts a fixed amount from the attendance mark.
// Theory courses and labs have DIFFERENT free-absence thresholds.
//
// These constants are intentionally named so they're easy to find and tweak when
// the policy changes (e.g. a new trimester adjusts the free count or per-miss
// deduction).
library;

/// Free absences before deductions begin — THEORY courses.
const int kTheoryFreeAbsences = 3;

/// Free absences before deductions begin — LAB courses.
const int kLabFreeAbsences = 1;

/// Marks deducted per absence beyond the free threshold (same for theory & lab).
const double kDeductionPerExtraAbsence = 0.25;

/// How we decide a course is a lab from its attendance row. Labs at UIU usually
/// carry a "lab"/"sessional" marker in the title (course codes vary by program),
/// so we match on the title text. Adjust here if the signal changes.
bool isLabCourse({String? title, String? courseCode}) {
  final t = (title ?? '').toLowerCase();
  final c = (courseCode ?? '').toLowerCase();
  return t.contains('lab') ||
      t.contains('sessional') ||
      c.contains('lab');
}

/// The attendance "budget" for one course: how the free-absence threshold and
/// per-miss deduction apply given how many classes have been missed so far.
class AttendanceBudget {
  /// Absences allowed with NO mark loss (the threshold).
  final int freeAbsences;

  /// Absences taken so far.
  final int absences;

  /// Free absences still remaining (0 once the threshold is crossed).
  final int freeRemaining;

  /// Absences that exceeded the threshold (each one cost a deduction).
  final int penalizedAbsences;

  /// Marks lost so far = penalizedAbsences × per-miss deduction.
  final double marksLost;

  /// True once any deduction has started.
  bool get isDeducting => penalizedAbsences > 0;

  const AttendanceBudget({
    required this.freeAbsences,
    required this.absences,
    required this.freeRemaining,
    required this.penalizedAbsences,
    required this.marksLost,
  });
}

/// Compute the attendance budget for a course.
AttendanceBudget attendanceBudget({
  required int absences,
  required bool isLab,
}) {
  final free = isLab ? kLabFreeAbsences : kTheoryFreeAbsences;
  final penalized = absences > free ? absences - free : 0;
  return AttendanceBudget(
    freeAbsences: free,
    absences: absences,
    freeRemaining: (free - absences).clamp(0, free),
    penalizedAbsences: penalized,
    marksLost: penalized * kDeductionPerExtraAbsence,
  );
}
