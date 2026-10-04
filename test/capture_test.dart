import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsphere/core/storage.dart';
import 'package:schoolsphere/domain/controller.dart';
import 'package:schoolsphere/domain/models.dart';
import 'package:schoolsphere/main.dart';

void main() {
  testWidgets('Capture actual Flutter screens for the portfolio', (
    tester,
  ) async {
    for (final family in ['Manrope', 'Fraunces']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final school = SchoolController(
      MemorySchoolStorage(),
      clock: () => DateTime(2026, 10, 5, 9, 15),
    );
    await school.initialize();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [schoolProvider.overrideWith((ref) => school)],
        child: RepaintBoundary(key: boundary, child: SchoolSphereApp(school)),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('portfolio/screenshots').create(recursive: true);
        await File(
          'portfolio/screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('welcome');
    school.enterDemo(demoUsers.first);
    await tester.pumpAndSettle();
    await capture('student-dashboard');
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));
    router.go('/academics?tab=1');
    await capture('student-results');
    router.go('/hub');
    await capture('school-hub');
    router.go('/exam/exam-algebra');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin test'));
    await capture('taking-test');
    router.go('/home');
    school.enterDemo(demoUsers[2]);
    await tester.pumpAndSettle();
    router.go('/attendance');
    await capture('teacher-attendance');
    router.go('/home');
    school.enterDemo(demoUsers[3]);
    await tester.pumpAndSettle();
    await capture('principal-dashboard');
    tester.view.physicalSize = const Size(1440, 1000);
    await capture('principal-desktop');
    await tester.pumpWidget(const SizedBox());
  }, skip: !const bool.fromEnvironment('CAPTURE_PORTFOLIO'));
}
