# SchoolSphere — A better school day, beautifully connected

**Project type:** InGrowwth Innovations portfolio demonstration  
**Category:** Mobile App  
**Industry:** Education  
**Platforms:** Flutter app source for Android and iOS; responsive browser preview  
**Status:** Functional demo, with Android build and optional backend integration

## The problem

A school day spans many disconnected interactions: teachers mark attendance, students complete assignments and tests, families look for progress updates, and leaders manage records and approvals. A coherent application should keep those interactions understandable and connected.

## The approach

SchoolSphere organizes the school around five roles. Each role gets its own dashboard and authorized workflows. A teal-and-cream design, spacious cards, clear typography and an original school illustration give administrative tasks a calm, approachable feel.

## Three examples of connected behaviour

- A teacher saves class attendance; the linked parent sees the same student's attendance journal.
- A student completes a timed assessment; objective answers are graded, written answers are reviewed by a teacher, and results become visible after publication.
- A parent requests leave; the principal reviews it, and the parent sees the recorded decision.

## Engineering decisions

Flutter provides a shared application codebase and responsive layouts. Riverpod keeps state changes connected across screens, while GoRouter organizes role-specific journeys. SQLite persists fictional mobile demo data. The optional Supabase backend separates school scopes and permissions at the database layer. Server functions enforce assessment deadlines and compute objective grades; answer keys and unpublished scores are kept away from student-readable records.

## Delivered capabilities

Attendance, staff check-in, assessments and question banks, marks and report cards, homework, resources, timetables, notices and private messages, admissions and enrollment, student/staff directories, class management, leave approvals, offline fee recording, receipts, library borrowing, transport schedules, school settings, dark mode and PDF exports.

## Verification and presentation

The project includes tests for connected workflows and five-role mobile/desktop layouts, disposable PostgreSQL permission tests, actual rendered screenshots, a browser build and a compiled Android demonstration package. See the verification document for final outcomes and untested integrations.

## Honest project boundaries

All demo identities and records are fictional. This is an independently built portfolio project, not a delivered client engagement. No measured business-impact claims, real-school deployment, client endorsement or production compliance certification is asserted. Live Supabase accounts, Firebase push delivery and store publishing require external setup. Some school-specific capabilities, including payroll, biometric attendance, online payments and GPS tracking, are outside this implementation.
