import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/controller.dart';
import '../domain/models.dart';
import 'widgets.dart';

Future<void> exportSchoolReport(
  SchoolController school, {
  bool receipt = false,
  Map<String, String>? receiptData,
}) async {
  final pdf = pw.Document();
  final regular = await fontFromAssetBundle('assets/fonts/Manrope.ttf');
  final title = receipt
      ? 'Payment receipt'
      : school.role.teaches
      ? 'School overview'
      : 'Academic progress report';
  final rows = <List<String>>[];
  if (receipt) {
    rows.addAll(receiptData!.entries.map((e) => [e.key, e.value]));
  } else if (school.role.teaches) {
    rows.add(['Class', 'Students', 'Attendance']);
    for (final c in school.accessibleClasses) {
      rows.add([
        c,
        '${school.records('student', classId: c).length}',
        '${school.attendanceRate(school.records('attendance', classId: c)).toStringAsFixed(1)}%',
      ]);
    }
  } else {
    rows.add(['Subject', 'Assessment', 'Marks']);
    for (final m in school.records('mark')) {
      rows.add([
        m.text('subject'),
        m.text('assessment'),
        '${m.number('score')} / ${m.number('max')}',
      ]);
    }
    for (final a
        in school.records('attempt').where((a) => a.flag('published'))) {
      rows.add([
        a.text('subject'),
        a.text('title'),
        '${a.number('score')} / ${a.number('max')}',
      ]);
    }
  }
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: regular),
      build: (_) => [
        pw.Text(
          'schoolsphere',
          style: pw.TextStyle(fontSize: 26, color: PdfColor.fromHex('#146B5D')),
        ),
        pw.SizedBox(height: 8),
        pw.Text(school.schoolName),
        pw.SizedBox(height: 28),
        pw.Text(title, style: const pw.TextStyle(fontSize: 22)),
        pw.SizedBox(height: 8),
        pw.Text(
          school.role.teaches
              ? 'Prepared for ${school.user!.name}'
              : 'Student: ${school.studentName}',
        ),
        pw.Text('Generated ${niceDate(school.clock().toIso8601String())}'),
        pw.SizedBox(height: 24),
        pw.TableHelper.fromTextArray(
          data: rows,
          headerCount: receipt ? 0 : 1,
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#DDEDE3'),
          ),
          cellPadding: const pw.EdgeInsets.all(10),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        if (!receipt && !school.role.teaches) ...[
          pw.SizedBox(height: 24),
          pw.Text(
            'Attendance: ${school.attendanceRate(school.records('attendance')).toStringAsFixed(1)}%',
          ),
        ],
        pw.SizedBox(height: 24),
        pw.Text(
          school.live
              ? 'Generated from school records.'
              : 'Portfolio demonstration. Fictional school records.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
      footer: (_) => pw.Text(
        'SchoolSphere · InGrowwth Innovations',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ),
  );
  await Printing.layoutPdf(
    onLayout: (_) => pdf.save(),
    name: receipt ? 'SchoolSphere-receipt.pdf' : 'SchoolSphere-report.pdf',
  );
}
