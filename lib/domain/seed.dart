import 'models.dart';

List<SchoolRecord> seedSchool({DateTime? now}) {
  final today = now ?? DateTime.now();
  SchoolRecord item(
    String id,
    String kind,
    Map<String, dynamic> data, {
    String? group,
    String? student,
    String? owner,
  }) => SchoolRecord(
    id: id,
    kind: kind,
    data: data,
    classId: group,
    studentId: student,
    ownerId: owner,
  );
  final records = <SchoolRecord>[
    item('settings', 'settings', {
      'name': 'Evergreen International',
      'city': 'Ahmedabad',
      'year': '2026–27',
      'term': 'Term 1',
    }),
    for (final c in ['10-A', '9-B', '8-A'])
      item('class-$c', 'class', {
        'title': 'Grade ${c.split('-')[0]} · ${c.split('-')[1]}',
        'room': c == '10-A' ? '204' : '106',
        'teacher': 'Kavya Mehta',
      }, group: c),
    item(
      'student-aarav',
      'student',
      {
        'name': 'Aarav Shah',
        'roll': '01',
        'parent': 'Meera Shah',
        'email': 'aarav@example.test',
        'joined': '2026-04-01',
      },
      group: '10-A',
      student: 'student-aarav',
    ),
    item(
      'student-anaya',
      'student',
      {
        'name': 'Anaya Shah',
        'roll': '02',
        'parent': 'Meera Shah',
        'email': 'anaya@example.test',
        'joined': '2026-04-01',
      },
      group: '9-B',
      student: 'student-anaya',
    ),
    for (final (i, name) in [
      'Ishaan Desai',
      'Zoya Khan',
      'Vihaan Patel',
      'Sia Joshi',
      'Kabir Soni',
      'Myra Rao',
      'Reyansh Modi',
      'Aditi Sharma',
      'Arjun Nair',
      'Tara Kapoor',
    ].indexed)
      item(
        'student-${i + 3}',
        'student',
        {
          'name': name,
          'roll': '${i + 3}'.padLeft(2, '0'),
          'parent': 'Demo Guardian',
          'joined': '2026-04-01',
        },
        group: i < 7 ? '10-A' : '9-B',
        student: 'student-${i + 3}',
      ),
    item('teacher-kavya', 'staff', {
      'name': 'Kavya Mehta',
      'subject': 'Mathematics',
      'designation': 'Class teacher',
      'classes': ['10-A', '9-B'],
    }, owner: 'teacher-kavya'),
    item('teacher-rohan', 'staff', {
      'name': 'Rohan Iyer',
      'subject': 'Science',
      'designation': 'Senior teacher',
      'classes': ['10-A'],
    }, owner: 'teacher-rohan'),
    item('teacher-nisha', 'staff', {
      'name': 'Nisha Verma',
      'subject': 'English',
      'designation': 'Language teacher',
      'classes': ['9-B', '8-A'],
    }, owner: 'teacher-nisha'),
    item('principal-dev', 'staff', {
      'name': 'Dev Malhotra',
      'subject': 'Leadership',
      'designation': 'Principal',
      'classes': [],
    }, owner: 'principal-dev'),
    item(
      'exam-algebra',
      'exam',
      {
        'title': 'Algebra checkpoint',
        'subject': 'Mathematics',
        'minutes': 15,
        'published': true,
        'date': dayKey(today),
        'questions': [
          {
            'id': 'q1',
            'prompt': 'If 3x + 7 = 22, what is x?',
            'options': ['3', '5', '7', '9'],
            'points': 5,
            'type': 'mcq',
          },
          {
            'id': 'q2',
            'prompt': 'Which expression equals (a + b)²?',
            'options': ['a² + b²', 'a² + ab + b²', 'a² + 2ab + b²', '2a + 2b'],
            'points': 5,
            'type': 'mcq',
          },
          {
            'id': 'q3',
            'prompt': 'The roots of x² − 9 = 0 are…',
            'options': ['0 and 9', '3 and −3', '9 and −9', '3 only'],
            'points': 5,
            'type': 'mcq',
          },
          {
            'id': 'q4',
            'prompt':
                'Explain how you would solve 2(x + 3) = 14. Show your steps.',
            'options': [],
            'points': 5,
            'type': 'written',
          },
        ],
      },
      group: '10-A',
      owner: 'teacher-kavya',
    ),
    item(
      'exam-science',
      'exam',
      {
        'title': 'Our living world',
        'subject': 'Science',
        'minutes': 10,
        'published': true,
        'date': dayKey(today),
        'questions': [
          {
            'id': 's1',
            'prompt': 'Which organelle performs photosynthesis?',
            'options': ['Nucleus', 'Chloroplast', 'Mitochondrion', 'Ribosome'],
            'points': 5,
            'type': 'mcq',
          },
          {
            'id': 's2',
            'prompt': 'Which gas do plants absorb during photosynthesis?',
            'options': ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'],
            'points': 5,
            'type': 'mcq',
          },
        ],
      },
      group: '10-A',
      owner: 'teacher-rohan',
    ),
    item(
      'marks-math-aarav',
      'mark',
      {
        'subject': 'Mathematics',
        'assessment': 'Term 1 assessment',
        'score': 87,
        'max': 100,
        'published': true,
        'feedback': 'Strong reasoning. Keep practising quadratic equations.',
      },
      group: '10-A',
      student: 'student-aarav',
    ),
    item(
      'marks-science-aarav',
      'mark',
      {
        'subject': 'Science',
        'assessment': 'Term 1 assessment',
        'score': 92,
        'max': 100,
        'published': true,
        'feedback': 'Excellent understanding of scientific concepts.',
      },
      group: '10-A',
      student: 'student-aarav',
    ),
    item(
      'marks-english-aarav',
      'mark',
      {
        'subject': 'English',
        'assessment': 'Term 1 assessment',
        'score': 81,
        'max': 100,
        'published': true,
        'feedback': 'Thoughtful writing. Work on grammar accuracy.',
      },
      group: '10-A',
      student: 'student-aarav',
    ),
    item(
      'marks-english-anaya',
      'mark',
      {
        'subject': 'English',
        'assessment': 'Term 1 assessment',
        'score': 89,
        'max': 100,
        'published': true,
      },
      group: '9-B',
      student: 'student-anaya',
    ),
    item(
      'hw-algebra',
      'homework',
      {
        'title': 'Quadratic equations · Practice set',
        'subject': 'Mathematics',
        'description':
            'Solve questions 1–8 from exercise 4.2. Include your reasoning for each answer.',
        'due': dayKey(today.add(const Duration(days: 2))),
        'points': 10,
      },
      group: '10-A',
      owner: 'teacher-kavya',
    ),
    item(
      'hw-science',
      'homework',
      {
        'title': 'Explore a local ecosystem',
        'subject': 'Science',
        'description':
            'Describe a nearby ecosystem, identify three producers and consumers, and draw a food chain.',
        'due': dayKey(today.add(const Duration(days: 4))),
        'points': 20,
      },
      group: '10-A',
      owner: 'teacher-rohan',
    ),
    item('notice-festival', 'notice', {
      'title': 'A little curiosity goes a long way.',
      'body':
          'Our annual Science & Innovation Fair is coming up. Bring your ideas, prototypes, and questions. Families are welcome!',
      'category': 'Campus life',
      'date': dayKey(today.add(const Duration(days: 5))),
      'author': 'Principal’s office',
      'pinned': true,
    }),
    item('notice-meeting', 'notice', {
      'title': 'Parent–teacher conversations',
      'body':
          'Join us this Saturday, 9:00–12:00, to discuss your child’s progress and goals for the next term.',
      'category': 'Families',
      'date': dayKey(today.add(const Duration(days: 6))),
      'author': 'Academic office',
    }),
    item('notice-library', 'notice', {
      'title': 'Your next adventure is on a shelf',
      'body':
          'The library has 24 new titles in science, fiction, and history. Visit during lunch break.',
      'category': 'Library',
      'date': dayKey(today),
      'author': 'Library team',
    }),
    item(
      'fee-aarav',
      'fee',
      {
        'title': 'Term 2 tuition',
        'amount': 18500,
        'paid': 0,
        'due': dayKey(today.add(const Duration(days: 15))),
        'status': 'Due',
      },
      student: 'student-aarav',
      group: '10-A',
    ),
    item(
      'fee-anaya',
      'fee',
      {
        'title': 'Term 2 tuition',
        'amount': 16500,
        'paid': 16500,
        'due': dayKey(today),
        'status': 'Paid',
        'receipt': 'SS-2026-0012',
      },
      student: 'student-anaya',
      group: '9-B',
    ),
    item('leave-1', 'leave', {
      'name': 'Rohan Iyer',
      'reason': 'Professional development workshop',
      'from': dayKey(today.add(const Duration(days: 2))),
      'to': dayKey(today.add(const Duration(days: 2))),
      'status': 'Pending',
      'type': 'Staff',
    }, owner: 'teacher-rohan'),
    item(
      'leave-2',
      'leave',
      {
        'name': 'Aarav Shah',
        'reason': 'Family appointment',
        'from': dayKey(today.add(const Duration(days: 3))),
        'to': dayKey(today.add(const Duration(days: 3))),
        'status': 'Pending',
        'type': 'Student',
      },
      student: 'student-aarav',
      group: '10-A',
      owner: 'parent-meera',
    ),
    item('book-1', 'book', {
      'title': 'A Brief History of Time',
      'author': 'Stephen Hawking',
      'category': 'Science',
      'copies': 4,
    }),
    item('book-2', 'book', {
      'title': 'The Blue Umbrella',
      'author': 'Ruskin Bond',
      'category': 'Fiction',
      'copies': 6,
    }),
    item('book-3', 'book', {
      'title': 'The Story of My Experiments with Truth',
      'author': 'M. K. Gandhi',
      'category': 'Biography',
      'copies': 3,
    }),
    item('route-1', 'transport', {
      'title': 'Route 04 · West Ahmedabad',
      'driver': 'Sanjay Patel',
      'bus': 'GJ-01-SS-204',
      'stops': 'Satellite 07:10 · Vastrapur 07:25 · School 07:45',
      'return': 'School departure 15:15',
      'contact': 'Contact the school transport desk',
    }, group: '10-A'),
    item('admission-1', 'admission', {
      'name': 'Avni Trivedi',
      'grade': '8-A',
      'parent': 'Nirali Trivedi',
      'email': 'nirali@example.test',
      'status': 'New',
      'date': dayKey(today),
    }),
    item(
      'resource-1',
      'resource',
      {
        'title': 'Algebra revision guide',
        'subject': 'Mathematics',
        'body':
            'Key identities: (a+b)² = a²+2ab+b²; (a−b)² = a²−2ab+b²; a²−b² = (a+b)(a−b). Practise one worked example for each identity.',
      },
      group: '10-A',
      owner: 'teacher-kavya',
    ),
    item('message-1', 'message', {
      'body':
          'Aarav is doing well in mathematics. Please encourage him to show each step in his written solutions.',
      'sender': 'Kavya Mehta',
      'recipient': 'Meera Shah',
      'recipients': ['parent-meera', 'teacher-kavya'],
      'sent': today.subtract(const Duration(hours: 3)).toIso8601String(),
    }, owner: 'teacher-kavya'),
  ];
  for (final student in records.where((r) => r.kind == 'student').toList()) {
    for (var offset = 1; offset <= 14; offset++) {
      final date = today.subtract(Duration(days: offset));
      if (date.weekday > 5) continue;
      records.add(
        item(
          'att-${student.id}-${dayKey(date)}',
          'attendance',
          {
            'date': dayKey(date),
            'status': offset == 7 && student.id == 'student-aarav'
                ? 'Absent'
                : 'Present',
            'name': student.text('name'),
          },
          student: student.id,
          group: student.classId,
          owner: 'teacher-kavya',
        ),
      );
    }
  }
  for (final (i, subject) in [
    'Mathematics',
    'Science',
    'English',
    'Social studies',
    'Computer science',
  ].indexed) {
    for (final c in ['10-A', '9-B']) {
      records.add(
        item('schedule-$c-$i', 'schedule', {
          'subject': subject,
          'time': [
            '08:15–09:00',
            '09:05–09:50',
            '10:10–10:55',
            '11:00–11:45',
            '12:30–13:15',
          ][i],
          'teacher': [
            'Kavya Mehta',
            'Rohan Iyer',
            'Nisha Verma',
            'Kavya Mehta',
            'Rohan Iyer',
          ][i],
          'room': c == '10-A' ? '204' : '106',
          'days': [1, 2, 3, 4, 5],
          'order': i,
        }, group: c),
      );
    }
  }
  for (final exam in records.where((r) => r.kind == 'exam').toList()) {
    for (final raw in exam.list('questions')) {
      final q = Map<String, dynamic>.from(raw);
      records.add(
        item(
          'bank-${exam.id}-${q['id']}',
          'question',
          {
            ...q,
            'subject': exam.text('subject'),
            'correct': demoAnswerKeys[exam.id]?[q['id']],
          },
          group: exam.classId,
          owner: exam.ownerId,
        ),
      );
    }
  }
  return records;
}

const demoAnswerKeys = <String, Map<String, int>>{
  'exam-algebra': {'q1': 1, 'q2': 2, 'q3': 1},
  'exam-science': {'s1': 1, 's2': 2},
};
