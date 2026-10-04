import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

const destinations = [
  ('/home', 'Home', Icons.space_dashboard_outlined),
  ('/attendance', 'Attendance', Icons.fact_check_outlined),
  ('/academics', 'Learning', Icons.auto_stories_outlined),
  ('/community', 'Community', Icons.forum_outlined),
  ('/hub', 'School hub', Icons.grid_view_rounded),
];

class SchoolShell extends ConsumerWidget {
  const SchoolShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolProvider);
    final user = school.user;
    if (user == null) return const SizedBox.shrink();
    var index = destinations.indexWhere((d) => d.$1 == path);
    if (index < 0) index = path.startsWith('/exam') ? 2 : 4;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        automaticallyImplyLeading: false,
        title: wide
            ? Text(
                destinations[index].$2,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const Brand(),
        actions: [
          if (!school.live && wide) const Pill('DEMO WORKSPACE'),
          if (school.busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'Announcements',
            onPressed: () => context.go('/community'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            offset: const Offset(0, 46),
            onSelected: (v) async {
              if (v == 'theme') await runAction(context, school.toggleTheme);
              if (v == 'account' && context.mounted) {
                context.go('/module/settings');
              }
              if (v == 'signout' && context.mounted) {
                await runAction(context, school.signOut);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${user.name}\n${user.role.label}'),
              ),
              const PopupMenuItem(
                value: 'account',
                child: Text('School & account'),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Text(
                  school.dark ? 'Light appearance' : 'Dark appearance',
                ),
              ),
              PopupMenuItem(
                value: 'signout',
                child: Text(school.live ? 'Sign out' : 'Switch demo role'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 16, 20, 16),
              child: PersonAvatar(user.name, size: 38),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (user.role == SchoolRole.parent && school.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  const Text('Viewing ', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: school.studentId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: school.children
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.text('name')} · ${s.classId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) school.chooseChild(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 72,
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(destinations[i].$1),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.$3, size: 22),
                      label: d.$2,
                    ),
                  )
                  .toList(),
            ),
    );
    if (!wide) return content;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 236,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Brand(),
                    const SizedBox(height: 34),
                    Text(
                      school.schoolName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Pill(user.role.label),
                    const SizedBox(height: 28),
                    ...destinations.indexed.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: index == entry.$1
                              ? (isDark(context) ? teal : mint)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              entry.$2.$3,
                              size: 21,
                              color: index == entry.$1
                                  ? (isDark(context) ? Colors.white : teal)
                                  : null,
                            ),
                            title: Text(
                              entry.$2.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => context.go(entry.$2.$1),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Surface(
                      color: isDark(context) ? null : const Color(0xFFF4F5EC),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.eco_outlined, color: teal),
                          const SizedBox(height: 10),
                          const Text(
                            'Growing together.',
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'A little care makes\na big difference.',
                            style: TextStyle(fontSize: 11, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'INGROWWTH INNOVATIONS',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
