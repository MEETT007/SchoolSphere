import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../core/reports.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

const modules = <String, (String, String, IconData)>{
  'timetable': (
    'Timetable',
    'A rhythm for your school day',
    Icons.calendar_view_day_outlined,
  ),
  'fees': (
    'Fees & receipts',
    'Clear records, fewer worries',
    Icons.receipt_long_outlined,
  ),
  'leave': (
    'Leave & approvals',
    'A little flexibility, thoughtfully managed',
    Icons.event_available_outlined,
  ),
  'library': (
    'Library',
    'Find your next adventure',
    Icons.local_library_outlined,
  ),
  'transport': (
    'Transport',
    'A smoother journey to school',
    Icons.directions_bus_outlined,
  ),
  'students': (
    'Student directory',
    'Know every learner',
    Icons.school_outlined,
  ),
  'staff': (
    'Our people',
    'The people who make it possible',
    Icons.badge_outlined,
  ),
  'classes': (
    'Classes & sections',
    'Make space for learning',
    Icons.meeting_room_outlined,
  ),
  'admissions': (
    'Admissions',
    'Welcome new possibilities',
    Icons.person_add_alt_1_outlined,
  ),
  'reports': ('Reports', 'See the bigger picture', Icons.insights_outlined),
  'settings': ('School & account', 'Your school, your way', Icons.tune_rounded),
};

bool moduleAllowed(String module, SchoolRole role) {
  if (['admissions', 'classes'].contains(module)) return role.managesSchool;
  if (module == 'students') return role.teaches;
  if (module == 'fees') return role != SchoolRole.teacher;
  if (module == 'leave') return role != SchoolRole.student;
  return true;
}

