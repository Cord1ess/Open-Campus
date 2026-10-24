import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../academics/advising_model.dart';
import '../academics/course_history_model.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/models.dart';
import '../sections/section_catalog_model.dart';

/// Normalises a course code for lookups ("cse 2217" == "CSE2217").
String normCourseCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Splits a combined label such as "CSE 2217: Data Structure (A)" or
/// "CSE 4165 Web Programming Laboratory" into (code, title).
(String code, String? title) splitCourseLabel(String label) {
  final m = RegExp(r'^\s*([A-Za-z]{2,5})\s*-?\s*(\d{3,4}[A-Za-z]?)\s*[:\-–]?\s*(.*)$')
      .firstMatch(label);
  if (m == null) return (label.trim(), null);
  final code = '${m.group(1)!.toUpperCase()} ${m.group(2)!}';
  final rest = m.group(3)!.trim();
  return (code, rest.isEmpty ? null : rest);
}

/// Every course title the app already knows, keyed by normalised code. Merged
/// from attendance, course history, pre-advising and the section catalogue —
/// whichever are loaded — so screens whose data only carries a code (the class
/// routine, bills) can still show the course name.
final courseTitlesProvider = Provider<Map<String, String>>((ref) {
  final map = <String, String>{};
  void put(String? code, String? title) {
    if (code == null || title == null) return;
    final t = title.trim();
    if (t.isEmpty) return;
    map.putIfAbsent(normCourseCode(code), () => t);
  }

  final att = ref.watch(attendanceProvider);
  if (att is ResData<AttendanceData>) {
    for (final c in att.loaded.data.courses) {
      put(c.courseCode, c.title);
    }
  }
  final hist = ref.watch(courseHistoryProvider);
  if (hist is ResData<CourseHistoryData>) {
    for (final c in hist.loaded.data.courses) {
      put(c.courseCode, c.courseName);
    }
  }
  final adv = ref.watch(advisingProvider);
  if (adv is ResData<AdvisingData>) {
    for (final c in [...adv.loaded.data.offered, ...adv.loaded.data.taken]) {
      put(c.code, c.title);
    }
  }
  final cat = ref.watch(sectionCatalogProvider);
  if (cat is ResData<SectionCatalogData>) {
    for (final c in cat.loaded.data.courses) {
      put(c.formalCode, c.name);
    }
  }
  return map;
});

/// Title for [code] if known.
String? lookupCourseTitle(WidgetRef ref, String code) {
  final (c, inline) = splitCourseLabel(code);
  return ref.watch(courseTitlesProvider)[normCourseCode(c)] ?? inline;
}

/// The course label used everywhere: the course TITLE as the main line and the
/// code (plus optional extra, e.g. section) underneath in smaller text. Falls
/// back to the code alone when no title is known.
class CourseName extends ConsumerWidget {
  final String code;
  final String? title;
  final String? extra;
  final TextStyle? titleStyle;
  final TextStyle? codeStyle;
  final int maxLines;
  final Color? color;
  const CourseName({
    super.key,
    required this.code,
    this.title,
    this.extra,
    this.titleStyle,
    this.codeStyle,
    this.maxLines = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (cleanCode, inline) = splitCourseLabel(code);
    final name = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : (ref.watch(courseTitlesProvider)[normCourseCode(cleanCode)] ?? inline);
    final ts = (titleStyle ?? context.text.titleSmall)
        ?.copyWith(color: color ?? titleStyle?.color);
    final cs = (codeStyle ?? context.text.bodySmall)?.copyWith(
        color: color?.withValues(alpha: 0.75) ?? codeStyle?.color);
    final sub = [cleanCode, if (extra != null && extra!.isNotEmpty) extra!]
        .join(' · ');
    if (name == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cleanCode,
              maxLines: maxLines, overflow: TextOverflow.ellipsis, style: ts),
          if (extra != null && extra!.isNotEmpty)
            Text(extra!, maxLines: 1, overflow: TextOverflow.ellipsis, style: cs),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: ts),
        const SizedBox(height: 1),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: cs),
      ],
    );
  }
}
