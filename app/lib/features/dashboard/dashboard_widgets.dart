import '../../core/domain/attendance_rules.dart';
import '../../core/theme/app_theme.dart';
import 'models.dart';

/// Attendance helpers shared by the dashboard, the Attendance page and the
/// Academics hub.

double? overallAttendancePct(AttendanceData a) {
  if (a.courses.isEmpty) return null;
  final held = a.courses.fold<int>(0, (s, c) => s + c.totalHeld);
  final present = a.courses.fold<int>(0, (s, c) => s + c.present);
  return held == 0 ? null : present / held * 100;
}

/// Total classes attended across all courses.
int attendedClasses(AttendanceData a) =>
    a.courses.fold<int>(0, (s, c) => s + c.present);

/// Total classes held across all courses.
int totalClasses(AttendanceData a) =>
    a.courses.fold<int>(0, (s, c) => s + c.totalHeld);

/// Semantic tone for a course's attendance: danger once marks are being
/// deducted, warning when one (or no) free absence remains or presence is
/// below 70%, otherwise success.
StatusTone attendanceTone(double pct, AttendanceBudget? budget) {
  if (budget != null && budget.isDeducting) return StatusTone.danger;
  if ((budget != null && budget.freeRemaining <= 1) || pct < 70) {
    return StatusTone.warning;
  }
  return StatusTone.success;
}
