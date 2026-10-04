import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/backend.dart';
import '../core/storage.dart';
import 'models.dart';
import 'seed.dart';

final schoolProvider = ChangeNotifierProvider<SchoolController>(
  (ref) => throw UnimplementedError('Override at startup'),
);

class SchoolController extends ChangeNotifier {
  SchoolController(this.storage, {this.backend, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final SchoolStorage storage;
  final SchoolBackend? backend;
  final DateTime Function() clock;
  List<SchoolRecord> _all = [];
  Map<String, Map<String, int>> _keys = {};
  SchoolUser? user;
  String? selectedChild;
  bool busy = false, dark = false;
  String? notificationWarning;
  bool get live => backend != null;
  SchoolRole get role => user!.role;
  String get schoolName =>
      records('settings').firstOrNull?.text('name') ?? 'Your school';
  List<String> get accessibleClasses => role.managesSchool
      ? records('class').map((r) => r.classId!).toList()
      : user!.classes;
  String? get studentId => role == SchoolRole.student
      ? user!.id
      : selectedChild ?? user?.children.firstOrNull;
  String get studentName =>
      _all
          .where((r) => r.kind == 'student' && r.id == studentId)
          .firstOrNull
          ?.text('name') ??
      user?.name ??
      '';
  String? get studentClass => _all
      .where((r) => r.kind == 'student' && r.id == studentId)
      .firstOrNull
      ?.classId;
  List<SchoolRecord> get children => _all
      .where(
        (r) => r.kind == 'student' && (user?.children.contains(r.id) ?? false),
      )
      .toList();

  Future<void> initialize() async {
    if (live) {
      if (backend!.client.auth.currentSession != null) {
        try {
          user = await backend!.currentProfile();
          _all = await backend!.load();
        } catch (_) {
          await backend!.client.auth.signOut();
          user = null;
        }
      }
    } else {
      final saved = await storage.read();
      _all = saved == null
          ? seedSchool(now: clock())
          : (saved['records'] as List)
                .map((r) => SchoolRecord.fromJson(Map<String, dynamic>.from(r)))
                .toList();
      _keys = saved == null
          ? {...demoAnswerKeys}
          : Map<String, dynamic>.from(
              saved['keys'] ?? {},
            ).map((key, value) => MapEntry(key, Map<String, int>.from(value)));
      dark = saved?['dark'] == true;
    }
  }

  void enterDemo(SchoolUser profile) {
    if (live) throw StateError('Demo access is disabled in live mode.');
    final staff = _all
        .where((r) => r.kind == 'staff' && r.id == profile.id)
        .firstOrNull;
    user = SchoolUser(
      id: profile.id,
      name: profile.name,
      role: profile.role,
      schoolId: profile.schoolId,
      children: profile.children,
      classes: profile.role == SchoolRole.teacher && staff != null
          ? List<String>.from(staff.list('classes'))
          : profile.classes,
    );
    selectedChild = profile.children.firstOrNull;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (!live) throw StateError('Use a demo profile.');
    user = await backend!.signIn(email, password);
    try {
      _all = await backend!.load();
    } catch (_) {
      await backend!.client.auth.signOut();
      user = null;
      rethrow;
    }
    selectedChild = user!.children.firstOrNull;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (live) {
      await backend!.client.auth.signOut();
      _all = [];
    }
    user = null;
    selectedChild = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (live) {
      user = await backend!.currentProfile();
      _all = await backend!.load();
    }
    notifyListeners();
  }

  void chooseChild(String id) {
    if (!user!.children.contains(id)) {
      throw StateError('Child is not linked to this account.');
    }
    selectedChild = id;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    dark = !dark;
    notifyListeners();
    if (!live) await storage.write(_snapshot(_all));
  }

  Future<void> resetDemo() async {
    if (live) {
      throw StateError('Reset is available only in the fictional demo.');
    }
    final previousKeys = _keys;
    _keys = {...demoAnswerKeys};
    try {
      await _commit(seedSchool(now: clock()), replace: true);
    } catch (_) {
      _keys = previousKeys;
      rethrow;
    }
  }

  bool _visible(SchoolRecord r) {
    if (user == null || r.schoolId != user!.schoolId) return false;
    if (r.kind == 'message') return r.list('recipients').contains(user!.id);
    if (role.managesSchool) return true;
    if (r.kind == 'question') {
      return role == SchoolRole.teacher && user!.classes.contains(r.classId);
    }
    if (r.kind == 'settings' || r.kind == 'book' || r.kind == 'staff') {
      return true;
    }
    if (r.kind == 'staffAttendance') return r.ownerId == user!.id;
    if (r.kind == 'admission') return false;
    if (role == SchoolRole.teacher) {
      if (r.kind == 'leave') return r.ownerId == user!.id;
      if (r.kind == 'fee' || r.kind == 'borrow') return false;
      return r.classId == null || user!.classes.contains(r.classId);
    }
    final isOwn = r.studentId == studentId;
    if (r.kind == 'student') return r.id == studentId;
    if ([
      'attendance',
      'attempt',
      'submission',
      'fee',
      'borrow',
      'leave',
    ].contains(r.kind)) {
      return isOwn;
    }
    if (r.kind == 'mark') return isOwn && r.flag('published');
    if (r.kind == 'exam' && !r.flag('published')) return false;
    return r.classId == null || r.classId == studentClass;
  }

  List<SchoolRecord> records(String kind, {String? classId}) => _all
      .where(
        (r) =>
            r.kind == kind &&
            _visible(r) &&
            (classId == null || r.classId == classId),
      )
      .toList();
  SchoolRecord? byId(String id) =>
      _all.where((r) => r.id == id && _visible(r)).firstOrNull;
  Map<String, dynamic> _snapshot(List<SchoolRecord> records) => {
    'version': 1,
    'dark': dark,
    'records': records.map((r) => r.toJson()).toList(),
    'keys': _keys,
  };
  String newId(String prefix) =>
      '$prefix-${clock().microsecondsSinceEpoch}-${_all.length}';
  void _require(bool allowed) {
    if (!allowed) throw StateError('Your account cannot perform this action.');
  }

  void _classPermission(String? group) => _require(
    role.managesSchool ||
        (role == SchoolRole.teacher &&
            group != null &&
            user!.classes.contains(group)),
  );

  Future<void> _commit(
    List<SchoolRecord> changes, {
    bool replace = false,
    bool remote = true,
  }) async {
    if (busy) {
      throw StateError('A save is already in progress. Please try again.');
    }
    final committingUser = user?.id;
    busy = true;
    notifyListeners();
    try {
      final ids = changes.map((r) => r.id).toSet();
      var next = replace
          ? changes
          : [..._all.where((r) => !ids.contains(r.id)), ...changes];
      if (live && remote) {
        final canonical = await backend!.save(changes);
        final canonicalIds = canonical.map((r) => r.id).toSet();
        next = [
          ...next.where((r) => !canonicalIds.contains(r.id)),
          ...canonical,
        ];
      }
      if (!live) await storage.write(_snapshot(next));
      if (live && user?.id != committingUser) return;
      _all = next;
      if (live &&
          const bool.fromEnvironment('ENABLE_PUSH') &&
          user?.role.teaches == true) {
        try {
          await backend!.notifyUpdates(changes);
          notificationWarning = null;
        } catch (_) {
          notificationWarning =
              'Your changes were saved. Push delivery needs attention in the school setup.';
        }
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveAttendance(
    String classId,
    DateTime date,
    Map<String, String> statuses,
  ) async {
    _classPermission(classId);
    if (date.isAfter(clock())) {
      throw StateError('Attendance cannot be recorded for a future date.');
    }
    final roster = records('student', classId: classId);
    _require(
      statuses.isNotEmpty &&
          statuses.keys.every((id) => roster.any((s) => s.id == id)),
    );
    if (statuses.values.any(
      (s) => !['Present', 'Absent', 'Late', 'Excused'].contains(s),
    )) {
      throw ArgumentError('Invalid attendance status');
    }
    final day = dayKey(date);
    await _commit(
      statuses.entries
          .map(
            (e) => SchoolRecord(
              id: 'att-${e.key}-$day',
              kind: 'attendance',
              classId: classId,
              studentId: e.key,
              ownerId: user!.id,
              schoolId: user!.schoolId,
              data: {
                'date': day,
                'status': e.value,
                'name': roster.firstWhere((s) => s.id == e.key).text('name'),
              },
            ),
          )
          .toList(),
    );
  }

  Future<void> staffCheckIn() async {
    _require(role.teaches);
    final id = 'staff-${user!.id}-${dayKey(clock())}';
    final existing = byId(id);
    if (existing?.data['out'] != null) {
      throw StateError('You have already checked out today.');
    }
    await _commit([
      existing != null
          ? existing.copy({'out': clock().toIso8601String()})
          : SchoolRecord(
              id: id,
              kind: 'staffAttendance',
              ownerId: user!.id,
              schoolId: user!.schoolId,
              data: {
                'name': user!.name,
                'date': dayKey(clock()),
                'in': clock().toIso8601String(),
              },
            ),
    ]);
  }

  Future<SchoolRecord> startExam(SchoolRecord exam) async {
    _require(
      role == SchoolRole.student &&
          exam.classId == studentClass &&
          exam.flag('published'),
    );
    final existing = records(
      'attempt',
    ).where((r) => r.text('exam') == exam.id).firstOrNull;
    if (existing != null) return existing;
    if (live) {
      final attempt = await backend!.examAction('start', exam.id);
      await _commit([attempt], remote: false);
      return attempt;
    }
    final attempt = SchoolRecord(
      id: 'attempt-${exam.id}-${user!.id}',
      kind: 'attempt',
      classId: exam.classId,
      studentId: user!.id,
      ownerId: user!.id,
      schoolId: user!.schoolId,
      data: {
        'exam': exam.id,
        'title': exam.text('title'),
        'subject': exam.text('subject'),
        'status': 'In progress',
        'started': clock().toIso8601String(),
        'deadline': clock()
            .add(Duration(minutes: exam.number('minutes').toInt()))
            .toIso8601String(),
        'answers': <String, dynamic>{},
      },
    );
    await _commit([attempt]);
    return attempt;
  }

  Future<void> saveAnswers(
    SchoolRecord exam,
    Map<String, dynamic> answers,
  ) async {
    final attempt = records(
      'attempt',
    ).firstWhere((r) => r.text('exam') == exam.id);
    _require(role == SchoolRole.student && attempt.studentId == user!.id);
    if (attempt.text('status') != 'In progress') {
      throw StateError('This test has already been submitted.');
    }
    if (!clock().isBefore(DateTime.parse(attempt.text('deadline')))) {
      await submitExam(exam, answers);
      return;
    }
    if (live) {
      await _commit([
        await backend!.examAction('save', exam.id, answers),
      ], remote: false);
    } else {
      await _commit([
        attempt.copy({'answers': answers}),
      ]);
    }
  }

  Future<void> submitExam(
    SchoolRecord exam,
    Map<String, dynamic> answers,
  ) async {
    _require(role == SchoolRole.student);
    final attempt = records(
      'attempt',
    ).firstWhere((r) => r.text('exam') == exam.id);
    _require(attempt.studentId == user!.id);
    if (attempt.text('status') != 'In progress') return;
    if (live) {
      await _commit([
        await backend!.examAction('submit', exam.id, answers),
      ], remote: false);
      return;
    }
    var score = 0, maximum = 0;
    final written = <String, dynamic>{};
    final validAnswers = <String, dynamic>{};
    // A deadline is authoritative. Late submissions grade the last saved answers.
    final actualAnswers =
        clock().isAfter(DateTime.parse(attempt.text('deadline')))
        ? Map<String, dynamic>.from(attempt.data['answers'] ?? {})
        : answers;
    for (final raw in exam.list('questions')) {
      final q = Map<String, dynamic>.from(raw);
      final points = (q['points'] as num).toInt();
      maximum += points;
      if (actualAnswers.containsKey(q['id'])) {
        validAnswers[q['id']] = actualAnswers[q['id']];
      }
      if (q['type'] == 'written') {
        written[q['id']] = null;
      } else if (actualAnswers[q['id']] == _keys[exam.id]?[q['id']]) {
        score += points;
      }
    }
    await _commit([
      attempt.copy({
        'answers': validAnswers,
        'score': score,
        'max': maximum,
        'writtenScores': written,
        'status': written.isEmpty ? 'Graded' : 'Awaiting review',
        'published': false,
        'submitted': clock().toIso8601String(),
      }),
    ]);
  }

  Future<void> reviewAttempt(
    SchoolRecord attempt,
    Map<String, num> writtenScores,
    String feedback, {
    required bool publish,
  }) async {
    _classPermission(attempt.classId);
    final exam = byId(attempt.text('exam'))!;
    if (attempt.text('status') == 'In progress') {
      throw StateError('The student has not submitted this test.');
    }
    var writtenTotal = 0;
    for (final raw
        in exam.list('questions').where((q) => q['type'] == 'written')) {
      final score = writtenScores[raw['id']];
      if (score == null ||
          score < 0 ||
          score > (raw['points'] as num) ||
          score != score.roundToDouble()) {
        throw StateError(
          'Enter a whole-number mark within the question maximum.',
        );
      }
      writtenTotal += score.toInt();
    }
    if (live) {
      await _commit([
        await backend!.reviewAttempt(attempt, writtenScores, feedback, publish),
      ], remote: false);
      return;
    }
    final previous = Map<String, dynamic>.from(
      attempt.data['writtenScores'] ?? {},
    );
    final objectiveScore =
        attempt.number('score') -
        previous.values.fold<num>(0, (sum, v) => sum + ((v as num?) ?? 0));
    await _commit([
      attempt.copy({
        'score': objectiveScore + writtenTotal,
        'writtenScores': writtenScores,
        'feedback': feedback,
        'status': 'Graded',
        'published': publish,
      }),
    ]);
  }

  Future<void> createExam(
    String title,
    String subject,
    String group,
    int minutes,
    List<Map<String, dynamic>> questions,
    Map<String, int> keys, {
    bool saveToBank = false,
  }) async {
    _classPermission(group);
    if (title.trim().isEmpty ||
        minutes < 1 ||
        minutes > 180 ||
        questions.isEmpty ||
        questions.length > 30) {
      throw StateError('Add a title, duration, and at least one question.');
    }
    for (final q in questions) {
      if ((q['prompt'] as String).trim().isEmpty || (q['points'] as num) <= 0) {
        throw StateError('Every question needs a prompt and positive marks.');
      }
      if (q['type'] == 'mcq' &&
          (keys[q['id']] == null ||
              keys[q['id']]! < 0 ||
              keys[q['id']]! >= (q['options'] as List).length)) {
        throw StateError(
          'Select a correct answer for every objective question.',
        );
      }
    }
    final exam = SchoolRecord(
      id: newId('exam'),
      kind: 'exam',
      classId: group,
      ownerId: user!.id,
      schoolId: user!.schoolId,
      data: {
        'title': title.trim(),
        'subject': subject,
        'minutes': minutes,
        'questions': questions,
        'published': true,
        'date': dayKey(clock()),
      },
    );
    if (live) {
      await backend!.createExam(exam, keys, saveToBank: saveToBank);
      await _commit([exam], remote: false);
    } else {
      _keys[exam.id] = keys;
      try {
        final bank = saveToBank
            ? questions
                  .map(
                    (q) => SchoolRecord(
                      id: 'bank-${exam.id}-${q['id']}',
                      kind: 'question',
                      schoolId: user!.schoolId,
                      classId: group,
                      ownerId: user!.id,
                      data: {
                        ...q,
                        'subject': subject,
                        'correct': keys[q['id']],
                      },
                    ),
                  )
                  .toList()
            : <SchoolRecord>[];
        await _commit([exam, ...bank]);
      } catch (_) {
        _keys.remove(exam.id);
        rethrow;
      }
    }
  }

  Future<void> saveMark(
    String student,
    String subject,
    String assessment,
    num score,
    num maximum,
    String feedback,
    bool publish,
  ) async {
    final pupil = byId(student);
    _classPermission(pupil?.classId);
    if (maximum <= 0 || score < 0 || score > maximum) {
      throw StateError('Marks must be between zero and the maximum.');
    }
    final existing = records('mark')
        .where(
          (r) =>
              r.studentId == student &&
              r.text('subject') == subject &&
              r.text('assessment') == assessment,
        )
        .firstOrNull;
    await _commit([
      SchoolRecord(
        id: existing?.id ?? newId('mark'),
        kind: 'mark',
        classId: pupil!.classId,
        studentId: student,
        ownerId: user!.id,
        schoolId: user!.schoolId,
        data: {
          'subject': subject,
          'assessment': assessment,
          'score': score,
          'max': maximum,
          'feedback': feedback,
          'published': publish,
        },
      ),
    ]);
  }

  Future<void> submitHomework(SchoolRecord assignment, String response) async {
    _require(role == SchoolRole.student && assignment.classId == studentClass);
    if (response.trim().length < 5) {
      throw StateError('Please write your answer before submitting.');
    }
    final existing = records(
      'submission',
    ).where((r) => r.text('homework') == assignment.id).firstOrNull;
    if (existing?.data['score'] != null) {
      throw StateError('A graded submission cannot be edited.');
    }
    await _commit([
      SchoolRecord(
        id: existing?.id ?? 'submission-${assignment.id}-${user!.id}',
        kind: 'submission',
        studentId: user!.id,
        classId: assignment.classId,
        ownerId: user!.id,
        schoolId: user!.schoolId,
        data: {
          'homework': assignment.id,
          'title': assignment.text('title'),
          'response': response.trim(),
          'sent': clock().toIso8601String(),
          'status': dayKey(clock()).compareTo(assignment.text('due')) > 0
              ? 'Submitted late'
              : 'Submitted',
        },
      ),
    ]);
  }

  Future<void> reviewHomework(
    SchoolRecord submission,
    num score,
    String feedback,
  ) async {
    _classPermission(submission.classId);
    final assignment = byId(submission.text('homework'))!;
    if (score < 0 || score > assignment.number('points')) {
      throw StateError('Marks exceed the assignment maximum.');
    }
    await _commit([
      submission.copy({
        'score': score,
        'max': assignment.number('points'),
        'feedback': feedback,
        'status': 'Reviewed',
      }),
    ]);
  }

  Future<void> requestLeave(String reason, DateTime from, DateTime to) async {
    _require(role != SchoolRole.student);
    if (reason.trim().length < 5 ||
        to.isBefore(from) ||
        dayKey(from).compareTo(dayKey(clock())) < 0) {
      throw StateError('Enter a reason and a valid future date range.');
    }
    await _commit([
      SchoolRecord(
        id: newId('leave'),
        kind: 'leave',
        classId: role == SchoolRole.parent ? studentClass : null,
        studentId: role == SchoolRole.parent ? studentId : null,
        ownerId: user!.id,
        schoolId: user!.schoolId,
        data: {
          'name': role == SchoolRole.parent ? studentName : user!.name,
          'reason': reason.trim(),
          'from': dayKey(from),
          'to': dayKey(to),
          'status': 'Pending',
          'type': role == SchoolRole.parent ? 'Student' : 'Staff',
        },
      ),
    ]);
  }

  Future<void> decideLeave(SchoolRecord leave, bool approved) async {
    _require(
      role.managesSchool &&
          leave.text('status') == 'Pending' &&
          leave.ownerId != user!.id,
    );
    await _commit([
      leave.copy({
        'status': approved ? 'Approved' : 'Declined',
        'reviewer': user!.name,
      }),
    ]);
  }

  Future<void> recordPayment(SchoolRecord fee, num amount) async {
    _require(role.managesSchool);
    final remaining = fee.number('amount') - fee.number('paid');
    if (amount <= 0 || amount > remaining) {
      throw StateError('Enter an amount within the outstanding balance.');
    }
    final paid = fee.number('paid') + amount;
    await _commit([
      fee.copy({
        'paid': paid,
        'status': paid >= fee.number('amount') ? 'Paid' : 'Part paid',
        'receipt': 'SS-${clock().millisecondsSinceEpoch}',
        'paidOn': clock().toIso8601String(),
      }),
    ]);
  }

  Future<void> borrowBook(SchoolRecord book) async {
    _require(role == SchoolRole.student);
    final active = _all.where(
      (r) =>
          r.kind == 'borrow' &&
          r.text('book') == book.id &&
          r.text('status') == 'Borrowed',
    );
    if (active.any((r) => r.studentId == user!.id)) {
      throw StateError('You already have this book.');
    }
    if (active.length >= book.number('copies')) {
      throw StateError('All copies are currently on loan.');
    }
    if (live) {
      final row = await backend!.client.rpc(
        'borrow_book',
        params: {'book_id': book.id},
      );
      await _commit([
        SchoolRecord.fromJson(Map<String, dynamic>.from(row)),
      ], remote: false);
    } else {
      await _commit([
        SchoolRecord(
          id: newId('borrow'),
          kind: 'borrow',
          studentId: user!.id,
          classId: studentClass,
          ownerId: user!.id,
          data: {
            'book': book.id,
            'title': book.text('title'),
            'status': 'Borrowed',
            'due': dayKey(clock().add(const Duration(days: 14))),
          },
        ),
      ]);
    }
  }

  Future<void> returnBook(SchoolRecord loan) async {
    _require(
      role.managesSchool ||
          (role == SchoolRole.student && loan.studentId == user!.id),
    );
    if (live) {
      final row = await backend!.client.rpc(
        'return_book',
        params: {'loan_id': loan.id},
      );
      await _commit([
        SchoolRecord.fromJson(Map<String, dynamic>.from(row)),
      ], remote: false);
    } else {
      await _commit([
        loan.copy({'status': 'Returned', 'returned': dayKey(clock())}),
      ]);
    }
  }

  Future<void> sendMessage(
    String recipientId,
    String recipientName,
    String body,
  ) async {
    if (body.trim().isEmpty) throw StateError('Write a message first.');
    _require(recipientId != user!.id);
    // In live mode the database verifies school membership and permitted relationships.
    await _commit([
      SchoolRecord(
        id: newId('message'),
        kind: 'message',
        ownerId: user!.id,
        schoolId: user!.schoolId,
        data: {
          'body': body.trim(),
          'sender': user!.name,
          'recipient': recipientName,
          'recipients': [user!.id, recipientId],
          'sent': clock().toIso8601String(),
        },
      ),
    ]);
  }

  Future<void> addRecord(
    String kind,
    Map<String, dynamic> data, {
    String? group,
    String? pupil,
  }) async {
    const teacherKinds = ['homework', 'notice', 'resource', 'question'];
    if (teacherKinds.contains(kind)) {
      if (group == null) {
        _require(role.managesSchool);
      } else {
        _classPermission(group);
      }
    } else {
      _require(
        role.managesSchool &&
            [
              'student',
              'staff',
              'class',
              'schedule',
              'fee',
              'book',
              'transport',
              'admission',
            ].contains(kind),
      );
    }
    final id = newId(kind);
    await _commit([
      SchoolRecord(
        id: id,
        kind: kind,
        classId: group,
        studentId: kind == 'student' ? id : pupil,
        ownerId: user!.id,
        schoolId: user!.schoolId,
        data: data,
      ),
    ]);
  }

  Future<void> updateAdministrative(
    SchoolRecord record,
    Map<String, dynamic> values,
  ) async {
    _require(
      role.managesSchool &&
          [
            'settings',
            'admission',
            'class',
            'staff',
            'transport',
          ].contains(record.kind),
    );
    await _commit([record.copy(values)]);
  }

  Future<void> enrollAdmission(SchoolRecord admission) async {
    _require(role.managesSchool && admission.text('status') != 'Enrolled');
    final group = admission.text('grade');
    if (!accessibleClasses.contains(group)) {
      throw StateError('Create the requested class before enrolling.');
    }
    final id = 'enrolled-${admission.id}';
    final used = records(
      'student',
      classId: group,
    ).map((s) => int.tryParse(s.text('roll')) ?? 0).toList();
    final roll = used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;
    await _commit([
      SchoolRecord(
        id: id,
        kind: 'student',
        studentId: id,
        classId: group,
        ownerId: user!.id,
        schoolId: user!.schoolId,
        data: {
          'name': admission.text('name'),
          'parent': admission.text('parent'),
          'email': admission.text('email'),
          'roll': '$roll'.padLeft(2, '0'),
          'joined': dayKey(clock()),
        },
      ),
      admission.copy({'status': 'Enrolled', 'student': id}),
    ]);
  }

  double attendanceRate(List<SchoolRecord> attendance) {
    if (attendance.isEmpty) return 0;
    final counted = attendance
        .where((r) => r.text('status') != 'Excused')
        .toList();
    if (counted.isEmpty) return 0;
    return counted
            .where((r) => ['Present', 'Late'].contains(r.text('status')))
            .length /
        counted.length *
        100;
  }
}
