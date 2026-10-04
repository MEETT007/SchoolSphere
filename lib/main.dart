import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/backend.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'domain/controller.dart';
import 'features/shell.dart';
import 'features/dashboard.dart';
import 'features/attendance.dart';
import 'features/academics.dart';
import 'features/exams.dart';
import 'features/community.dart';
import 'features/management.dart';
import 'features/welcome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (SchoolBackend.url.isEmpty != SchoolBackend.publicKey.isEmpty) {
      throw StateError(
        'Supply both the Supabase URL and public key for a connected school.',
      );
    }
    SchoolBackend? backend;
    if (SchoolBackend.configured) {
      await Supabase.initialize(
        url: SchoolBackend.url,
        publishableKey: SchoolBackend.publicKey,
      );
      backend = SchoolBackend(Supabase.instance.client);
    }
    final controller = SchoolController(LocalSchoolStorage(), backend: backend);
    await controller.initialize();
    runApp(
      ProviderScope(
        overrides: [schoolProvider.overrideWith((ref) => controller)],
        child: SchoolSphereApp(controller),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        theme: schoolTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Brand(),
                  const SizedBox(height: 24),
                  const Text(
                    'We couldn’t open your school.',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'Check the connection or device storage, then reopen the app.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SchoolSphereApp extends ConsumerStatefulWidget {
  const SchoolSphereApp(this.controller, {super.key});
  final SchoolController controller;
  @override
  ConsumerState<SchoolSphereApp> createState() => _SchoolSphereAppState();
}

class _SchoolSphereAppState extends ConsumerState<SchoolSphereApp> {
  late final router = GoRouter(
    initialLocation: '/',
    refreshListenable: widget.controller,
    redirect: (context, state) {
      final signedIn = widget.controller.user != null;
      if (!signedIn && state.uri.path != '/') return '/';
      if (signedIn && state.uri.path == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomePage()),
      ShellRoute(
        builder: (context, state, child) =>
            SchoolShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: '/attendance',
            builder: (_, _) => const AttendancePage(),
          ),
          GoRoute(
            path: '/academics',
            builder: (_, state) => AcademicsPage(
              initialTab:
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/exam/:id',
            builder: (_, state) =>
                ExamPage(examId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/community', builder: (_, _) => const CommunityPage()),
          GoRoute(path: '/hub', builder: (_, _) => const HubPage()),
          GoRoute(
            path: '/module/:name',
            builder: (_, state) =>
                ManagementPage(module: state.pathParameters['name']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Return to school'),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider);
    return MaterialApp.router(
      title: 'SchoolSphere · A better school day',
      debugShowCheckedModeBanner: false,
      theme: schoolTheme(),
      darkTheme: schoolTheme(dark: true),
      themeMode: school.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
