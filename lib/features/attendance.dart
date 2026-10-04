import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});
  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  String? group;
  late DateTime date;
  final Map<String, String> draft = {};
  String search = '';
  @override
  void initState() {
    super.initState();
    date = ref.read(schoolProvider).clock();
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider);
    final teacher = school.role.teaches;
    final groups = school.accessibleClasses;
    group = groups.contains(group) ? group : groups.firstOrNull;
    final rows = school.records('attendance', classId: teacher ? group : null);
    final today = rows.where((r) => r.text('date') == dayKey(date)).toList();
    final roster = school
        .records('student', classId: group)
        .where(
          (s) => s.text('name').toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    String status(String id) =>
        draft[id] ??
        today.where((r) => r.studentId == id).firstOrNull?.text('status') ??
        'Not marked';
    return PageBody(
      onRefresh: school.refresh,
      children: [
        const SectionHeading(
          'Every student, seen.',
          subtitle: 'Attendance is the first moment of connection.',
        ),
        ResponsiveGrid(
          minWidth: 140,
          children: [
            StatCard(
              label: 'Attendance rate',
              value: '${school.attendanceRate(rows).toStringAsFixed(1)}%',
              icon: Icons.pie_chart_outline_rounded,
            ),
            StatCard(
              label: teacher ? 'Present today' : 'Days present',
              value:
                  '${(teacher ? today : rows).where((r) => ['Present', 'Late'].contains(r.text('status'))).length}',
              icon: Icons.check_circle_outline_rounded,
            ),
            StatCard(
              label: teacher ? 'Absent today' : 'Days absent',
              value:
                  '${(teacher ? today : rows).where((r) => r.text('status') == 'Absent').length}',
              icon: Icons.person_off_outlined,
              color: clay,
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (teacher) ...[
          Surface(
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: group,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: groups
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text('Grade $g'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      group = v;
                      draft.clear();
                    }),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2026),
                      lastDate: school.clock(),
                    );
                    if (picked != null) {
                      setState(() {
                        date = picked;
                        draft.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 17),
                  label: Text(DateFormat('d MMM yyyy').format(date)),
                ),
                TextButton.icon(
                  onPressed: school.busy || group == null
                      ? null
                      : () => setState(() {
                          for (final s in school.records(
                            'student',
                            classId: group,
                          )) {
                            draft[s.id] = 'Present';
                          }
                        }),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all present'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Find a student',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SectionHeading(
            'Class register',
            subtitle:
                'Choose a status for each student, then save the register.',
          ),
          if (roster.isEmpty)
            const EmptyState(
              'No students here yet',
              'Add students to this class from the school hub.',
            )
          else
            Surface(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: roster
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                PersonAvatar(s.text('name'), size: 37),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.text('name'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Roll ${s.text('roll')} · ${s.classId}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Pill(
                                  status(s.id),
                                  color: statusColor(status(s.id)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: ['Present', 'Absent', 'Late', 'Excused']
                                  .map(
                                    (v) => ChoiceChip(
                                      label: Text(
                                        v,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      selected: status(s.id) == v,
                                      onSelected: school.busy
                                          ? null
                                          : (_) =>
                                                setState(() => draft[s.id] = v),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: school.busy || draft.isEmpty || group == null
                  ? null
                  : () async {
                      final changes = Map<String, String>.from(draft);
                      if (await runAction(
                        context,
                        () => school.saveAttendance(group!, date, changes),
                        'Attendance saved. Families can now view it.',
                      )) {
                        if (mounted) setState(draft.clear);
                      }
                    },
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Save register${draft.isEmpty ? '' : ' · ${draft.length} changes'}',
              ),
            ),
          ),
          const SectionHeading(
            'Staff check-in',
            subtitle: 'Your attendance, recorded with care.',
          ),
          Surface(
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    school
                                .records('staffAttendance')
                                .where(
                                  (r) =>
                                      r.ownerId == school.user!.id &&
                                      r.text('date') == dayKey(school.clock()),
                                )
                                .firstOrNull
                                ?.data['out'] !=
                            null
                        ? 'Checked out for today'
                        : 'Record your arrival or departure',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                FilledButton(
                  onPressed: school.busy
                      ? null
                      : () => runAction(
                          context,
                          school.staffCheckIn,
                          'Staff attendance updated.',
                        ),
                  child: const Text(
                    'Check in / out',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (school.role.managesSchool) ...[
            const SectionHeading('Staff attendance today'),
            ...school
                .records('staffAttendance')
                .where((r) => r.text('date') == dayKey(school.clock()))
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.text('name'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          DetailRow(
                            'Arrival',
                            DateFormat(
                              'HH:mm',
                            ).format(DateTime.parse(r.text('in'))),
                          ),
                          DetailRow(
                            'Departure',
                            r.data['out'] == null
                                ? 'On campus'
                                : DateFormat(
                                    'HH:mm',
                                  ).format(DateTime.parse(r.text('out'))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ] else ...[
          const SectionHeading(
            'Your attendance journal',
            subtitle:
                'Present and late days count toward attendance. Excused days are excluded.',
          ),
          if (rows.isEmpty)
            const EmptyState(
              'Your journal starts here',
              'Your teacher’s attendance records will appear here.',
            )
          else
            Surface(
              child: Column(
                children:
                    (rows..sort(
                          (a, b) => b.text('date').compareTo(a.text('date')),
                        ))
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Icon(
                                  r.text('status') == 'Absent'
                                      ? Icons.remove_circle_outline
                                      : Icons.check_circle_outline,
                                  color: statusColor(r.text('status')),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'EEEE, d MMM',
                                    ).format(DateTime.parse(r.text('date'))),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Pill(
                                  r.text('status'),
                                  color: statusColor(r.text('status')),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ],
    );
  }
}