class HubPage extends ConsumerWidget {
  const HubPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolProvider);
    return PageBody(
      children: [
        const SectionHeading(
          'Your whole school, connected.',
          subtitle: 'The everyday essentials, all in one place.',
        ),
        ResponsiveGrid(
          minWidth: 155,
          children: modules.entries
              .where((m) => moduleAllowed(m.key, school.role))
              .map(
                (m) => Surface(
                  onTap: () => context.go('/module/${m.key}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mint,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(m.value.$3, color: teal, size: 26),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        m.value.$1,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        m.value.$2,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: teal,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class ManagementPage extends ConsumerStatefulWidget {
  const ManagementPage({super.key, required this.module});
  final String module;
  @override
  ConsumerState<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends ConsumerState<ManagementPage> {
  String search = '', group = '';
  int weekday = DateTime.now().weekday;
  @override
  void didUpdateWidget(covariant ManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      search = '';
      group = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider), info = modules[widget.module];
    if (info == null || !moduleAllowed(widget.module, school.role)) {
      return const PageBody(
        children: [
          EmptyState(
            'This space is for school leadership',
            'Use the school hub to explore your available modules.',
          ),
        ],
      );
    }
    final children = switch (widget.module) {
      'timetable' => _timetable(context, school),
      'fees' => _fees(context, school),
      'leave' => _leave(context, school),
      'library' => _library(context, school),
      'transport' => _transport(context, school),
      'students' => _students(context, school),
      'staff' => _staff(context, school),
      'classes' => _classes(context, school),
      'admissions' => _admissions(context, school),
      'reports' => _reports(context, school),
      _ => _settings(context, school),
    };
    return PageBody(
      onRefresh: school.refresh,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/hub'),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('School hub'),
        ),
        SectionHeading(info.$1, subtitle: info.$2),
        ...children,
      ],
    );
  }

  Widget _add(String label, VoidCallback action, SchoolController school) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: FilledButton.icon(
          onPressed: school.busy ? null : action,
          icon: const Icon(Icons.add, size: 18),
          label: Text(label),
        ),
      );
  List<Widget> _timetable(BuildContext context, SchoolController school) {
    final groups = school.role.teaches
        ? school.accessibleClasses
        : [if (school.studentClass != null) school.studentClass!];
    group = groups.contains(group) ? group : groups.firstOrNull ?? '';
    final periods =
        school
            .records('schedule', classId: group)
            .where((p) => p.list('days').contains(weekday))
            .toList()
          ..sort((a, b) => a.number('order').compareTo(b.number('order')));
    return [
      if (groups.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey(group),
            initialValue: group,
            decoration: const InputDecoration(labelText: 'Class'),
            items: groups
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => group = v!),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexed
            .map(
              (d) => ChoiceChip(
                label: Text(d.$2),
                selected: weekday == d.$1 + 1,
                onSelected: (_) => setState(() => weekday = d.$1 + 1),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      if (school.role.managesSchool && groups.isNotEmpty)
        _add('Add a period', () => _createPeriod(context, school), school),
      if (periods.isEmpty)
        const EmptyState(
          'Room to breathe',
          'No classes scheduled for this day.',
        )
      else
        ...periods.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 65,
                    decoration: BoxDecoration(
                      color: teal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.text('time'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: teal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          p.text('subject'),
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${p.text('teacher')} · Room ${p.text('room')}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.auto_stories_outlined, color: teal),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  Future<void> _createPeriod(
    BuildContext context,
    SchoolController school,
  ) async {
    final v = await schoolForm(context, 'Plan a learning period', [
      FormFieldSpec(
        'class',
        'Class',
        options: school.accessibleClasses,
        value: group,
      ),
      const FormFieldSpec('subject', 'Subject'),
      const FormFieldSpec('teacher', 'Teacher'),
      const FormFieldSpec('room', 'Room'),
      const FormFieldSpec('time', 'Time (08:15–09:00)', value: '08:15–09:00'),
      const FormFieldSpec(
        'order',
        'Position in day (1–12)',
        number: true,
        value: '1',
      ),
      const FormFieldSpec(
        'day',
        'Day',
        options: [
          'Every weekday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ],
      ),
    ]);
    if (v != null && context.mounted) {
      await runAction(context, () async {
        if (!RegExp(r'^\d{2}:\d{2}[–-]\d{2}:\d{2}$').hasMatch(v['time']!)) {
          throw StateError('Use a time range such as 08:15–09:00.');
        }
        final time = v['time']!.split(RegExp('[–-]'));
        final start = time[0].split(':').map(int.parse).toList(),
            end = time[1].split(':').map(int.parse).toList();
        if (start[0] > 23 ||
            end[0] > 23 ||
            start[1] > 59 ||
            end[1] > 59 ||
            start[0] * 60 + start[1] >= end[0] * 60 + end[1]) {
          throw StateError('Enter a valid period start and end.');
        }
        final days = v['day'] == 'Every weekday'
            ? [1, 2, 3, 4, 5]
            : [
                [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ].indexOf(v['day']!) +
                    1,
              ];
        final order = int.tryParse(v['order']!);
        if (order == null || order < 1 || order > 12) {
          throw StateError('Choose a whole-number position from 1 to 12.');
        }
        final conflicts = school
            .records('schedule', classId: v['class'])
            .where(
              (p) =>
                  p.list('days').any(days.contains) &&
                  p.number('order') == order - 1,
            );
        if (conflicts.isNotEmpty) {
          throw StateError('That class already has a period in this position.');
        }
        await school.addRecord('schedule', {
          'subject': v['subject'],
          'teacher': v['teacher'],
          'room': v['room'],
          'time': v['time'],
          'order': order - 1,
          'days': days,
        }, group: v['class']);
      }, 'Period added.');
    }
  }

  List<Widget> _fees(BuildContext context, SchoolController school) {
    final fees = school.records('fee');
    final total = fees.fold<num>(
      0,
      (s, f) => s + f.number('amount') - f.number('paid'),
    );
    return [
      StatCard(
        label: 'Outstanding balance',
        value: money(total),
        icon: Icons.account_balance_wallet_outlined,
        note: 'Recorded school fees',
      ),
      const SizedBox(height: 20),
      if (school.role.managesSchool)
        _add('Create a fee record', () => _createFee(context, school), school),
      if (fees.isEmpty)
        const EmptyState(
          'Everything accounted for',
          'Fee records will appear here.',
        )
      else
        ...fees.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.text('title'),
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 24,
                          ),
                        ),
                      ),
                      Pill(
                        f.text('status'),
                        color: statusColor(f.text('status')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (school.role.managesSchool)
                    DetailRow(
                      'Student',
                      school.byId(f.studentId ?? '')?.text('name') ?? '',
                    ),
                  DetailRow('Amount', money(f.number('amount'))),
                  DetailRow('Paid', money(f.number('paid'))),
                  DetailRow('Due', niceDate(f.text('due'))),
                  if (school.role.managesSchool &&
                      f.number('paid') < f.number('amount')) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: school.busy
                          ? null
                          : () async {
                              final v = await schoolForm(
                                context,
                                'Record an offline payment',
                                [
                                  FormFieldSpec(
                                    'amount',
                                    'Amount received',
                                    number: true,
                                    value:
                                        '${f.number('amount') - f.number('paid')}',
                                  ),
                                ],
                                button: 'Record payment',
                              );
                              if (v != null && context.mounted) {
                                await runAction(
                                  context,
                                  () => school.recordPayment(
                                    f,
                                    num.parse(v['amount']!),
                                  ),
                                  'Payment recorded.',
                                );
                              }
                            },
                      child: const Text('Record payment'),
                    ),
                  ],
                  if (f.text('receipt').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => runAction(
                        context,
                        () => exportSchoolReport(
                          school,
                          receipt: true,
                          receiptData: {
                            'Receipt': f.text('receipt'),
                            'Fee': f.text('title'),
                            'Total received': money(f.number('paid')),
                            'Outstanding': money(
                              f.number('amount') - f.number('paid'),
                            ),
                            'Date': niceDate(f.text('paidOn')),
                          },
                        ),
                      ),
                      icon: const Icon(Icons.download_outlined, size: 17),
                      label: const Text('Download receipt'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'Fee tracking includes recorded payments and receipts. Online payment processing is not connected.',
          style: TextStyle(fontSize: 11, height: 1.7),
        ),
      ),
    ];
  }

  Future<void> _createFee(BuildContext context, SchoolController school) async {
    final students = school.records('student');
    if (students.isEmpty) return;
    final labels = {
      for (final s in students) '${s.text('name')} · ${s.classId}': s,
    };
    final v = await schoolForm(context, 'Create a fee record', [
      FormFieldSpec('student', 'Student', options: labels.keys.toList()),
      const FormFieldSpec('title', 'Fee title'),
      const FormFieldSpec('amount', 'Amount', number: true),
      FormFieldSpec(
        'due',
        'Due date',
        date: true,
        value: dayKey(school.clock().add(const Duration(days: 15))),
      ),
    ]);
    if (v != null && context.mounted) {
      await runAction(context, () async {
        final amount = num.parse(v['amount']!);
        if (amount <= 0) throw StateError('Enter a positive fee amount.');
        final s = labels[v['student']]!;
        await school.addRecord(
          'fee',
          {
            'title': v['title'],
            'amount': amount,
            'paid': 0,
            'due': v['due'],
            'status': 'Due',
          },
          group: s.classId,
          pupil: s.id,
        );
      }, 'Fee record created.');
    }
  }

  List<Widget> _leave(BuildContext context, SchoolController school) {
    final leaves = school.records('leave');
    return [
      _add('Request leave', () async {
        final v = await schoolForm(context, 'A little time away', [
          const FormFieldSpec('reason', 'Reason', lines: 3),
          FormFieldSpec(
            'from',
            'From',
            date: true,
            value: dayKey(school.clock().add(const Duration(days: 1))),
          ),
          FormFieldSpec(
            'to',
            'To',
            date: true,
            value: dayKey(school.clock().add(const Duration(days: 1))),
          ),
        ], button: 'Send request');
        if (v != null && context.mounted) {
          await runAction(
            context,
            () => school.requestLeave(
              v['reason']!,
              DateTime.parse(v['from']!),
              DateTime.parse(v['to']!),
            ),
            'Leave request sent.',
          );
        }
      }, school),
      if (leaves.isEmpty)
        const EmptyState(
          'No leave requests',
          'Your requests and decisions will appear here.',
        )
      else
        ...leaves.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.text('name'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Pill(
                        l.text('status'),
                        color: statusColor(l.text('status')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.text('reason'),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  DetailRow(
                    l.text('type'),
                    '${niceDate(l.text('from'))} – ${niceDate(l.text('to'))}',
                  ),
                  if (school.role.managesSchool &&
                      l.text('status') == 'Pending' &&
                      l.ownerId != school.user!.id) ...[
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          onPressed: school.busy
                              ? null
                              : () => runAction(
                                  context,
                                  () => school.decideLeave(l, true),
                                  'Leave approved.',
                                ),
                          child: const Text('Approve'),
                        ),
                        OutlinedButton(
                          onPressed: school.busy
                              ? null
                              : () => runAction(
                                  context,
                                  () => school.decideLeave(l, false),
                                  'Request declined.',
                                ),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                  if (l.text('reviewer').isNotEmpty)
                    DetailRow('Reviewed by', l.text('reviewer')),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _library(BuildContext context, SchoolController school) {
    final books = school
        .records('book')
        .where(
          (b) => '${b.text('title')} ${b.text('author')}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    final loans = school
        .records('borrow')
        .where((r) => r.text('status') == 'Borrowed')
        .toList();
    return [
      TextField(
        decoration: const InputDecoration(
          hintText: 'Find your next read',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => search = v),
      ),
      const SizedBox(height: 18),
      if (school.role.managesSchool)
        _add('Add a book', () async {
          final v = await schoolForm(context, 'A new story for the shelf', [
            const FormFieldSpec('title', 'Book title'),
            const FormFieldSpec('author', 'Author'),
            const FormFieldSpec('category', 'Category'),
            const FormFieldSpec('copies', 'Copies', number: true, value: '1'),
          ]);
          if (v != null && context.mounted) {
            await runAction(context, () async {
              final count = int.tryParse(v['copies']!);
              if (count == null || count < 1) {
                throw StateError('Enter a positive whole-number copy count.');
              }
              await school.addRecord('book', {
                'title': v['title'],
                'author': v['author'],
                'category': v['category'],
                'copies': count,
              });
            }, 'Book added.');
          }
        }, school),
      ResponsiveGrid(
        children: books
            .map(
              (b) => Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: teal, size: 33),
                    const SizedBox(height: 18),
                    Pill(b.text('category'), color: clay),
                    const SizedBox(height: 12),
                    Text(
                      b.text('title'),
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 23,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      b.text('author'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    DetailRow('Copies in catalog', '${b.number('copies')}'),
                    if (school.role == SchoolRole.student)
                      FilledButton(
                        onPressed: school.busy
                            ? null
                            : () => runAction(
                                context,
                                () => school.borrowBook(b),
                                'Book checked out. Return it within 14 days.',
                              ),
                        child: const Text('Borrow book'),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      if (loans.isNotEmpty) ...[
        const SectionHeading('Books on loan'),
        ...loans.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.text('title'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  DetailRow('Return by', niceDate(l.text('due'))),
                  if (school.role.managesSchool)
                    DetailRow(
                      'Student',
                      school.byId(l.studentId ?? '')?.text('name') ?? '',
                    ),
                  if (school.role.managesSchool ||
                      school.role == SchoolRole.student)
                    TextButton(
                      onPressed: school.busy
                          ? null
                          : () => runAction(
                              context,
                              () => school.returnBook(l),
                              'Book returned.',
                            ),
                      child: const Text('Return book'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      if (books.isEmpty)
        const EmptyState(
          'No matching books',
          'Try a different title or author.',
        ),
    ];
  }

  List<Widget> _transport(BuildContext context, SchoolController school) {
    final routes = school.records('transport');
    return [
      if (school.role.managesSchool)
        _add('Add a school route', () async {
          final v = await schoolForm(context, 'Plan a safe journey', [
            const FormFieldSpec('title', 'Route name'),
            FormFieldSpec('class', 'Class', options: school.accessibleClasses),
            const FormFieldSpec('driver', 'Driver'),
            const FormFieldSpec('bus', 'Vehicle number'),
            const FormFieldSpec('stops', 'Stops and pickup times', lines: 3),
            const FormFieldSpec('return', 'Return time'),
            const FormFieldSpec('contact', 'Transport contact'),
          ]);
          if (v != null && context.mounted) {
            await runAction(
              context,
              () => school.addRecord('transport', {
                'title': v['title'],
                'driver': v['driver'],
                'bus': v['bus'],
                'stops': v['stops'],
                'return': v['return'],
                'contact': v['contact'],
              }, group: v['class']),
              'Route added.',
            );
          }
        }, school),
      if (routes.isEmpty)
        const EmptyState(
          'No route assigned',
          'Your school transport details will appear here.',
        )
      else
        ...routes.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: teal,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    r.text('title'),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DetailRow('Driver', r.text('driver')),
                  DetailRow('Bus', r.text('bus')),
                  const Divider(),
                  Text(
                    r.text('stops'),
                    style: const TextStyle(fontSize: 13, height: 1.9),
                  ),
                  DetailRow('Return', r.text('return')),
                  const SizedBox(height: 12),
                  Text(r.text('contact'), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      const Text(
        'Scheduled routes and pickup times. Live vehicle tracking is not connected.',
        style: TextStyle(fontSize: 11),
      ),
    ];
  }

  List<Widget> _students(BuildContext context, SchoolController school) {
    final students = school
        .records('student')
        .where(
          (s) => '${s.text('name')} ${s.classId}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return [
      TextField(
        decoration: const InputDecoration(
          hintText: 'Find a student or class',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => search = v),
      ),
      const SizedBox(height: 18),
      if (school.role.managesSchool)
        _add('Add student', () => _addStudent(context, school), school),
      if (students.isEmpty)
        const EmptyState(
          'No matching learners',
          'Add a student or adjust your search.',
        )
      else
        ...students.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Surface(
              padding: const EdgeInsets.all(16),
              onTap: () => _studentDetails(context, school, s),
              child: Row(
                children: [
                  PersonAvatar(s.text('name')),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.text('name'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Roll ${s.text('roll')} · Grade ${s.classId}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: teal),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  Future<void> _addStudent(
    BuildContext context,
    SchoolController school,
  ) async {
    if (school.accessibleClasses.isEmpty) return;
    final v = await schoolForm(context, 'Welcome a new learner', [
      const FormFieldSpec('name', 'Student name'),
      FormFieldSpec('class', 'Class', options: school.accessibleClasses),
      const FormFieldSpec('roll', 'Roll number'),
      const FormFieldSpec('parent', 'Guardian name'),
      const FormFieldSpec('email', 'Guardian email', optional: true),
    ]);
    if (v != null && context.mounted) {
      await runAction(context, () async {
        if (school
            .records('student', classId: v['class'])
            .any((s) => s.text('roll') == v['roll'])) {
          throw StateError(
            'That roll number already belongs to a student in this class.',
          );
        }
        await school.addRecord('student', {
          'name': v['name'],
          'roll': v['roll'],
          'parent': v['parent'],
          'email': v['email'],
          'joined': dayKey(school.clock()),
        }, group: v['class']);
      }, 'Student added to the roster.');
    }
  }

  Future<void> _studentDetails(
    BuildContext context,
    SchoolController school,
    SchoolRecord s,
  ) async {
    final marks = school
        .records('mark')
        .where((r) => r.studentId == s.id)
        .toList();
    final attendance = school
        .records('attendance')
        .where((r) => r.studentId == s.id)
        .toList();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.text('name')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailRow('Class', s.classId ?? ''),
                DetailRow('Roll', s.text('roll')),
                DetailRow('Guardian', s.text('parent')),
                DetailRow(
                  'Attendance',
                  '${school.attendanceRate(attendance).toStringAsFixed(1)}%',
                ),
                const Divider(),
                ...marks.map(
                  (m) => DetailRow(
                    m.text('subject'),
                    '${m.number('score')} / ${m.number('max')}',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  List<Widget> _staff(BuildContext context, SchoolController school) {
    final staff = school.records('staff');
    return [
      if (school.role.managesSchool)
        _add('Add staff member', () async {
          final v = await schoolForm(context, 'Welcome a new colleague', [
            const FormFieldSpec('name', 'Full name'),
            const FormFieldSpec('subject', 'Subject or department'),
            const FormFieldSpec('designation', 'Designation'),
            const FormFieldSpec(
              'classes',
              'Assigned classes (comma separated)',
              optional: true,
            ),
          ]);
          if (v != null && context.mounted) {
            await runAction(context, () async {
              final classes = v['classes']!
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (classes.any((c) => !school.accessibleClasses.contains(c))) {
                throw StateError('Use existing class names, such as 10-A.');
              }
              await school.addRecord('staff', {
                'name': v['name'],
                'subject': v['subject'],
                'designation': v['designation'],
                'classes': classes,
              });
            }, 'Staff member added to the directory.');
          }
        }, school),
      ResponsiveGrid(
        children: staff
            .map(
              (s) => Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PersonAvatar(s.text('name'), size: 52),
                    const SizedBox(height: 18),
                    Text(
                      s.text('name'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.text('designation'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Pill(s.text('subject')),
                    const SizedBox(height: 12),
                    Text(
                      s.list('classes').isEmpty
                          ? 'School leadership'
                          : s.list('classes').join(' · '),
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (school.role.managesSchool)
                      TextButton(
                        onPressed: school.busy
                            ? null
                            : () async {
                                final v = await schoolForm(
                                  context,
                                  'Update staff assignment',
                                  [
                                    FormFieldSpec(
                                      'designation',
                                      'Designation',
                                      value: s.text('designation'),
                                    ),
                                    FormFieldSpec(
                                      'subject',
                                      'Subject or department',
                                      value: s.text('subject'),
                                    ),
                                    FormFieldSpec(
                                      'classes',
                                      'Classes (comma separated)',
                                      value: s.list('classes').join(', '),
                                      optional: true,
                                    ),
                                  ],
                                );
                                if (v != null && context.mounted) {
                                  await runAction(context, () async {
                                    final classes = v['classes']!
                                        .split(',')
                                        .map((s) => s.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList();
                                    if (classes.any(
                                      (c) =>
                                          !school.accessibleClasses.contains(c),
                                    )) {
                                      throw StateError(
                                        'Use existing class names.',
                                      );
                                    }
                                    await school.updateAdministrative(s, {
                                      'designation': v['designation'],
                                      'subject': v['subject'],
                                      'classes': classes,
                                    });
                                  }, 'Assignment updated.');
                                }
                              },
                        child: const Text('Manage assignment'),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    ];
  }

  List<Widget> _classes(BuildContext context, SchoolController school) {
    final classes = school.records('class');
    return [
      _add('Add class or section', () async {
        final v = await schoolForm(context, 'Make space for learning', [
          const FormFieldSpec('id', 'Class code (for example 7-A)'),
          const FormFieldSpec('title', 'Display name'),
          const FormFieldSpec('room', 'Room'),
          const FormFieldSpec('teacher', 'Class teacher'),
        ]);
        if (v != null && context.mounted) {
          await runAction(context, () async {
            if (!RegExp(r'^\d{1,2}-[A-Z]$').hasMatch(v['id']!)) {
              throw StateError('Use a class code such as 7-A.');
            }
            if (school.accessibleClasses.contains(v['id'])) {
              throw StateError('This class already exists.');
            }
            await school.addRecord('class', {
              'title': v['title'],
              'room': v['room'],
              'teacher': v['teacher'],
            }, group: v['id']);
          }, 'Class added.');
        }
      }, school),
      ResponsiveGrid(
        children: classes
            .map(
              (c) => Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      color: teal,
                      size: 30,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      c.text('title'),
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 25,
                      ),
                    ),
                    DetailRow(
                      'Students',
                      '${school.records('student', classId: c.classId).length}',
                    ),
                    DetailRow('Room', c.text('room')),
                    DetailRow('Teacher', c.text('teacher')),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    ];
  }

  List<Widget> _admissions(BuildContext context, SchoolController school) {
    final applications = school.records('admission');
    return [
      _add('New application', () async {
        final v = await schoolForm(context, 'Welcome a new possibility', [
          const FormFieldSpec('name', 'Student name'),
          FormFieldSpec(
            'grade',
            'Requested class',
            options: school.accessibleClasses,
          ),
          const FormFieldSpec('parent', 'Guardian name'),
          const FormFieldSpec('email', 'Guardian email'),
        ]);
        if (v != null && context.mounted) {
          await runAction(
            context,
            () => school.addRecord('admission', {
              'name': v['name'],
              'grade': v['grade'],
              'parent': v['parent'],
              'email': v['email'],
              'status': 'New',
              'date': dayKey(school.clock()),
            }),
            'Application recorded.',
          );
        }
      }, school),
      if (applications.isEmpty)
        const EmptyState('A fresh start', 'New admissions will appear here.')
      else
        ...applications.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.text('name'),
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 24,
                          ),
                        ),
                      ),
                      Pill(a.text('status')),
                    ],
                  ),
                  DetailRow('Requested class', a.text('grade')),
                  DetailRow('Guardian', a.text('parent')),
                  DetailRow('Email', a.text('email')),
                  const SizedBox(height: 12),
                  if (a.text('status') != 'Enrolled')
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: school.busy
                              ? null
                              : () => runAction(
                                  context,
                                  () => school.updateAdministrative(a, {
                                    'status': 'Shortlisted',
                                  }),
                                  'Application shortlisted.',
                                ),
                          child: const Text('Shortlist'),
                        ),
                        FilledButton(
                          onPressed: school.busy
                              ? null
                              : () => runAction(
                                  context,
                                  () => school.enrollAdmission(a),
                                  'Student enrolled.',
                                ),
                          child: const Text('Enroll student'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _reports(BuildContext context, SchoolController school) {
    return [
      _add(
        'Export PDF report',
        () => runAction(context, () => exportSchoolReport(school)),
        school,
      ),
      if (school.role.teaches) ...[
        const SectionHeading('Attendance by class'),
        ResponsiveGrid(
          children: school.accessibleClasses
              .map(
                (c) => StatCard(
                  label: 'Grade $c',
                  value:
                      '${school.attendanceRate(school.records('attendance', classId: c)).toStringAsFixed(1)}%',
                  icon: Icons.fact_check_outlined,
                  note:
                      '${school.records('student', classId: c).length} enrolled students',
                ),
              )
              .toList(),
        ),
        const SectionHeading('Academic pulse'),
        ...school.accessibleClasses.map((c) {
          final marks = school
              .records('mark', classId: c)
              .where((m) => m.flag('published'))
              .toList();
          final average = marks.isEmpty
              ? 0
              : marks.fold<double>(
                      0,
                      (sum, m) =>
                          sum + m.number('score') / m.number('max') * 100,
                    ) /
                    marks.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grade $c',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  DetailRow('Published results', '${marks.length}'),
                  DetailRow(
                    'Average score',
                    marks.isEmpty
                        ? 'No results yet'
                        : '${average.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: average / 100,
                    color: teal,
                    backgroundColor: mint,
                    minHeight: 7,
                  ),
                ],
              ),
            ),
          );
        }),
      ] else ...[
        StatCard(
          label: 'Attendance',
          value:
              '${school.attendanceRate(school.records('attendance')).toStringAsFixed(1)}%',
          icon: Icons.fact_check_outlined,
          note: school.studentName,
        ),
        const SectionHeading('Published academic results'),
        ...school
            .records('mark')
            .map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Surface(
                  child: Column(
                    children: [
                      DetailRow(
                        m.text('subject'),
                        '${m.number('score')} / ${m.number('max')}',
                      ),
                      DetailRow('Assessment', m.text('assessment')),
                    ],
                  ),
                ),
              ),
            ),
      ],
    ];
  }

  List<Widget> _settings(BuildContext context, SchoolController school) {
    final settings = school.records('settings').firstOrNull;
    return [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(),
            const SizedBox(height: 22),
            Text(
              school.schoolName,
              style: const TextStyle(fontFamily: 'Fraunces', fontSize: 27),
            ),
            DetailRow('Academic year', settings?.text('year') ?? ''),
            DetailRow('Term', settings?.text('term') ?? ''),
            DetailRow('Location', settings?.text('city') ?? ''),
            if (school.role.managesSchool && settings != null)
              TextButton(
                onPressed: school.busy
                    ? null
                    : () async {
                        final v = await schoolForm(context, 'School details', [
                          FormFieldSpec(
                            'name',
                            'School name',
                            value: settings.text('name'),
                          ),
                          FormFieldSpec(
                            'city',
                            'City',
                            value: settings.text('city'),
                          ),
                          FormFieldSpec(
                            'year',
                            'Academic year',
                            value: settings.text('year'),
                          ),
                          FormFieldSpec(
                            'term',
                            'Term',
                            value: settings.text('term'),
                          ),
                        ]);
                        if (v != null && context.mounted) {
                          await runAction(
                            context,
                            () => school.updateAdministrative(settings, v),
                            'School details updated.',
                          );
                        }
                      },
                child: const Text('Edit school details'),
              ),
          ],
        ),
      ),
      const SectionHeading('Your workspace'),
      Surface(
        child: Column(
          children: [
            DetailRow('Name', school.user!.name),
            DetailRow('Role', school.role.label),
            DetailRow(
              'Workspace',
              school.live ? 'Connected school' : 'Fictional portfolio demo',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Dark appearance',
                style: TextStyle(fontSize: 13),
              ),
              value: school.dark,
              onChanged: (_) => runAction(context, school.toggleTheme),
            ),
            if (school.live)
              OutlinedButton.icon(
                onPressed: () => runAction(
                  context,
                  school.backend!.registerNotifications,
                  'Notification registration requested.',
                ),
                icon: const Icon(Icons.notifications_none),
                label: const Text('Enable notifications'),
              ),
            if (!school.live)
              OutlinedButton.icon(
                onPressed: school.busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Reset the fictional demo?'),
                            content: const Text(
                              'This removes your demo changes on this device and restores the sample school.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Reset demo'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await runAction(
                            context,
                            school.resetDemo,
                            'Demo restored.',
                          );
                        }
                      },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset demo data'),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => runAction(context, school.signOut),
              child: Text(school.live ? 'Sign out' : 'Switch demo role'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'SchoolSphere · Built with Flutter\nA portfolio project by InGrowwth Innovations.',
        style: TextStyle(fontSize: 11, height: 1.8),
      ),
    ];
  }
}
