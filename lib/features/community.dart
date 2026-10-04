import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});
  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  bool messages = false;
  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider);
    final notices = school.records('notice');
    final threads = school.records('message')
      ..sort((a, b) => b.text('sent').compareTo(a.text('sent')));
    return PageBody(
      onRefresh: school.refresh,
      children: [
        const SectionHeading(
          'A school is its people.',
          subtitle: 'Good conversations. Shared moments. Stronger connections.',
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Noticeboard'),
              icon: Icon(Icons.campaign_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Messages'),
              icon: Icon(Icons.forum_outlined),
            ),
          ],
          selected: {messages},
          onSelectionChanged: (s) => setState(() => messages = s.first),
        ),
        if (!messages) ...[
          SectionHeading(
            'What’s happening',
            action: school.role.teaches
                ? IconButton(
                    tooltip: 'Post announcement',
                    onPressed: school.busy
                        ? null
                        : () => _announce(context, school),
                    icon: const Icon(Icons.add_circle_outline),
                  )
                : null,
          ),
          if (notices.isEmpty)
            const EmptyState(
              'The noticeboard is ready',
              'Your school’s next announcement will appear here.',
            )
          else
            ...notices.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Pill(n.text('category'), color: clay),
                          const Spacer(),
                          if (n.flag('pinned'))
                            const Icon(
                              Icons.push_pin_outlined,
                              size: 16,
                              color: teal,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            niceDate(n.text('date')),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        n.text('title'),
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 27,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        n.text('body'),
                        style: const TextStyle(fontSize: 13, height: 1.8),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_stories_outlined,
                            color: teal,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              n.text('author'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (n.classId != null) Pill(n.classId!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ] else ...[
          SectionHeading(
            'Keep the conversation going',
            subtitle: 'Messages are private to their participants.',
            action: IconButton(
              tooltip: 'New message',
              onPressed: school.busy ? null : () => _compose(context, school),
              icon: const Icon(Icons.edit_square),
            ),
          ),
          if (threads.isEmpty)
            const EmptyState(
              'Say hello',
              'Connect with a teacher or your school office.',
            )
          else
            ...threads.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PersonAvatar(m.text('sender')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.text('sender'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'To ${m.text('recipient')}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat(
                              'd MMM · HH:mm',
                            ).format(DateTime.parse(m.text('sent'))),
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        m.text('body'),
                        style: const TextStyle(fontSize: 13, height: 1.8),
                      ),
                      if (m.ownerId != school.user!.id)
                        TextButton.icon(
                          onPressed: () => _reply(context, school, m),
                          icon: const Icon(Icons.reply, size: 17),
                          label: const Text('Reply'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _announce(BuildContext context, SchoolController school) async {
    final groups = [
      if (school.role.managesSchool) 'Whole school',
      ...school.accessibleClasses,
    ];
    if (groups.isEmpty) return;
    final v = await schoolForm(context, 'A moment to share', [
      const FormFieldSpec('title', 'Announcement title'),
      const FormFieldSpec('body', 'Message', lines: 5),
      const FormFieldSpec(
        'category',
        'Category',
        options: ['Campus life', 'Academics', 'Families', 'Sports', 'Library'],
      ),
      FormFieldSpec('audience', 'Audience', options: groups),
      FormFieldSpec(
        'date',
        'Event date',
        date: true,
        value: dayKey(school.clock()),
      ),
    ], button: 'Post announcement');
    if (v != null && context.mounted) {
      await runAction(
        context,
        () => school.addRecord('notice', {
          'title': v['title'],
          'body': v['body'],
          'category': v['category'],
          'date': v['date'],
          'author': school.user!.name,
        }, group: v['audience'] == 'Whole school' ? null : v['audience']),
        'Announcement posted.',
      );
    }
  }

  Future<void> _compose(BuildContext context, SchoolController school) async {
    List<Map<String, dynamic>> contacts;
    if (school.live) {
      contacts = [];
      final ok = await runAction(context, () async {
        final rows = await school.backend!.client.rpc('contact_directory');
        contacts = List<Map<String, dynamic>>.from(
          (rows as List).map((r) => Map<String, dynamic>.from(r)),
        );
      });
      if (!ok || !context.mounted) return;
    } else {
      contacts = demoUsers
          .where(
            (u) =>
                u.id != school.user!.id &&
                (school.role.teaches || u.role.teaches),
          )
          .map((u) => {'id': u.id, 'name': u.name, 'role': u.role.label})
          .toList();
    }
    if (contacts.isEmpty) {
      if (context.mounted) {
        await runAction(
          context,
          () async => throw StateError('No contacts are available yet.'),
        );
      }
      return;
    }
    final labels = {for (final c in contacts) '${c['name']} · ${c['role']}': c};
    if (!context.mounted) return;
    final v = await schoolForm(context, 'Start a conversation', [
      FormFieldSpec('recipient', 'To', options: labels.keys.toList()),
      const FormFieldSpec('body', 'Your message', lines: 5),
    ], button: 'Send message');
    if (v != null && context.mounted) {
      final contact = labels[v['recipient']]!;
      await runAction(
        context,
        () => school.sendMessage(contact['id'], contact['name'], v['body']!),
        'Message sent.',
      );
    }
  }

  Future<void> _reply(
    BuildContext context,
    SchoolController school,
    SchoolRecord message,
  ) async {
    final recipient = message
        .list('recipients')
        .where((id) => id != school.user!.id)
        .first;
    final v = await schoolForm(context, 'Reply to ${message.text('sender')}', [
      const FormFieldSpec('body', 'Your message', lines: 5),
    ], button: 'Send reply');
    if (v != null && context.mounted) {
      await runAction(
        context,
        () => school.sendMessage(recipient, message.text('sender'), v['body']!),
        'Reply sent.',
      );
    }
  }
}
