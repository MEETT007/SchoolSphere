import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolProvider);
    final user = school.user!;
    final attendance = school.records('attendance');
    final marks = school
        .records('mark')
        .where((r) => r.flag('published'))
        .toList();
    final exams = school.records('exam');
    final notices = school.records('notice');
    final pending = school
        .records('leave')
        .where((r) => r.text('status') == 'Pending')
        .length;
    final teacher = user.role.teaches;
    final average = marks.isEmpty
        ? 0
        : marks.fold<double>(
                0,
                (s, r) => s + r.number('score') / r.number('max') * 100,
              ) /
              marks.length;
    final greeting = school.clock().hour < 12
        ? 'Good morning'
        : school.clock().hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final stats = teacher
        ? [
            StatCard(
              label: user.role.managesSchool
                  ? 'Enrolled students'
                  : 'Your students',
              value: '${school.records('student').length}',
              icon: Icons.groups_outlined,
              note: 'Across ${school.accessibleClasses.length} classes',
            ),
            StatCard(
              label: 'Attendance',
              value: '${school.attendanceRate(attendance).toStringAsFixed(0)}%',
              icon: Icons.fact_check_outlined,
              note: '${attendance.length} recorded entries',
            ),
            StatCard(
              label: 'Active assessments',
              value: '${exams.length}',
              icon: Icons.quiz_outlined,
              color: clay,
              note: 'Ready for learning',
            ),
            StatCard(
              label: 'Leave requests',
              value: '$pending',
              icon: Icons.event_available_outlined,
              color: const Color(0xFFA16A1C),
              note: 'Awaiting a decision',
            ),
          ]
        : [
            StatCard(
              label: 'Attendance',
              value: '${school.attendanceRate(attendance).toStringAsFixed(0)}%',
              icon: Icons.fact_check_outlined,
              note: '${attendance.length} recorded school days',
            ),
            StatCard(
              label: 'Average marks',
              value: marks.isEmpty ? '—' : '${average.toStringAsFixed(0)}%',
              icon: Icons.insights_outlined,
              note: '${marks.length} published subject results',
            ),
            StatCard(
              label: 'Available tests',
              value: '${exams.length}',
              icon: Icons.quiz_outlined,
              color: clay,
              note: 'Explore your next challenge',
            ),
            StatCard(
              label: 'Assignments',
              value: '${school.records('homework').length}',
              icon: Icons.edit_note_rounded,
              color: const Color(0xFFA16A1C),
              note: 'Practice makes progress',
            ),
          ];
    return PageBody(
      onRefresh: school.refresh,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat(
                  'EEEE, d MMMM yyyy',
                ).format(school.clock()).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 450)
              Pill(
                'ACADEMIC YEAR ${school.records('settings').firstOrNull?.text('year') ?? '—'}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$greeting, ${user.firstName}.',
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 33,
            letterSpacing: -.9,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.role == SchoolRole.parent
              ? 'A little closer to ${school.studentName.split(' ').first}’s school day.'
              : teacher
              ? 'Here’s what’s happening in your school today.'
              : 'A new day to learn something wonderful.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 25),
        Surface(
          color: isDark(context)
              ? const Color(0xFF21483F)
              : const Color(0xFFE8EFE0),
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Pill('EVERY DAY COUNTS'),
                      const SizedBox(height: 14),
                      Text(
                        teacher
                            ? 'Be the reason\nsomeone loves learning.'
                            : 'Your next big idea\nstarts right here.',
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 27,
                          height: 1.15,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        teacher
                            ? 'Start with a check-in. Make every student feel seen.'
                            : 'A small step today. A brighter possibility tomorrow.',
                        style: const TextStyle(fontSize: 11, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () =>
                            context.go(teacher ? '/attendance' : '/academics'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text(
                          teacher ? 'Take attendance' : 'Explore learning',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (box.maxWidth > 520) const CampusArt(height: 190),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ResponsiveGrid(
          minWidth: MediaQuery.sizeOf(context).width < 600 ? 140 : 210,
          gap: 12,
          children: stats,
        ),
        SectionHeading(
          'Your day, at a glance',
          subtitle: 'Everything you need, a little closer.',
          action: TextButton(
            onPressed: () => context.go('/hub'),
            child: const Text('View all', style: TextStyle(fontSize: 11)),
          ),
        ),
        ResponsiveGrid(
          minWidth: 145,
          children: [
            _QuickAction(
              'Timetable',
              'Make room for learning',
              Icons.calendar_view_day_outlined,
              '/module/timetable',
              teal,
            ),
            _QuickAction(
              teacher ? 'Review results' : 'My results',
              'See progress take shape',
              Icons.bar_chart_rounded,
              '/academics?tab=1',
              clay,
            ),
            _QuickAction(
              teacher ? 'Leave & approvals' : 'Fees & receipts',
              teacher ? 'Support your people' : 'Everything accounted for',
              Icons.task_alt_rounded,
              teacher ? '/module/leave' : '/module/fees',
              const Color(0xFF887BA2),
            ),
          ],
        ),
        SectionHeading(
          'On the noticeboard',
          subtitle: 'The moments that bring us together.',
          action: TextButton(
            onPressed: () => context.go('/community'),
            child: const Text('See all', style: TextStyle(fontSize: 11)),
          ),
        ),
        if (notices.isEmpty)
          const EmptyState(
            'A quiet noticeboard',
            'School announcements will appear here.',
          )
        else
          ResponsiveGrid(
            minWidth: 300,
            children: notices
                .take(2)
                .map(
                  (n) => Surface(
                    onTap: () => context.go('/community'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Pill(n.text('category'), color: clay),
                            const Spacer(),
                            Text(
                              niceDate(n.text('date')),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        Text(
                          n.text('title'),
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 22,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          n.text('body'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(
                              Icons.campaign_outlined,
                              size: 16,
                              color: teal,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                n.text('author'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_outward,
                              size: 16,
                              color: teal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 26),
        Center(
          child: Text(
            'A better school day, together.',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
    this.title,
    this.subtitle,
    this.icon,
    this.path,
    this.color,
  );
  final String title, subtitle, path;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Surface(
    onTap: () => context.go(path),
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
