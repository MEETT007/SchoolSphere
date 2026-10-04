import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme.dart';

String niceDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat('d MMM').format(date);
}

String money(num value) =>
    '₹${NumberFormat('#,##,##0', 'en_IN').format(value)}';
bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false, this.light = false});
  final bool compact, light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: .15) : teal,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.auto_stories_rounded,
          color: Colors.white,
          size: 23,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'schoolsphere',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              letterSpacing: -.8,
              color: light ? Colors.white : null,
            ),
          ),
        ),
      ],
    ],
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: isDark(context)
            ? const Color(0xFF2A403B)
            : const Color(0xFFE7EBE2),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = teal});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: isDark(context) ? Color.lerp(color, Colors.white, .35) : color,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Color statusColor(String text) =>
    ['Absent', 'Declined', 'Overdue'].contains(text)
    ? clay
    : [
        'Pending',
        'Late',
        'Due',
        'In progress',
        'Awaiting review',
      ].contains(text)
    ? const Color(0xFFA16A1C)
    : teal;

class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.name, {super.key, this.size = 42, this.color = teal});
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(size * .33),
    ),
    child: Text(
      name
          .split(' ')
          .where((s) => s.isNotEmpty)
          .take(2)
          .map((s) => s[0])
          .join(),
      style: TextStyle(
        color: isDark(context) ? mint : color,
        fontWeight: FontWeight.w800,
        fontSize: size / 3,
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        10,
        MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
    return onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minWidth = 250,
    this.gap = 14,
  });
  final List<Widget> children;
  final double minWidth, gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = ((constraints.maxWidth + gap) / (minWidth + gap))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - gap * (count - 1)) / count;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map((w) => SizedBox(width: width, child: w))
            .toList(),
      );
    },
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.note,
    this.color = teal,
  });
  final String label, value;
  final IconData icon;
  final String? note;
  final Color color;
  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const Spacer(),
            Icon(
              Icons.north_east,
              size: 15,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            note!,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Surface(
      child: Column(
        children: [
          const SizedBox(height: 18),
          Icon(icon, color: teal, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 18),
        ],
      ),
    ),
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, [
  String? success,
]) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), behavior: SnackBarBehavior.floating),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: clay,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

class FormFieldSpec {
  const FormFieldSpec(
    this.key,
    this.label, {
    this.value = '',
    this.options,
    this.lines = 1,
    this.number = false,
    this.optional = false,
    this.date = false,
    this.readOnly = false,
  });
  final String key, label, value;
  final List<String>? options;
  final int lines;
  final bool number, optional, date, readOnly;
}

Future<Map<String, String>?> schoolForm(
  BuildContext context,
  String title,
  List<FormFieldSpec> fields, {
  String button = 'Save',
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (context) => _SchoolForm(title, fields, button),
);

class _SchoolForm extends StatefulWidget {
  const _SchoolForm(this.title, this.fields, this.button);
  final String title, button;
  final List<FormFieldSpec> fields;
  @override
  State<_SchoolForm> createState() => _SchoolFormState();
}

class _SchoolFormState extends State<_SchoolForm> {
  final key = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(
        text: f.value.isEmpty && f.options != null
            ? f.options!.firstOrNull ?? ''
            : f.value,
      ),
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.fields
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: f.options != null
                        ? DropdownButtonFormField<String>(
                            initialValue:
                                f.options!.contains(controllers[f.key]!.text)
                                ? controllers[f.key]!.text
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: f.label),
                            items: f.options!
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                controllers[f.key]!.text = v ?? '',
                            validator: (v) =>
                                v == null ? 'Choose an option' : null,
                          )
                        : TextFormField(
                            controller: controllers[f.key],
                            maxLines: f.lines,
                            readOnly: f.date || f.readOnly,
                            keyboardType: f.number
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: f.label,
                              suffixIcon: f.date
                                  ? const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    )
                                  : null,
                            ),
                            onTap: f.date
                                ? () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          DateTime.tryParse(
                                            controllers[f.key]!.text,
                                          ) ??
                                          DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2040),
                                    );
                                    if (date != null) {
                                      controllers[f.key]!.text = DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(date);
                                    }
                                  }
                                : null,
                            validator: (v) {
                              if (!f.optional &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'This field is required';
                              }
                              if (f.number &&
                                  v != null &&
                                  (num.tryParse(v) == null ||
                                      !num.parse(v).isFinite)) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (key.currentState!.validate()) {
            Navigator.pop(
              context,
              controllers.map((k, v) => MapEntry(k, v.text.trim())),
            );
          }
        },
        child: Text(widget.button),
      ),
    ],
  );
}

/// Original vector illustration: an open book, school windows, sun and growing leaves.
class CampusArt extends StatelessWidget {
  const CampusArt({super.key, this.height = 160});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: height * 1.25,
    child: CustomPaint(painter: _CampusPainter()),
  );
}

class _CampusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 250, size.height / 200);
    final p = Paint();
    canvas.drawCircle(
      const Offset(145, 92),
      78,
      p..color = const Color(0xFFE0ECE0),
    );
    canvas.drawCircle(const Offset(204, 40), 19, p..color = amber);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(73, 55, 134, 120),
        const Radius.circular(8),
      ),
      p..color = const Color(0xFFF9EFD8),
    );
    final roof = Path()
      ..moveTo(59, 62)
      ..lineTo(139, 19)
      ..lineTo(220, 62)
      ..close();
    canvas.drawPath(roof, p..color = teal);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 4; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(88 + col * 27, 76 + row * 37, 15, 23),
            const Radius.circular(7),
          ),
          p..color = const Color(0xFF8CAD97),
        );
        canvas.drawLine(
          Offset(95.5 + col * 27, 77 + row * 37),
          Offset(95.5 + col * 27, 98 + row * 37),
          p
            ..color = const Color(0xFFF9EFD8)
            ..strokeWidth = 2,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(126, 139, 27, 37),
        const Radius.circular(10),
      ),
      p..color = teal,
    );
    final book = Path()
      ..moveTo(31, 146)
      ..quadraticBezierTo(56, 135, 88, 150)
      ..lineTo(88, 190)
      ..quadraticBezierTo(60, 174, 31, 183)
      ..close();
    canvas.drawPath(book, p..color = Colors.white);
    final right = Path()
      ..moveTo(88, 150)
      ..quadraticBezierTo(114, 138, 139, 146)
      ..lineTo(139, 183)
      ..quadraticBezierTo(112, 175, 88, 190)
      ..close();
    canvas.drawPath(right, p..color = const Color(0xFFDAE8DB));
    canvas.drawLine(
      const Offset(88, 150),
      const Offset(88, 190),
      p
        ..color = teal
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(43, 154 + i * 8),
        Offset(73, 160 + i * 7),
        p
          ..color = const Color(0xFFB6CAB9)
          ..strokeWidth = 2,
      );
    }
    canvas.drawLine(
      const Offset(216, 181),
      const Offset(214, 119),
      p
        ..color = teal
        ..strokeWidth = 3,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromLTWH(194, 126 + i * 16, 22, 10),
        p..color = teal,
      );
      canvas.drawOval(
        Rect.fromLTWH(213, 117 + i * 17, 22, 11),
        p..color = const Color(0xFF77A68B),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(204, 172, 25, 16),
        const Radius.circular(4),
      ),
      p..color = clay,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
