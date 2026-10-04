import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsphere/core/storage.dart';
import 'package:schoolsphere/domain/controller.dart';
import 'package:schoolsphere/domain/models.dart';

class FailingStorage extends MemorySchoolStorage {
  bool fail = false;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('Disk unavailable');
    await super.write(value);
  }
}

void main() {
  late SchoolController school;
  late DateTime now;
  late MemorySchoolStorage storage;
  setUp(() async {
    now = DateTime(2026, 10, 5, 8);
    storage = MemorySchoolStorage();
    school = SchoolController(storage, clock: () => now);
    await school.initialize();
    school.enterDemo(demoUsers[2]);
  });
  test('Attendance saved by teacher appears for linked parent only', () async {
    await school.saveAttendance('10-A', now, {
      'student-aarav': 'Absent',
      'student-3': 'Present',
    });
    school.enterDemo(demoUsers[1]);
    expect(
      school
          .records('attendance')
          .where((r) => r.text('date') == dayKey(now))
          .single
          .text('status'),
      'Absent',
    );
    expect(
      school.records('attendance').every((r) => r.studentId == 'student-aarav'),
      isTrue,
    );
    school.chooseChild('student-anaya');
    expect(
      school.records('attendance').every((r) => r.studentId == 'student-anaya'),
      isTrue,
    );
    expect(() => school.chooseChild('student-3'), throwsStateError);
  });
  test('Teacher cannot write another class or future attendance', () async {
    await expectLater(
      school.saveAttendance('8-A', now, {'student-aarav': 'Present'}),
      throwsStateError,
    );
    await expectLater(
      school.saveAttendance('10-A', now.add(const Duration(days: 1)), {
        'student-aarav': 'Present',
      }),
      throwsStateError,
    );
    await expectLater(
      school.saveAttendance('10-A', now, {'student-anaya': 'Present'}),
      throwsStateError,
    );
  });
  test('Attendance excludes excused days and includes late arrivals', () {
    final values = ['Present', 'Late', 'Absent', 'Excused'];
    final rows = values
        .map(
          (v) => SchoolRecord(id: v, kind: 'attendance', data: {'status': v}),
        )
        .toList();
    expect(school.attendanceRate(rows), closeTo(200 / 3, .001));
    expect(school.attendanceRate([]), 0);
  });
  test('Students cannot alter marks, fees, directory or approvals', () async {
    school.enterDemo(demoUsers.first);
    await expectLater(
      school.saveMark('student-aarav', 'Science', 'Term', 100, 100, '', true),
      throwsStateError,
    );
    await expectLater(
      school.addRecord('student', {'name': 'Fake'}, group: '10-A'),
      throwsStateError,
    );
    await expectLater(
      school.recordPayment(school.records('fee').first, 10),
      throwsStateError,
    );
    expect(school.records('admission'), isEmpty);
  });
  test('Draft marks stay hidden until published', () async {
    await school.saveMark(
      'student-aarav',
      'Computer science',
      'Quiz',
      8,
      10,
      'Great work',
      false,
    );
    school.enterDemo(demoUsers.first);
    expect(
      school
          .records('mark')
          .any((m) => m.text('subject') == 'Computer science'),
      isFalse,
    );
    school.enterDemo(demoUsers[2]);
    await school.saveMark(
      'student-aarav',
      'Computer science',
      'Quiz',
      8,
      10,
      'Great work',
      true,
    );
    school.enterDemo(demoUsers[1]);
    expect(
      school
          .records('mark')
          .firstWhere((m) => m.text('subject') == 'Computer science')
          .number('score'),
      8,
    );
  });
  test('A test allows one attempt and grades objective answers once', () async {
    school.enterDemo(demoUsers.first);
    final exam = school.byId('exam-algebra')!;
    expect(exam.data.containsKey('keys'), isFalse);
    final first = await school.startExam(exam);
    final second = await school.startExam(exam);
    expect(first.id, second.id);
    final answers = {
      'q1': 1,
      'q2': 2,
      'q3': 1,
      'q4': 'Subtract 6, divide by 2, x=4.',
    };
    await school.submitExam(exam, answers);
    await school.submitExam(exam, answers);
    final attempt = school.records('attempt').single;
    expect(attempt.number('score'), 15);
    expect(attempt.number('max'), 20);
    expect(attempt.text('status'), 'Awaiting review');
    expect(attempt.flag('published'), isFalse);
    await expectLater(school.saveAnswers(exam, answers), throwsStateError);
  });
  test(
    'Written grading validates maximum and avoids double counting on re-review',
    () async {
      school.enterDemo(demoUsers.first);
      final exam = school.byId('exam-algebra')!;
      await school.startExam(exam);
      await school.submitExam(exam, {'q1': 1, 'q2': 2, 'q3': 1, 'q4': 'x = 4'});
      school.enterDemo(demoUsers[2]);
      final attempt = school.records('attempt').single;
      await expectLater(
        school.reviewAttempt(attempt, {'q4': 6}, 'Good', publish: true),
        throwsStateError,
      );
      await school.reviewAttempt(attempt, {'q4': 4}, 'Good', publish: false);
      await school.reviewAttempt(
        school.records('attempt').single,
        {'q4': 5},
        'Excellent',
        publish: true,
      );
      expect(school.records('attempt').single.number('score'), 20);
      school.enterDemo(demoUsers[1]);
      expect(school.records('attempt').single.flag('published'), isTrue);
    },
  );
  test(
    'Expired tests grade the last saved answers, not changed late answers',
    () async {
      school.enterDemo(demoUsers.first);
      final exam = school.byId('exam-science')!;
      await school.startExam(exam);
      await school.saveAnswers(exam, {'s1': 0});
      now = now.add(const Duration(minutes: 11));
      await school.submitExam(exam, {'s1': 1, 's2': 2});
      expect(school.records('attempt').single.number('score'), 0);
      expect(school.records('attempt').single.data['answers'], {'s1': 0});
    },
  );
  test('Teachers can create an assessment with private answer keys', () async {
    await school.createExam(
      'New quiz',
      'Math',
      '10-A',
      10,
      [
        {
          'id': 'q1',
          'prompt': '2+2?',
          'points': 4,
          'type': 'mcq',
          'options': ['3', '4'],
        },
      ],
      {'q1': 1},
    );
    final exam = school.records('exam').last;
    expect(exam.data.containsKey('keys'), isFalse);
    school.enterDemo(demoUsers.first);
    await school.startExam(exam);
    await school.submitExam(exam, {'q1': 1});
    expect(school.records('attempt').single.number('score'), 4);
  });
  test(
    'Homework feedback connects teacher to student and locks reviewed work',
    () async {
      school.enterDemo(demoUsers.first);
      final hw = school.byId('hw-algebra')!;
      await school.submitHomework(hw, 'Here is my worked solution.');
      school.enterDemo(demoUsers[2]);
      await school.reviewHomework(
        school.records('submission').single,
        8,
        'Show your working more clearly.',
      );
      school.enterDemo(demoUsers.first);
      expect(school.records('submission').single.number('score'), 8);
      await expectLater(
        school.submitHomework(hw, 'Changed answer'),
        throwsStateError,
      );
    },
  );
  test(
    'Principal approval is visible to parent and cannot be repeated',
    () async {
      school.enterDemo(demoUsers[3]);
      final leave = school.byId('leave-2')!;
      await school.decideLeave(leave, true);
      await expectLater(
        school.decideLeave(school.byId('leave-2')!, false),
        throwsStateError,
      );
      school.enterDemo(demoUsers[1]);
      expect(school.records('leave').single.text('status'), 'Approved');
    },
  );
  test(
    'Partial payments enforce outstanding balance and remain visible to parents',
    () async {
      school.enterDemo(demoUsers[4]);
      await school.recordPayment(school.byId('fee-aarav')!, 5000);
      await expectLater(
        school.recordPayment(school.byId('fee-aarav')!, 14000),
        throwsStateError,
      );
      school.enterDemo(demoUsers[1]);
      expect(school.records('fee').single.number('paid'), 5000);
      expect(school.records('fee').single.text('status'), 'Part paid');
    },
  );
  test(
    'Library blocks duplicate loans and permits a returned copy to be borrowed',
    () async {
      school.enterDemo(demoUsers.first);
      final book = school.byId('book-1')!;
      await school.borrowBook(book);
      await expectLater(school.borrowBook(book), throwsStateError);
      await school.returnBook(school.records('borrow').single);
      now = now.add(const Duration(seconds: 1));
      await school.borrowBook(book);
      expect(
        school
            .records('borrow')
            .where((r) => r.text('status') == 'Borrowed')
            .length,
        1,
      );
    },
  );
  test('Enrollment is atomic and cannot enroll an application twice', () async {
    school.enterDemo(demoUsers[4]);
    final a = school.byId('admission-1')!;
    await school.enrollAdmission(a);
    expect(
      school
          .records('student')
          .where((s) => s.text('name') == 'Avni Trivedi')
          .length,
      1,
    );
    expect(school.byId(a.id)!.text('status'), 'Enrolled');
    await expectLater(
      school.enrollAdmission(school.byId(a.id)!),
      throwsStateError,
    );
  });
  test('Saved demo survives reopening the app', () async {
    await school.saveAttendance('10-A', now, {'student-aarav': 'Late'});
    final reopened = SchoolController(storage, clock: () => now);
    await reopened.initialize();
    reopened.enterDemo(demoUsers.first);
    expect(
      reopened
          .records('attendance')
          .where((r) => r.text('date') == dayKey(now))
          .single
          .text('status'),
      'Late',
    );
  });
  test('Failed writes leave the previous register intact', () async {
    final disk = FailingStorage();
    final controller = SchoolController(disk, clock: () => now);
    await controller.initialize();
    controller.enterDemo(demoUsers[2]);
    disk.fail = true;
    await expectLater(
      controller.saveAttendance('10-A', now, {'student-aarav': 'Absent'}),
      throwsStateError,
    );
    expect(
      controller
          .records('attendance')
          .where((r) => r.text('date') == dayKey(now)),
      isEmpty,
    );
    expect(controller.busy, isFalse);
  });
  test(
    'Reusable question bank remains hidden from students and parents',
    () async {
      await school.createExam(
        'Reusable quiz',
        'Math',
        '10-A',
        10,
        [
          {
            'id': 'q1',
            'prompt': '2+2?',
            'points': 4,
            'type': 'mcq',
            'options': ['3', '4'],
          },
        ],
        {'q1': 1},
        saveToBank: true,
      );
      expect(
        school
            .records('question')
            .any((q) => q.text('prompt') == '2+2?' && q.number('correct') == 1),
        isTrue,
      );
      school.enterDemo(demoUsers.first);
      expect(school.records('question'), isEmpty);
      school.enterDemo(demoUsers[1]);
      expect(school.records('question'), isEmpty);
    },
  );
  test(
    'Principal staff assignments change teacher access on the next role switch',
    () async {
      school.enterDemo(demoUsers[3]);
      await school.updateAdministrative(school.byId('teacher-kavya')!, {
        'classes': ['8-A'],
      });
      school.enterDemo(demoUsers[2]);
      expect(school.accessibleClasses, ['8-A']);
      await expectLater(
        school.saveAttendance('10-A', now, {'student-aarav': 'Present'}),
        throwsStateError,
      );
    },
  );
  test('Leadership cannot read conversations they did not participate in', () {
    school.enterDemo(demoUsers[3]);
    expect(school.records('message'), isEmpty);
  });
}
