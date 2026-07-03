import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:raddmed/Models/ProcedureModel.dart';
import 'package:raddmed/Models/PatientModel.dart';
import 'package:raddmed/Repositories/PatientRepository.dart';
import 'package:intl/intl.dart';

class PdfReportService {
  static Future<void> generateAndPrintProcedureReport(
    ProcedureModel procedure,
  ) async {
    final doc = pw.Document();

    // Fetch full patient model
    PatientModel? patient;
    try {
      final allPatients = PatientRepository.getAllPatients();
      patient = allPatients.firstWhere(
        (p) =>
            p.patientId == procedure.patientId || p.id == procedure.patientId,
      );
    } catch (_) {}

    // Parse logs
    List<Map<String, dynamic>> logs = [];
    if (procedure.procedureLog != null && procedure.procedureLog!.isNotEmpty) {
      try {
        final decoded = jsonDecode(procedure.procedureLog!) as List;
        logs = decoded.map((e) => e as Map<String, dynamic>).toList();
      } catch (_) {}
    }

    // Format dates
    final startStr = _formatDate(procedure.startTime);
    final endStr = procedure.endTime != null
        ? _formatDate(procedure.endTime!)
        : 'N/A';

    // Parse set power from logs
    String setPower = '—';
    for (var l in logs) {
      final msg = l['msg']?.toString() ?? '';
      final pwrMatch = RegExp(r'Power:\s*(\d+)\s*W').firstMatch(msg);
      if (pwrMatch != null && setPower == '—') {
        setPower = pwrMatch.group(1)!;
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(procedure),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildPatientInfo(procedure, patient),
          pw.SizedBox(height: 20),
          _buildProcedureInfo(procedure, startStr, endStr, setPower),
          pw.SizedBox(height: 30),
          pw.Text(
            'System Logs & Events',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildLogTable(logs),
        ],
      ),
    );

    // Prompt native print / save as PDF dialogue
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Procedure_Report_${procedure.patientId}_${procedure.id}',
    );
  }

  static pw.Widget _buildHeader(ProcedureModel proc) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RADDMED',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  'Ablation Procedure Report',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Report Generated:',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.now()),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }

  static pw.Widget _buildPatientInfo(
    ProcedureModel proc,
    PatientModel? patient,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient Information',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name:', proc.patientName),
                    _infoRow('Patient ID:', proc.patientId),
                    _infoRow('Gender:', patient?.gender ?? 'N/A'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Age:', patient?.age ?? 'N/A'),
                    _infoRow('Mobile:', patient?.contactNumber ?? 'N/A'),
                    _infoRow('Area:', proc.category),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProcedureInfo(
    ProcedureModel proc,
    String startStr,
    String endStr,
    String setPower,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Procedure Details',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Mode:', proc.mode),
                    _infoRow('Status:', proc.status),
                    _infoRow('Physician:', proc.initiatedByUserName),
                    _infoRow('Start Time:', startStr),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Antenna:', proc.antenna),
                    _infoRow('Serial No:', proc.antennaSerialNumber),
                    _infoRow('Set Power:', '$setPower W'),
                    _infoRow('End Time:', endStr),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLogTable(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return pw.Text(
        'No logs recorded for this procedure.',
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColors.grey600,
          fontStyle: pw.FontStyle.italic,
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      context: null,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey800,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FlexColumnWidth(),
      },
      headers: ['Time', 'Level', 'Message'],
      data: logs.map((log) {
        return [
          log['time']?.toString() ?? '',
          (log['lvl']?.toString() ?? '').toUpperCase(),
          log['msg']?.toString() ?? '',
        ];
      }).toList(),
    );
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('MMM dd, yyyy hh:mm a').format(d);
    } catch (_) {
      return iso;
    }
  }
}
