// UIU grading domain — the custom grade scale, GPA/CGPA math, and goal
// projection. Single source of truth so the calculator, projections, and charts
// all agree. See memory: uiu-grading-finance-rules.

import 'dart:math' as math;

/// One band of the UIU letter-grade scale.
class Grade {
  final String letter;
  final double point;
  final int minMark; // inclusive lower bound of the marks band
  final int maxMark;
  final String assessment;
  const Grade(
      this.letter, this.point, this.minMark, this.maxMark, this.assessment);
}

/// The full UIU scale, best-to-worst.
const uiuGrades = <Grade>[
  Grade('A', 4.00, 90, 100, 'Outstanding'),
  Grade('A-', 3.67, 86, 89, 'Excellent'),
  Grade('B+', 3.33, 82, 85, 'Very Good'),
  Grade('B', 3.00, 78, 81, 'Good'),
  Grade('B-', 2.67, 74, 77, 'Above Average'),
  Grade('C+', 2.33, 70, 73, 'Average'),
  Grade('C', 2.00, 66, 69, 'Below Average'),
  Grade('C-', 1.67, 62, 65, 'Poor'),
  Grade('D+', 1.33, 58, 61, 'Very poor'),
  Grade('D', 1.00, 55, 57, 'Pass'),
  Grade('F', 0.00, 0, 54, 'Fail'),
];

/// Highest and lowest attainable grade points (excluding F for "passing").
const double maxGradePoint = 4.0;
const double minPassGradePoint = 1.0; // D
const double degreeMinCgpa = 2.0;

/// A course the user is planning (credit + an optional target grade point).
class PlannedCourse {
  final String label;
  double credit;
  double? gradePoint; // null = unknown/blank
  PlannedCourse({required this.label, required this.credit, this.gradePoint});
}

/// Weighted GPA + the credit base it was computed over, in ONE pass. Courses
/// with a null grade point are ignored (they contribute to neither). `gpa` is
/// null when no graded credits are present. Callers should use `credits` from
/// here rather than re-summing separately, so the GPA and its credit base can't
/// diverge.
({double? gpa, double credits}) weightedGpaWithCredits(
    Iterable<({double credit, double? point})> courses) {
  var cr = 0.0, qp = 0.0;
  for (final c in courses) {
    if (c.point == null) continue;
    cr += c.credit;
    qp += c.credit * c.point!;
  }
  return (gpa: cr == 0 ? null : qp / cr, credits: cr);
}

/// Weighted GPA of a set of (credit, gradePoint) pairs. Returns null if no
/// credits. Courses with a null grade point are ignored. (Thin wrapper over
/// [weightedGpaWithCredits] for call sites that only need the GPA.)
double? weightedGpa(Iterable<({double credit, double? point})> courses) =>
    weightedGpaWithCredits(courses).gpa;

/// Snap a numeric grade point to the nearest valid UIU letter (for display of a
/// "needed grade").
Grade nearestGradeAtOrAbove(double point) {
  // Smallest grade whose point >= target; falls back to A if target > 4.
  Grade best = uiuGrades.first;
  for (final g in uiuGrades.reversed) {
    if (g.point >= point - 1e-9) return g;
    best = g;
  }
  return best;
}

/// Convert a marks percentage to its letter grade.
Grade gradeForMarks(num marks) {
  for (final g in uiuGrades) {
    if (marks >= g.minMark) return g;
  }
  return uiuGrades.last;
}

/// Result of a whole-degree goal projection.
class GoalProjection {
  final double goalCgpa;
  final double currentCgpa;
  final double completedCredits;
  final double remainingCredits;

  /// The average grade point needed across ALL remaining credits to hit the
  /// goal. May exceed 4.0 (then [reachable] is false).
  final double neededAvg;
  final bool reachable;

  /// If unreachable, the highest CGPA still attainable (all-A remaining).
  final double maxReachableCgpa;

  const GoalProjection({
    required this.goalCgpa,
    required this.currentCgpa,
    required this.completedCredits,
    required this.remainingCredits,
    required this.neededAvg,
    required this.reachable,
    required this.maxReachableCgpa,
  });
}

/// Required-GPA analysis for a SINGLE upcoming trimester (the reference app's
/// "next trimester" planner): given current standing and how many credits you'll
/// take next, what trimester GPA do you need to land at [targetCgpa]?
///   target = (current*completed + needed*next) / (completed + next)
/// → needed = (target*(completed+next) - current*completed) / next
class NextTrimesterPlan {
  final double requiredGpa;
  final bool achievable; // requiredGpa within (0, 4]
  final bool alreadyAchieved; // current standing already meets target
  /// Highest CGPA reachable next trimester (all-A) — used when unachievable.
  final double maxReachableCgpa;
  const NextTrimesterPlan({
    required this.requiredGpa,
    required this.achievable,
    required this.alreadyAchieved,
    required this.maxReachableCgpa,
  });
}

