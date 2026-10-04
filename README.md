# SchoolSphere

**A better school day, beautifully connected.**

A Flutter school management portfolio project by InGrowwth Innovations. A warm teal-and-cream identity, custom school illustration, bundled Manrope/Fraunces typography, responsive layouts, and five connected role experiences.

## Try the demonstration

Open the local browser preview at `http://127.0.0.1:8742` while its preview server is running. Choose Student, Parent, Teacher, Principal, or Administrator. The school, names, messages, marks, and receipts are fictional.

The Android demonstration package is in `deliverables/SchoolSphere-demo.apk` when built. It is a release-mode app signed with a development key for local review, not a Play Store release. Android installation has to be performed on your own device. The APK has been compiled; physical-device behaviour has not been verified here.

### Three connected journeys

1. Enter as **Teacher → Attendance → Grade 10-A**. Choose statuses and save. Switch to **Parent** from the account menu. Aarav's attendance journal reflects the saved entry. The parent can also switch between Aarav and Anaya.
2. Enter as **Student → Learning → Tests → Algebra checkpoint**. Answer multiple-choice and written questions, then submit. Switch to **Teacher → the same test → Review & publish**. Grade the written answer and publish. Switch to Student or Parent to see the result.
3. Enter as **Parent → School hub → Leave & approvals**, request leave, then switch to **Principal** and approve it. Return to Parent to see the decision.

Changes survive app reopening. Demo data is stored in SQLite on Android/iOS and local browser preferences in the web preview. School & account → Reset demo restores sample data. No live backend is required for the demo.

## What is implemented

| Area | Working functionality |
|---|---|
| Roles | Student, parent, teacher, principal, administrator; scoped dashboards and navigation |
| Student attendance | Per-class/date register; present, absent, late, excused; bulk present; saved history and calculated rate |
| Staff attendance | Arrival/departure check-in and principal's daily view |
| Tests | Teacher test builder; objective/written questions; saved question bank; timed single attempts; saved answers; expiry; objective grading |
| Results | Manual written-answer review; feedback; draft/published marks; student/parent results; repeated review without double counting |
| Homework | Assignment creation; due dates; student responses; late status; teacher grading/feedback; reviewed submissions lock |
| Resources | Text revision guides and secure external learning links |
| Timetable | Classes, weekday filters, periods, rooms, teachers and period creation |
| Families | Linked children; child-specific attendance, results, fees, homework and leave |
| Communication | Announcements and private participant messages; teacher/leadership recipient directory |
| Administration | Student/staff directories; staff assignments; classes/sections; admissions and enrollment; school/year/term settings |
| Fees | Fee records; partial/full offline payment recording; outstanding balance and PDF receipts |
| Leave | Staff/parent requests; date validation; principal decisions; self-approval prevention |
| Library | Book catalog; borrow/return; due dates; duplicate and copy-limit checks |
| Transport | Class routes, vehicle/driver details, stops, pickup/return times |
| Reporting | Class attendance, academic summaries and PDF exports |
| Appearance | Light/dark themes, mobile bottom navigation and desktop sidebar |

This is a functional portfolio demonstration with an optional live backend, not a claim that it covers every school's requirements. Payroll, biometric attendance, SMS, online payments, live bus GPS, attachment submission, multi-school account switching, and store distribution are not implemented.

## Tech stack

Flutter 3.47.6 / Dart 3.13.5; Material 3; Riverpod; GoRouter; Supabase/PostgreSQL; SQLite; Firebase Cloud Messaging integration; PDF/Printing; Flutter tests. Dependency versions are locked in `pubspec.lock`. Font licenses are bundled in `assets/fonts`.

## Development

Install Flutter (version recorded in `.flutter-version`), then:

```sh
flutter pub get
flutter run
```

For a browser preview without opening a browser automatically:

```sh
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8742 --bind 127.0.0.1 --directory build/web
```

For Android:

```sh
flutter build apk --release
```

For iOS, use macOS with Xcode, CocoaPods and Apple signing configured. iOS project source is included, but no iOS build was verified in this environment.

## Verification

```sh
flutter analyze
flutter test
flutter test test/capture_test.dart --dart-define=CAPTURE_PORTFOLIO=true
```

The capture test is skipped by default and generates actual Flutter-rendered screenshots when explicitly enabled. The normal tests cover connected school workflows and phone/desktop layouts for all five roles. See `docs/VERIFICATION.md` for the final results and their limits.

Disposable PostgreSQL checks:

```sh
cd supabase/tests
npm install
npm test
```

These tests use PGlite's PostgreSQL engine with small Auth/Storage compatibility shims. They compile the migration and exercise permissions, test deadlines, grading, borrowing and leave approval. They do not contact a live Supabase project.

## Connect a real school

See `docs/LIVE_SETUP.md`. When both backend configuration values are supplied, the role selector is replaced with authenticated sign-in, database policies determine access, and server functions grade tests. Live school data is not copied into the demo cache.

Firebase push registration and a server notification function are included, but require Firebase credentials and deployment before delivery can be tested. Enabling push is optional; record saves remain successful if push delivery fails.

## Portfolio assets

- `portfolio/screenshots/`: eight actual app captures.
- `portfolio/logo.svg`: original vector app mark.
- `portfolio/portfolio-entry.json`: content matching the existing InGrowwth portfolio schema.
- `portfolio/CASE_STUDY.md`: project narrative without invented client testimonials or performance claims.
- `portfolio/showcase.html`: a local presentation of the mobile screens.

The existing InGrowwth website and its database have not been modified. The prepared entry can be added through its existing portfolio admin editor after uploading the screenshots.
