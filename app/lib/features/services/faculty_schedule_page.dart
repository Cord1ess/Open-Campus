import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// Faculty schedules — pick a faculty member to see their class times,
/// counselling (office) hours, and room. Data isn't pulled from UCAM yet; the
/// structure and UX are built so wiring real data later is a drop-in.
class FacultySchedulePage extends StatefulWidget {
  const FacultySchedulePage({super.key});

  @override
  State<FacultySchedulePage> createState() => _FacultySchedulePageState();
}

class _FacultySchedulePageState extends State<FacultySchedulePage> {
  // Placeholder demo data only — NOT real faculty. Live faculty schedules are
  // wired from the backend later; these examples exist purely so the picker and
  // detail UI have something to render in the beta.
  // TODO(data): replace with /faculty/schedules once available.
  static const _faculty = <_Faculty>[
    _Faculty(
      name: 'Dr. Sample Faculty One',
      initial: 'SF1',
      department: 'CSE',
      room: '000 (A)',
      email: 'faculty1@example.edu',
      classes: [
        _Slot('CSE 0000', 'Sat', '08:30 AM', '09:50 AM', '0000'),
        _Slot('CSE 0000', 'Tue', '08:30 AM', '09:50 AM', '0000'),
      ],
      counselling: [
        _Slot(null, 'Sun', '11:00 AM', '01:00 PM', '000 (A)'),
        _Slot(null, 'Wed', '02:00 PM', '04:00 PM', '000 (A)'),
      ],
    ),
    _Faculty(
      name: 'Dr. Sample Faculty Two',
      initial: 'SF2',
      department: 'EEE',
      room: '000 (B)',
      email: 'faculty2@example.edu',
      classes: [
        _Slot('EEE 0000', 'Sun', '09:51 AM', '11:10 AM', '0000'),
      ],
      counselling: [
        _Slot(null, 'Mon', '10:00 AM', '12:00 PM', '000 (B)'),
      ],
    ),
  ];

  _Faculty? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Faculty Schedules')),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.lg),
            sliver: SliverList.list(children: [
              const _ScaffoldNote(),
              const SizedBox(height: Spacing.lg),
              FadeSlideIn(child: _picker(context)),
              const SizedBox(height: Spacing.lg),
              if (_selected == null)
                const StateMessage(
                  icon: Icons.person_search_outlined,
                  title: 'Pick a faculty member',
                  subtitle: 'Choose a faculty above to see their schedule.',
                )
              else
                _FacultyDetail(_selected!),
              const SizedBox(height: 96),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _picker(BuildContext context) {
    final scheme = context.scheme;
    return DropdownButtonFormField<_Faculty>(
      initialValue: _selected,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.school_outlined),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        hintText: 'Search faculty',
      ),
      items: [
        for (final f in _faculty)
          DropdownMenuItem(
            value: f,
            child: Text('${f.name}  ·  ${f.department}'),
          ),
      ],
      onChanged: (f) => setState(() => _selected = f),
    );
  }
}

class _ScaffoldNote extends StatelessWidget {
  const _ScaffoldNote();
  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
                'Sample data — live faculty schedules will appear here '
                'once connected.',
                style: context.text.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _FacultyDetail extends StatelessWidget {
  final _Faculty f;
  const _FacultyDetail(this.f);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      children: [
        FadeSlideIn(
          child: SectionCard(
            title: f.name,
            icon: Icons.badge_outlined,
            child: Column(
              children: [
                _kv(context, 'Initial', f.initial),
                _kv(context, 'Department', f.department),
                _kv(context, 'Room', f.room),
                _kv(context, 'Email', f.email, color: scheme.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 60,
          child: SectionCard(
            title: 'Class times',
            icon: Icons.menu_book_outlined,
            child: Column(
              children: [
                for (var i = 0; i < f.classes.length; i++) ...[
                  if (i > 0)
                    Divider(height: Spacing.lg, color: scheme.outlineVariant),
                  _SlotRow(f.classes[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        FadeSlideIn(
          delayMs: 120,
          child: SectionCard(
            title: 'Counselling hours',
            icon: Icons.schedule_outlined,
            child: Column(
              children: [
                for (var i = 0; i < f.counselling.length; i++) ...[
                  if (i > 0)
                    Divider(height: Spacing.lg, color: scheme.outlineVariant),
                  _SlotRow(f.counselling[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
                width: 96,
                child: Text(k,
                    style: context.text.labelMedium
                        ?.copyWith(color: context.scheme.onSurfaceVariant))),
            Expanded(
                child: Text(v,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600, color: color))),
          ],
        ),
      );
}

class _SlotRow extends StatelessWidget {
  final _Slot s;
  const _SlotRow(this.s);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          alignment: Alignment.center,
          child: Text(s.day,
              style: context.text.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.course != null)
                Text(s.course!,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              Text('${s.start} – ${s.end}',
                  style: context.text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        Text('Room ${s.room}',
            style: context.text.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Faculty {
  final String name, initial, department, room, email;
  final List<_Slot> classes;
  final List<_Slot> counselling;
  const _Faculty({
    required this.name,
    required this.initial,
    required this.department,
    required this.room,
    required this.email,
    required this.classes,
    required this.counselling,
  });
}

class _Slot {
  final String? course;
  final String day, start, end, room;
  const _Slot(this.course, this.day, this.start, this.end, this.room);
}
