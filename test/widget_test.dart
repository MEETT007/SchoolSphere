import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsphere/core/storage.dart';
import 'package:schoolsphere/domain/controller.dart';
import 'package:schoolsphere/domain/models.dart';
import 'package:schoolsphere/features/management.dart';
import 'package:schoolsphere/main.dart';

void main() {
  testWidgets('Welcome opens a connected teacher workspace', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final school = SchoolController(MemorySchoolStorage());
    await school.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [schoolProvider.overrideWith((ref) => school)],
        child: SchoolSphereApp(school),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Teacher'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Teacher'));
    await tester.pumpAndSettle();
    expect(school.role, SchoolRole.teacher);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [390.0, 1440.0]) {
    for (final profile in demoUsers) {
      testWidgets('${profile.role.label} screens fit a $width viewport', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final school = SchoolController(MemorySchoolStorage());
        await school.initialize();
        school.enterDemo(profile);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [schoolProvider.overrideWith((ref) => school)],
            child: SchoolSphereApp(school),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold).last);
        final router = GoRouter.of(context);
        final paths = [
          '/home',
          '/attendance',
          '/academics',
          '/academics?tab=1',
          '/academics?tab=2',
          '/academics?tab=3',
          '/community',
          '/hub',
          ...modules.keys
              .where((m) => moduleAllowed(m, profile.role))
              .map((m) => '/module/$m'),
        ];
        for (final path in paths) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${profile.role.label} $path at $width',
          );
        }
        await school.toggleTheme();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Teacher test builder can reuse a saved question on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final school = SchoolController(MemorySchoolStorage());
    await school.initialize();
    school.enterDemo(demoUsers[2]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [schoolProvider.overrideWith((ref) => school)],
        child: SchoolSphereApp(school),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).last)).go('/academics');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create test'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Use a saved question'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Use a saved question'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('If 3x + 7').first);
    await tester.pumpAndSettle();
    expect(find.text('If 3x + 7 = 22, what is x?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Student test screen saves a selected answer and submits once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final school = SchoolController(MemorySchoolStorage());
    await school.initialize();
    school.enterDemo(demoUsers.first);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [schoolProvider.overrideWith((ref) => school)],
        child: SchoolSphereApp(school),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(
      tester.element(find.byType(Scaffold).last),
    ).go('/exam/exam-science');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    expect(school.records('attempt').single.data['answers'], {'s1': 1});
    await tester.scrollUntilVisible(
      find.text('Next question'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carbon dioxide'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Submit test'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit test').last);
    await tester.pumpAndSettle();
    expect(school.records('attempt').single.text('status'), 'Graded');
    expect(school.records('attempt').single.number('score'), 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
