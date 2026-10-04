import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

class ExamPage extends ConsumerStatefulWidget {
  const ExamPage({super.key, required this.examId});
  final String examId;
  @override
  ConsumerState<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends ConsumerState<ExamPage> {
  Timer? ticker, debounce;
  int questionIndex = 0;
  bool starting = false, autoSubmitting = false;
  String? error;
  Map<String, dynamic> answers = {};
  String? loadedAttempt;
  @override
  void initState() {
    super.initState();
    if (ref.read(schoolProvider).user?.role == SchoolRole.student) {
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    debounce?.cancel();
    super.dispose();
  }

  SchoolRecord? get attempt => ref
      .read(schoolProvider)
      .records('attempt')
      .where((a) => a.text('exam') == widget.examId)
      .firstOrNull;
  void _tick() {
    if (!mounted) return;
    final school = ref.read(schoolProvider);
    if (school.user == null) return;
    final a = attempt;
    if (school.role == SchoolRole.student &&
        a?.text('status') == 'In progress' &&
        !school.clock().isBefore(DateTime.parse(a!.text('deadline'))) &&
        !autoSubmitting &&
        !school.busy) {
      _submit(automatic: true);
    } else {
      setState(() {});
    }
  }

  Future<void> _submit({bool automatic = false}) async {
    final school = ref.read(schoolProvider),
        exam = ref.read(schoolProvider).byId(widget.examId);
    if (exam == null) return;
    if (!automatic) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ready to hand it in?'),
          content: Text(
            '${answers.length} of ${exam.list('questions').length} questions answered. You cannot change answers after submitting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep working'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Submit test'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    debounce?.cancel();
    setState(() => autoSubmitting = true);
    final ok = await runAction(
      context,
      () => school.submitExam(exam, answers),
      automatic
          ? 'Time is up. Your saved answers were submitted.'
          : 'Your test has been submitted.',
    );
    if (mounted) {
      setState(() {
        autoSubmitting = false;
        error = ok ? null : 'Submission failed. Please reconnect and retry.';
      });
    }
  }

  Future<void> _save() async {
    final school = ref.read(schoolProvider),
        exam = ref.read(schoolProvider).byId(widget.examId);
    if (school.busy && attempt?.text('status') == 'In progress') {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 400), _save);
      return;
    }
    if (exam == null || attempt?.text('status') != 'In progress') {
      return;
    }
    final ok = await runAction(
      context,
      () => school.saveAnswers(exam, Map<String, dynamic>.from(answers)),
    );
    if (mounted) {
      setState(
        () => error = ok
            ? null
            : 'Your latest answer was not saved. Tap Save answers to retry.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider),
        exam = ref.watch(schoolProvider).byId(widget.examId);
    if (exam == null) {
      return const PageBody(
        children: [
          EmptyState(
            'Test unavailable',
            'It may not be published or assigned to your class.',
          ),
        ],
      );
    }
    if (school.role.teaches || school.role == SchoolRole.parent) {
      return _overview(context, school, exam);
    }
    final a = attempt;
    if (a != null && loadedAttempt != a.id) {
      loadedAttempt = a.id;
      answers = Map<String, dynamic>.from(a.data['answers'] ?? {});
    }
    if (a == null) {
      return PageBody(
        children: [
          TextButton.icon(
            onPressed: () => context.go('/academics'),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('Back to learning'),
          ),
          const SizedBox(height: 16),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pill(exam.text('subject')),
                const SizedBox(height: 18),
                Text(
                  exam.text('title'),
                  style: const TextStyle(fontFamily: 'Fraunces', fontSize: 32),
                ),
                const SizedBox(height: 20),
                DetailRow(
                  'Time available',
                  '${exam.number('minutes')} minutes',
                ),
                DetailRow('Questions', '${exam.list('questions').length}'),
                DetailRow(
                  'Total marks',
                  '${exam.list('questions').fold<num>(0, (sum, q) => sum + (q['points'] as num))}',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Find a quiet spot. Your timer starts when you begin and continues if you leave this screen. Answers save as you work. You get one attempt.',
                  style: TextStyle(fontSize: 13, height: 1.8),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: starting || school.busy
                      ? null
                      : () async {
                          setState(() => starting = true);
                          await runAction(context, () async {
                            await school.startExam(exam);
                          });
                          if (mounted) setState(() => starting = false);
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(starting ? 'Getting ready…' : 'Begin test'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (a.text('status') != 'In progress') {
      return PageBody(
        children: [
          const SectionHeading('You showed up. You gave it a go.'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.task_alt_rounded, color: teal, size: 44),
                const SizedBox(height: 18),
                Text(
                  exam.text('title'),
                  style: const TextStyle(fontFamily: 'Fraunces', fontSize: 28),
                ),
                const SizedBox(height: 14),
                Pill(a.text('status')),
                const SizedBox(height: 16),
                Text(
                  a.flag('published')
                      ? 'Your result is ready.'
                      : 'Your teacher will review and publish your result. Thank you for your effort.',
                  style: const TextStyle(fontSize: 13, height: 1.7),
                ),
                if (a.flag('published')) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${a.number('score')} / ${a.number('max')}',
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 40,
                    ),
                  ),
                  Text(
                    a.text('feedback'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/academics?tab=1'),
                  child: const Text('Back to learning'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final questions = exam.list('questions');
    questionIndex = questionIndex.clamp(0, questions.length - 1);
    final q = Map<String, dynamic>.from(questions[questionIndex]);
    final remaining = DateTime.parse(
      a.text('deadline'),
    ).difference(school.clock());
    final seconds = remaining.inSeconds.clamp(0, 10800);
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                exam.text('title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Pill(
              '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
              color: seconds < 60 ? clay : teal,
            ),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: answers.length / questions.length,
          color: teal,
          backgroundColor: mint,
          minHeight: 5,
        ),
        const SizedBox(height: 12),
        Text(
          '${answers.length} answered · ${questions.length} questions',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 24),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pill('QUESTION ${questionIndex + 1}'),
                  const Spacer(),
                  Text(
                    '${q['points']} marks',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                q['prompt'],
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 27,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 25),
              if (q['type'] == 'written')
                TextFormField(
                  key: ValueKey('${q['id']}-written'),
                  initialValue: answers[q['id']]?.toString() ?? '',
                  maxLines: 7,
                  enabled: !autoSubmitting && seconds > 0,
                  decoration: const InputDecoration(
                    hintText: 'Explain your thinking…',
                  ),
                  onChanged: (v) {
                    answers[q['id']] = v;
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 700), _save);
                  },
                )
              else
                ...List.generate(
                  (q['options'] as List).length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Surface(
                      color: answers[q['id']] == i
                          ? (isDark(context) ? const Color(0xFF234B40) : mint)
                          : null,
                      padding: const EdgeInsets.all(16),
                      onTap: school.busy || autoSubmitting || seconds == 0
                          ? null
                          : () async {
                              final old = answers[q['id']];
                              setState(() => answers[q['id']] = i);
                              await _save();
                              if (error != null && mounted) {
                                setState(() {
                                  if (old == null) {
                                    answers.remove(q['id']);
                                  } else {
                                    answers[q['id']] = old;
                                  }
                                });
                              }
                            },
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: teal.withValues(alpha: .3),
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              q['options'][i],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (answers[q['id']] == i)
                            const Icon(
                              Icons.check_circle,
                              color: teal,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              error!,
              style: const TextStyle(color: clay, fontSize: 12),
            ),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: questionIndex == 0
                    ? null
                    : () async {
                        await _save();
                        if (mounted) setState(() => questionIndex--);
                      },
                child: const Text('Previous', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: school.busy || autoSubmitting
                    ? null
                    : () async {
                        await _save();
                        if (!mounted) return;
                        if (questionIndex < questions.length - 1) {
                          setState(() => questionIndex++);
                        } else {
                          _submit();
                        }
                      },
                child: Text(
                  questionIndex < questions.length - 1
                      ? 'Next question'
                      : 'Submit test',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            questions.length,
            (i) => ActionChip(
              label: Text('${i + 1}'),
              avatar: answers.containsKey(questions[i]['id'])
                  ? const Icon(Icons.check, size: 13)
                  : null,
              onPressed: () async {
                await _save();
                if (mounted) setState(() => questionIndex = i);
              },
            ),
          ),
        ),
        TextButton.icon(
          onPressed: school.busy ? null : _save,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save answers'),
        ),
      ],
    );
  }

  Widget _overview(
    BuildContext context,
    SchoolController school,
    SchoolRecord exam,
  ) {
    final attempts = school
        .records('attempt')
        .where((a) => a.text('exam') == exam.id)
        .toList();
    return PageBody(
      children: [
        TextButton.icon(
          onPressed: () => context.go('/academics'),
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('Back to learning'),
        ),
        SectionHeading(
          exam.text('title'),
          subtitle:
              '${exam.text('subject')} · ${exam.classId} · ${exam.number('minutes')} minutes',
        ),
        if (school.role == SchoolRole.parent)
          const Surface(
            child: Text(
              'This test is available in your child’s student account. Parents can view published results from Learning → Results.',
              style: TextStyle(fontSize: 13, height: 1.7),
            ),
          )
        else ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Question paper',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...exam
                    .list('questions')
                    .indexed
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.$1 + 1}. ${entry.$2['prompt']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entry.$2['points']} marks · ${entry.$2['type'] == 'written' ? 'Written response' : 'Multiple choice'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SectionHeading(
            'Student attempts',
            subtitle:
                'Review written answers, add feedback, and publish results.',
          ),
          if (attempts.isEmpty)
            const EmptyState(
              'Ready for the first attempt',
              'Student submissions will appear here.',
            )
          else
            ...attempts.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PersonAvatar(
                            school.byId(a.studentId ?? '')?.text('name') ??
                                'Student',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              school.byId(a.studentId ?? '')?.text('name') ??
                                  a.studentId ??
                                  '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Pill(
                            a.text('status'),
                            color: statusColor(a.text('status')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (a.text('status') != 'In progress') ...[
                        DetailRow(
                          'Marks',
                          '${a.number('score')} / ${a.number('max')}',
                        ),
                        DetailRow(
                          'Visibility',
                          a.flag('published')
                              ? 'Published'
                              : 'Not yet published',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: school.busy
                              ? null
                              : () => _review(context, school, exam, a),
                          child: const Text('Review & publish'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _review(
    BuildContext context,
    SchoolController school,
    SchoolRecord exam,
    SchoolRecord a,
  ) async {
    final written = exam
        .list('questions')
        .where((q) => q['type'] == 'written')
        .toList();
    final answers = Map<String, dynamic>.from(a.data['answers'] ?? {});
    final scores = Map<String, dynamic>.from(a.data['writtenScores'] ?? {});
    final fields = <FormFieldSpec>[
      ...written.expand(
        (q) => [
          FormFieldSpec(
            'response-${q['id']}',
            q['prompt'],
            value: answers[q['id']]?.toString() ?? 'No answer submitted',
            lines: 4,
            readOnly: true,
          ),
          FormFieldSpec(
            'score-${q['id']}',
            'Marks out of ${q['points']}',
            value: scores[q['id']]?.toString() ?? '',
            number: true,
          ),
        ],
      ),
      FormFieldSpec(
        'feedback',
        'Teacher feedback',
        value: a.text('feedback'),
        lines: 3,
        optional: true,
      ),
      const FormFieldSpec(
        'visibility',
        'Visibility',
        options: ['Save review', 'Publish result'],
      ),
    ];
    final v = await schoolForm(
      context,
      'Review student work',
      fields,
      button: 'Save review',
    );
    if (v != null && context.mounted) {
      await runAction(
        context,
        () => school.reviewAttempt(
          a,
          {for (final q in written) q['id']: num.parse(v['score-${q['id']}']!)},
          v['feedback']!,
          publish: v['visibility'] == 'Publish result',
        ),
        'Review saved.',
      );
    }
  }
}

class QuestionDraft {
  final prompt = TextEditingController(),
      points = TextEditingController(text: '5');
  final options = List.generate(4, (_) => TextEditingController());
  int correct = 0;
  bool written = false;
  void dispose() {
    prompt.dispose();
    points.dispose();
    for (final c in options) {
      c.dispose();
    }
  }
}

class ExamBuilder extends ConsumerStatefulWidget {
  const ExamBuilder({super.key});
  @override
  ConsumerState<ExamBuilder> createState() => _ExamBuilderState();
}

class _ExamBuilderState extends ConsumerState<ExamBuilder> {
  final title = TextEditingController(),
      minutes = TextEditingController(text: '15');
  final form = GlobalKey<FormState>();
  final questions = [QuestionDraft()];
  String? group;
  String subject = 'Mathematics';
  bool saving = false, saveToBank = true;
  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    for (final q in questions) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider);
    group ??= school.accessibleClasses.firstOrNull;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Create a little challenge.',
                      style: TextStyle(fontFamily: 'Fraunces', fontSize: 26),
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: title,
                          decoration: const InputDecoration(
                            labelText: 'Test title',
                          ),
                          validator: (v) => v?.trim().isNotEmpty == true
                              ? null
                              : 'Enter a title',
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: group,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: school.accessibleClasses
                              .map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              )
                              .toList(),
                          onChanged: (v) => group = v,
                          validator: (v) => v == null ? 'Choose a class' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: subject,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                          ),
                          items:
                              [
                                    'Mathematics',
                                    'Science',
                                    'English',
                                    'Social studies',
                                    'Computer science',
                                  ]
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => subject = v!,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: minutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration in minutes',
                          ),
                          validator: (v) =>
                              int.tryParse(v ?? '') != null &&
                                  int.parse(v!) >= 1 &&
                                  int.parse(v) <= 180
                              ? null
                              : 'Choose 1–180 minutes',
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  final bank = school.records('question');
                                  final selected = await showDialog<SchoolRecord>(
                                    context: context,
                                    builder: (c) => SimpleDialog(
                                      title: const Text('Your question bank'),
                                      children: [
                                        if (bank.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(20),
                                            child: Text(
                                              'Saved questions will appear here.',
                                            ),
                                          ),
                                        ...bank.map(
                                          (r) => SimpleDialogOption(
                                            onPressed: () =>
                                                Navigator.pop(c, r),
                                            child: Text(
                                              '${r.text('subject')} · ${r.text('prompt')}',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (selected != null && mounted) {
                                    setState(() {
                                      final q = QuestionDraft();
                                      q.prompt.text = selected.text('prompt');
                                      q.points.text = selected.text('points');
                                      q.written =
                                          selected.text('type') == 'written';
                                      q.correct = selected
                                          .number('correct')
                                          .toInt();
                                      for (final option
                                          in selected
                                              .list('options')
                                              .take(4)
                                              .indexed) {
                                        q.options[option.$1].text = option.$2
                                            .toString();
                                      }
                                      if (questions.length == 1 &&
                                          questions.first.prompt.text.isEmpty) {
                                        questions.first.dispose();
                                        questions.clear();
                                      }
                                      questions.add(q);
                                    });
                                  }
                                },
                          icon: const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 18,
                          ),
                          label: const Text('Use a saved question'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Save questions to my question bank',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: saveToBank,
                          onChanged: saving
                              ? null
                              : (v) => setState(() => saveToBank = v),
                        ),
                        ...questions.indexed.map((entry) {
                          final q = entry.$2;
                          return Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: Surface(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Question ${entry.$1 + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (questions.length > 1)
                                        IconButton(
                                          onPressed: saving
                                              ? null
                                              : () => setState(() {
                                                  questions.remove(q);
                                                  q.dispose();
                                                }),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Written response',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: q.written,
                                    onChanged: (v) =>
                                        setState(() => q.written = v),
                                  ),
                                  TextFormField(
                                    controller: q.prompt,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Question',
                                    ),
                                    validator: (v) =>
                                        v?.trim().isNotEmpty == true
                                        ? null
                                        : 'Write a question',
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: q.points,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Marks',
                                    ),
                                    validator: (v) =>
                                        int.tryParse(v ?? '') != null &&
                                            int.parse(v!) > 0 &&
                                            int.parse(v) <= 100
                                        ? null
                                        : 'Choose 1–100 marks',
                                  ),
                                  if (!q.written)
                                    ...q.options.indexed.map(
                                      (o) => Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              tooltip: 'Set correct answer',
                                              onPressed: () => setState(
                                                () => q.correct = o.$1,
                                              ),
                                              icon: Icon(
                                                q.correct == o.$1
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked,
                                                color: teal,
                                              ),
                                            ),
                                            Expanded(
                                              child: TextFormField(
                                                controller: o.$2,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Option ${String.fromCharCode(65 + o.$1)}',
                                                ),
                                                validator: (v) =>
                                                    v?.trim().isNotEmpty == true
                                                    ? null
                                                    : 'Add this option',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (!q.written)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                        'Select the check beside the correct answer.',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: saving || questions.length >= 30
                              ? null
                              : () => setState(
                                  () => questions.add(QuestionDraft()),
                                ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add question'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          setState(() => saving = true);
                          final qs = questions.indexed
                              .map(
                                (e) => <String, dynamic>{
                                  'id': 'q${e.$1 + 1}',
                                  'prompt': e.$2.prompt.text.trim(),
                                  'points': int.parse(e.$2.points.text),
                                  'type': e.$2.written ? 'written' : 'mcq',
                                  'options': e.$2.written
                                      ? []
                                      : e.$2.options
                                            .map((c) => c.text.trim())
                                            .toList(),
                                },
                              )
                              .toList();
                          final keys = {
                            for (final e in questions.indexed)
                              if (!e.$2.written) 'q${e.$1 + 1}': e.$2.correct,
                          };
                          final ok = await runAction(
                            context,
                            () => school.createExam(
                              title.text,
                              subject,
                              group!,
                              int.parse(minutes.text),
                              qs,
                              keys,
                              saveToBank: saveToBank,
                            ),
                            'Test published to your class.',
                          );
                          if (mounted && context.mounted) {
                            if (ok) {
                              Navigator.pop(context);
                            } else {
                              setState(() => saving = false);
                            }
                          }
                        },
                  child: Text(saving ? 'Publishing…' : 'Publish test'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