NextTrimesterPlan planNextTrimester({
  required double currentCgpa,
  required double completedCredits,
  required double nextCredits,
  required double targetCgpa,
}) {
  final total = completedCredits + nextCredits;
  final currentPoints = currentCgpa * completedCredits;
  final maxReachable =
      nextCredits <= 0 ? currentCgpa : (currentPoints + 4.0 * nextCredits) / total;
  if (nextCredits <= 0) {
    return NextTrimesterPlan(
      requiredGpa: 0,
      achievable: false,
      alreadyAchieved: currentCgpa >= targetCgpa - 1e-9,
      maxReachableCgpa: currentCgpa,
    );
  }
  final required = (targetCgpa * total - currentPoints) / nextCredits;
  return NextTrimesterPlan(
    requiredGpa: required,
    achievable: required > 1e-9 && required <= maxGradePoint + 1e-9,
    alreadyAchieved: required < 1e-9,
    maxReachableCgpa: math.min(maxGradePoint, maxReachable),
  );
}

/// A human "how hard is this" label for a required GPA (mirrors the reference
/// app's difficulty tiers).
String difficultyLabel(double requiredGpa) {
  if (requiredGpa > maxGradePoint) return 'Impossible';
  if (requiredGpa >= 3.67) return 'Very hard';
  if (requiredGpa >= 3.33) return 'Hard';
  if (requiredGpa >= 3.0) return 'Moderate';
  if (requiredGpa >= 2.0) return 'Manageable';
  return 'Comfortable';
}

/// New CGPA after a trimester of [trimesterGpa] over [trimesterCredits], on top
/// of the current standing. Used for projection tables.
double projectedCgpa({
  required double currentCgpa,
  required double completedCredits,
  required double trimesterGpa,
  required double trimesterCredits,
}) {
  final total = completedCredits + trimesterCredits;
  if (total <= 0) return currentCgpa;
  return (currentCgpa * completedCredits + trimesterGpa * trimesterCredits) /
      total;
}

/// Retake impact (UIU rule): the HIGHER of the two grades is what counts toward
/// CGPA. So a retake only helps if the new grade beats the old; if it's lower,
/// the previous (higher) grade still stands → zero/negative is clamped to "no
/// loss". [improvement] is the per-course quality-point gain that actually
/// counts.
class RetakeImpact {
  final double previousPoint;
  final double newPoint;
  final double credit;
  /// Quality points that count toward CGPA (UIU keeps the higher grade), so this
  /// is max(0, (new-prev)) * credit.
  final double countedImprovement;
  bool get improved => newPoint > previousPoint;
  const RetakeImpact({
    required this.previousPoint,
    required this.newPoint,
    required this.credit,
    required this.countedImprovement,
  });
}

RetakeImpact retakeImpact({
  required double previousPoint,
  required double newPoint,
  required double credit,
}) {
  // UIU counts the higher grade — a worse retake doesn't lower your CGPA.
  final delta = math.max(0.0, newPoint - previousPoint);
  return RetakeImpact(
    previousPoint: previousPoint,
    newPoint: newPoint,
    credit: credit,
    countedImprovement: delta * credit,
  );
}

/// Project what average grade point is needed across the remaining credits to
/// reach [goalCgpa], given current standing. CGPA is credit-weighted, so:
///   goal = (currentCgpa*completed + neededAvg*remaining) / (completed+remaining)
/// → neededAvg = (goal*(completed+remaining) - currentCgpa*completed) / remaining
GoalProjection projectGoal({
  required double goalCgpa,
  required double currentCgpa,
  required double completedCredits,
  required double remainingCredits,
}) {
  final total = completedCredits + remainingCredits;
  final maxReachable = remainingCredits <= 0
      ? currentCgpa
      : (currentCgpa * completedCredits + maxGradePoint * remainingCredits) /
          total;
  if (remainingCredits <= 0) {
    return GoalProjection(
      goalCgpa: goalCgpa,
      currentCgpa: currentCgpa,
      completedCredits: completedCredits,
      remainingCredits: 0,
      neededAvg: 0,
      reachable: currentCgpa >= goalCgpa - 1e-9,
      maxReachableCgpa: currentCgpa,
    );
  }
  final needed =
      (goalCgpa * total - currentCgpa * completedCredits) / remainingCredits;
  return GoalProjection(
    goalCgpa: goalCgpa,
    currentCgpa: currentCgpa,
    completedCredits: completedCredits,
    remainingCredits: remainingCredits,
    neededAvg: needed,
    reachable: needed <= maxGradePoint + 1e-9,
    maxReachableCgpa: math.min(maxGradePoint, maxReachable),
  );
}
