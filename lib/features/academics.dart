import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/controller.dart';
import '../domain/models.dart';
import 'exams.dart';

class AcademicsPage extends ConsumerStatefulWidget {
  const AcademicsPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<AcademicsPage> createState() => _AcademicsPageState();
}

class _AcademicsPageState extends ConsumerState<AcademicsPage> {
  late int tab = widget.initialTab.clamp(0, 3);
  @override
  void didUpdateWidget(covariant AcademicsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      tab = widget.initialTab.clamp(0, 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider);
    return PageBody(
      onRefresh: school.refresh,
      children: [
        const SectionHeading(
          'Room to grow.',
          subtitle: 'Every question is a new possibility.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Tests'),
                icon: Icon(Icons.quiz_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Results'),
                icon: Icon(Icons.insights_outlined),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Homework'),
                icon: Icon(Icons.edit_note),
              ),
              ButtonSegment(
                value: 3,
                label: Text('Resources'),
                icon: Icon(Icons.folder_outlined),
              ),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
        ),
        const SizedBox(height: 22),
        if (tab == 0) ..._tests(context, school),
        if (tab == 1) ..._results(context, school),
        if (tab == 2) ..._homework(context, school),
        if (tab == 3) ..._resources(context, school),
      ],
    );
  }

  List<Widget> _tests(BuildContext context, SchoolController school) {
    final exams = school.records('exam');
    return [
      SectionHeading(
        'A little challenge. A lot of learning.',
        subtitle:
            'Objective questions and written responses, in one assessment.',
        action: school.role.teaches
            ? IconButton(
                tooltip: 'Create test',
                onPressed: school.busy
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (_) => const ExamBuilder(),
                      ),
                icon: const Icon(Icons.add_circle_outline),
              )
            : null,
      ),
      if (exams.isEmpty)
        const EmptyState(
          'No tests scheduled',
          'New assessments will appear here when your teacher publishes them.',
        )
      else
        ResponsiveGrid(
          children: exams.map((exam) {
            final attempts = school
                .records('attempt')
                .where((r) => r.text('exam') == exam.id)
                .toList();
            final attempt = attempts.firstOrNull;
            return Surface(
              onTap: () => context.go('/exam/${exam.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(exam.text('subject')),
                      const Spacer(),
                      const Icon(Icons.arrow_outward, size: 19, color: teal),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    exam.text('title'),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DetailRow(
                    'Time to explore',
                    '${exam.number('minutes')} minutes',
                  ),
                  DetailRow('Questions', '${exam.list('questions').length}'),
                  DetailRow('Class', exam.classId ?? ''),
                  const SizedBox(height: 14),
                  Pill(
                    school.role.teaches
                        ? '${attempts.length} attempts'
                        : attempt?.text('status') ??
                              (school.role == SchoolRole.parent
                                  ? 'Available to your child'
                                  : 'Ready when you are'),
                    color: clay,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
    ];
  }

  List<Widget> _results(BuildContext context, SchoolController school) {
    final marks = school.records('mark');
    final attempts = school
        .records('attempt')
        .where(
          (r) => school.role.teaches
              ? r.text('status') != 'In progress'
              : r.flag('published'),
        )
        .toList();
    return [
      SectionHeading(
        'Progress, made visible.',
        subtitle: school.role.teaches
            ? 'Save marks as drafts or publish them to families.'
            : 'Only published results appear here.',
        action: school.role.teaches
            ? IconButton(
                tooltip: 'Enter marks',
                onPressed: school.busy
                    ? null
                    : () => _enterMark(context, school),
                icon: const Icon(Icons.add_circle_outline),
              )
            : null,
      ),
      if (marks.isEmpty && attempts.isEmpty)
        const EmptyState(
          'Your progress story is beginning',
          'Published results will appear here.',
        )
      else ...[
        ResponsiveGrid(
          children: marks.map((mark) {
            final percent = mark.number('score') / mark.number('max') * 100;
            return Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(mark.text('subject')),
                      const Spacer(),
                      Pill(gradeFor(percent), color: clay),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Text(
                    '${mark.number('score')} / ${mark.number('max')}',
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (percent / 100).clamp(0, 1),
                      minHeight: 6,
                      color: teal,
                      backgroundColor: mint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mark.text('assessment'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (school.role.teaches)
                    DetailRow(
                      'Student',
                      school.byId(mark.studentId ?? '')?.text('name') ??
                          mark.studentId ??
                          '',
                    ),
                  const SizedBox(height: 8),
                  Text(
                    mark.text('feedback', 'Keep growing. Every effort counts.'),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Pill(
                    mark.flag('published') ? 'Published' : 'Draft',
                    color: statusColor(
                      mark.flag('published') ? 'Published' : 'Pending',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (attempts.isNotEmpty) const SectionHeading('Assessment results'),
        ...attempts.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              onTap: () => context.go('/exam/${a.text('exam')}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.text('title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (school.role.teaches)
                    DetailRow(
                      'Student',
                      school.byId(a.studentId ?? '')?.text('name') ??
                          a.studentId ??
                          '',
                    ),
                  DetailRow(
                    'Marks',
                    '${a.number('score')} / ${a.number('max')}',
                  ),
                  Pill(a.text('status'), color: statusColor(a.text('status'))),
                  if (a.text('feedback').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      a.text('feedback'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ];
  }

  Future<void> _enterMark(BuildContext context, SchoolController school) async {
    final students = school.records('student');
    if (students.isEmpty) return;
    final labels = {
      for (final s in students) '${s.text('name')} · ${s.classId}': s.id,
    };
    final v = await schoolForm(context, 'Record academic progress', [
      FormFieldSpec('student', 'Student', options: labels.keys.toList()),
      const FormFieldSpec(
        'subject',
        'Subject',
        options: [
          'Mathematics',
          'Science',
          'English',
          'Social studies',
          'Computer science',
        ],
      ),
      const FormFieldSpec(
        'assessment',
        'Assessment',
        value: 'Term 1 assessment',
      ),
      const FormFieldSpec('score', 'Marks earned', number: true),
      const FormFieldSpec('max', 'Maximum marks', value: '100', number: true),
      const FormFieldSpec(
        'feedback',
        'Teacher feedback',
        lines: 3,
        optional: true,
      ),
      const FormFieldSpec(
        'visibility',
        'Visibility',
        options: ['Draft', 'Publish'],
      ),
    ]);
    if (v != null && context.mounted) {
      await runAction(
        context,
        () => school.saveMark(
          labels[v['student']]!,
          v['subject']!,
          v['assessment']!,
          num.parse(v['score']!),
          num.parse(v['max']!),
          v['feedback']!,
          v['visibility'] == 'Publish',
        ),
        'Marks saved.',
      );
    }
  }

  List<Widget> _homework(BuildContext context, SchoolController school) {
    final homework = school.records('homework');
    return [
      SectionHeading(
        'Practice. Explore. Discover.',
        subtitle: 'A place for thoughtful work and helpful feedback.',
        action: school.role.teaches
            ? IconButton(
                tooltip: 'Assign homework',
                onPressed: school.busy
                    ? null
                    : () => _createHomework(context, school),
                icon: const Icon(Icons.add_circle_outline),
              )
            : null,
      ),
      if (homework.isEmpty)
        const EmptyState('All caught up', 'New assignments will appear here.')
      else
        ...homework.map((h) {
          final submissions = school
              .records('submission')
              .where((s) => s.text('homework') == h.id)
              .toList();
          final mine = submissions.firstOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(h.text('subject')),
                      const Spacer(),
                      Text(
                        'Due ${niceDate(h.text('due'))}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    h.text('title'),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 23,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    h.text('description'),
                    style: const TextStyle(fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 12),
                  DetailRow('Maximum marks', '${h.number('points')}'),
                  if (school.role.teaches) ...[
                    Text(
                      '${submissions.length} submissions',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    ...submissions.map(
                      (s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          school.byId(s.studentId ?? '')?.text('name') ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          s.text('status'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.rate_review_outlined),
                        onTap: () => _reviewHomework(context, school, h, s),
                      ),
                    ),
                  ] else ...[
                    if (mine != null) ...[
                      Pill(mine.text('status')),
                      const SizedBox(height: 10),
                      Text(
                        mine.text('response'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (mine.data['score'] != null)
                        DetailRow(
                          'Teacher’s marks',
                          '${mine.number('score')} / ${mine.number('max')}',
                        ),
                      if (mine.text('feedback').isNotEmpty)
                        Text(
                          mine.text('feedback'),
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                    if (school.role == SchoolRole.student &&
                        mine?.data['score'] == null) ...[
                      const SizedBox(height: 15),
                      FilledButton.icon(
                        onPressed: school.busy
                            ? null
                            : () async {
                                final v =
                                    await schoolForm(context, 'Your work', [
                                      FormFieldSpec(
                                        'answer',
                                        'Write your response',
                                        value: mine?.text('response') ?? '',
                                        lines: 7,
                                      ),
                                    ], button: 'Submit homework');
                                if (v != null && context.mounted) {
                                  await runAction(
                                    context,
                                    () =>
                                        school.submitHomework(h, v['answer']!),
                                    'Homework submitted.',
                                  );
                                }
                              },
                        icon: const Icon(Icons.upload_rounded, size: 17),
                        label: Text(
                          mine == null
                              ? 'Submit your work'
                              : 'Update submission',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        }),
    ];
  }

  Future<void> _createHomework(
    BuildContext context,
    SchoolController school,
  ) async {
    if (school.accessibleClasses.isEmpty) return;
    final v = await schoolForm(context, 'A new learning challenge', [
      const FormFieldSpec('title', 'Assignment title'),
      FormFieldSpec('class', 'Class', options: school.accessibleClasses),
      const FormFieldSpec(
        'subject',
        'Subject',
        options: [
          'Mathematics',
          'Science',
          'English',
          'Social studies',
          'Computer science',
        ],
      ),
      const FormFieldSpec('description', 'Instructions', lines: 4),
      FormFieldSpec(
        'due',
        'Due date',
        date: true,
        value: dayKey(school.clock().add(const Duration(days: 3))),
      ),
      const FormFieldSpec('points', 'Maximum marks', number: true, value: '10'),
    ]);
    if (v != null && context.mounted) {
      await runAction(context, () async {
        if (num.parse(v['points']!) <= 0) {
          throw StateError('Maximum marks must be positive.');
        }
        await school.addRecord('homework', {
          'title': v['title'],
          'subject': v['subject'],
          'description': v['description'],
          'due': v['due'],
          'points': num.parse(v['points']!),
        }, group: v['class']);
      }, 'Assignment published.');
    }
  }

  Future<void> _reviewHomework(
    BuildContext context,
    SchoolController school,
    SchoolRecord h,
    SchoolRecord s,
  ) async {
    final v = await schoolForm(
      context,
      'Review: ${school.byId(s.studentId ?? '')?.text('name') ?? 'Student'}',
      [
        FormFieldSpec(
          'response',
          'Student response',
          value: s.text('response'),
          lines: 5,
          readOnly: true,
        ),
        FormFieldSpec(
          'score',
          'Marks out of ${h.number('points')}',
          number: true,
          value: s.data['score']?.toString() ?? '',
        ),
        FormFieldSpec(
          'feedback',
          'Your feedback',
          value: s.text('feedback'),
          lines: 3,
        ),
      ],
      button: 'Send feedback',
    );
    if (v != null && context.mounted) {
      await runAction(
        context,
        () => school.reviewHomework(s, num.parse(v['score']!), v['feedback']!),
        'Feedback sent.',
      );
    }
  }

  List<Widget> _resources(BuildContext context, SchoolController school) {
    final resources = school.records('resource');
    return [
      SectionHeading(
        'A shelf of possibilities.',
        subtitle: 'Guides and materials to help ideas take root.',
        action: school.role.teaches
            ? IconButton(
                tooltip: 'Add resource',
                onPressed: school.busy
                    ? null
                    : () async {
                        if (school.accessibleClasses.isEmpty) return;
                        final v = await schoolForm(
                          context,
                          'Share a learning resource',
                          [
                            const FormFieldSpec('title', 'Title'),
                            FormFieldSpec(
                              'class',
                              'Class',
                              options: school.accessibleClasses,
                            ),
                            const FormFieldSpec('subject', 'Subject'),
                            const FormFieldSpec(
                              'body',
                              'Notes and learning material',
                              lines: 5,
                            ),
                            const FormFieldSpec(
                              'url',
                              'HTTPS link (optional)',
                              optional: true,
                            ),
                          ],
                        );
                        if (v != null && context.mounted) {
                          await runAction(context, () async {
                            if (v['url']!.isNotEmpty &&
                                Uri.tryParse(v['url']!)?.scheme != 'https') {
                              throw StateError('Use a secure HTTPS link.');
                            }
                            await school.addRecord('resource', {
                              'title': v['title'],
                              'subject': v['subject'],
                              'body': v['body'],
                              'url': v['url'],
                            }, group: v['class']);
                          }, 'Resource shared.');
                        }
                      },
                icon: const Icon(Icons.add_circle_outline),
              )
            : null,
      ),
      if (resources.isEmpty)
        const EmptyState(
          'Your resource shelf is ready',
          'Your teachers can add guides and materials here.',
        )
      else
        ...resources.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pill(r.text('subject')),
                  const SizedBox(height: 14),
                  Text(
                    r.text('title'),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    r.text('body'),
                    style: const TextStyle(fontSize: 13, height: 1.8),
                  ),
                  if (r.text('url').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => runAction(context, () async {
                        final uri = Uri.tryParse(r.text('url'));
                        if (uri == null ||
                            uri.scheme != 'https' ||
                            !await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            )) {
                          throw StateError('Could not open this resource.');
                        }
                      }),
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: const Text('Open resource'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ];
  }
}
