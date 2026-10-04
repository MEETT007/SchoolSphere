enum SchoolRole { student, parent, teacher, principal, administrator }

extension RoleDetails on SchoolRole {
  String get label => switch (this) {
    SchoolRole.student => 'Student',
    SchoolRole.parent => 'Parent',
    SchoolRole.teacher => 'Teacher',
    SchoolRole.principal => 'Principal',
    SchoolRole.administrator => 'Administrator',
  };
  bool get managesSchool =>
      this == SchoolRole.principal || this == SchoolRole.administrator;
  bool get teaches => this == SchoolRole.teacher || managesSchool;
}

class SchoolUser {
  const SchoolUser({
    required this.id,
    required this.name,
    required this.role,
    this.classes = const [],
    this.children = const [],
    this.schoolId = 'demo-school',
  });
  final String id, name, schoolId;
  final SchoolRole role;
  final List<String> classes, children;
  String get firstName => name.split(' ').first;
  String get initials => name.split(' ').take(2).map((s) => s[0]).join();
  factory SchoolUser.fromJson(Map<String, dynamic> json) => SchoolUser(
    id: json['user_id'],
    name: json['name'],
    schoolId: json['school_id'],
    role: SchoolRole.values.byName(json['role']),
    classes: List<String>.from(json['classes'] ?? []),
    children: List<String>.from(json['children'] ?? []),
  );
}

/// A typed envelope with an extensible payload shared by local and remote stores.
/// Class and student scope live outside the payload so the database can enforce them.
class SchoolRecord {
  const SchoolRecord({
    required this.id,
    required this.kind,
    required this.data,
    this.classId,
    this.studentId,
    this.ownerId,
    this.schoolId = 'demo-school',
  });
  final String id, kind, schoolId;
  final String? classId, studentId, ownerId;
  final Map<String, dynamic> data;
  String text(String key, [String fallback = '']) =>
      data[key]?.toString() ?? fallback;
  num number(String key, [num fallback = 0]) => (data[key] as num?) ?? fallback;
  bool flag(String key) => data[key] == true;
  List<dynamic> list(String key) => (data[key] as List?) ?? [];
  SchoolRecord copy(Map<String, dynamic> values) => SchoolRecord(
    id: id,
    kind: kind,
    data: {...data, ...values},
    classId: classId,
    studentId: studentId,
    ownerId: ownerId,
    schoolId: schoolId,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'school_id': schoolId,
    'class_id': classId,
    'student_id': studentId,
    'owner_id': ownerId,
    'data': data,
  };
  factory SchoolRecord.fromJson(Map<String, dynamic> json) => SchoolRecord(
    id: json['id'],
    kind: json['kind'],
    schoolId: json['school_id'] ?? 'demo-school',
    classId: json['class_id'],
    studentId: json['student_id'],
    ownerId: json['owner_id'],
    data: Map<String, dynamic>.from(json['data']),
  );
}

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String gradeFor(num percent) => percent >= 90
    ? 'A+'
    : percent >= 80
    ? 'A'
    : percent >= 70
    ? 'B'
    : percent >= 60
    ? 'C'
    : percent >= 40
    ? 'D'
    : 'Needs support';

const demoUsers = [
  SchoolUser(
    id: 'student-aarav',
    name: 'Aarav Shah',
    role: SchoolRole.student,
    classes: ['10-A'],
  ),
  SchoolUser(
    id: 'parent-meera',
    name: 'Meera Shah',
    role: SchoolRole.parent,
    children: ['student-aarav', 'student-anaya'],
  ),
  SchoolUser(
    id: 'teacher-kavya',
    name: 'Kavya Mehta',
    role: SchoolRole.teacher,
    classes: ['10-A', '9-B'],
  ),
  SchoolUser(
    id: 'principal-dev',
    name: 'Dev Malhotra',
    role: SchoolRole.principal,
  ),
  SchoolUser(
    id: 'admin-riya',
    name: 'Riya Patel',
    role: SchoolRole.administrator,
  ),
];
