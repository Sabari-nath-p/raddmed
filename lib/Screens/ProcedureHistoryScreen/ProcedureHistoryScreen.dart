import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raddmed/Models/ProcedureModel.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';
import 'package:raddmed/Services/PdfReportService.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens (same theme as ActiveAblationScreen)
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF0D1B2A);
const _kNavyLight = Color(0xFF1A2E47);
const _kRed = Color(0xFFE3192B);
const _kGreen = Color(0xFF00C896);
const _kBlue = Color(0xFF3B82F6);
const _kAmber = Color(0xFFF59E0B);
const _kPurple = Color(0xFF8B5CF6);
const _kBg = Color(0xFFF0F2F5);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE4E8EF);
const _kSubText = Color(0xFF8A96A8);
const _kOrange = Color(0xFFEA580C);

// ─────────────────────────────────────────────────────────────────────────────
// Log Entry model (mirrors ActiveAblationScreen)
// ─────────────────────────────────────────────────────────────────────────────
class _LogEntry {
  final String time;
  final String message;
  final String level;
  const _LogEntry({
    required this.time,
    required this.message,
    required this.level,
  });

  factory _LogEntry.fromJson(Map<String, dynamic> j) => _LogEntry(
    time: j['time'] ?? '',
    message: j['msg'] ?? '',
    level: j['lvl'] ?? 'info',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Procedure History List Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProcedureHistoryScreen extends StatefulWidget {
  const ProcedureHistoryScreen({super.key});

  @override
  State<ProcedureHistoryScreen> createState() => _ProcedureHistoryScreenState();
}

class _ProcedureHistoryScreenState extends State<ProcedureHistoryScreen> {
  List<ProcedureModel> _all = [];
  List<ProcedureModel> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _all = ProcedureRepository.getAllProcedures()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _all.where((p) {
      final matchSearch =
          q.isEmpty ||
          p.patientName.toLowerCase().contains(q) ||
          p.patientId.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.initiatedByUserName.toLowerCase().contains(q) ||
          p.mode.toLowerCase().contains(q);
      final matchStatus = _statusFilter == 'All' || p.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.isNotEmpty ? iso : '—';
    }
  }

  String _duration(ProcedureModel p) {
    try {
      if (p.endTime.isEmpty) return 'In progress';
      final s = DateTime.parse(p.startTime);
      final e = DateTime.parse(p.endTime);
      final diff = e.difference(s);
      final m = diff.inMinutes;
      final sec = diff.inSeconds % 60;
      return '${m}m ${sec}s';
    } catch (_) {
      return '—';
    }
  }

  Color _modeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'continuous':
        return _kBlue;
      case 'footswitch':
        return _kGreen;
      case 'endovascular':
      case 'endovorus':
        return _kPurple;
      default:
        return _kSubText;
    }
  }

  Color _statusColor(String s) => s == 'Completed'
      ? _kGreen
      : s == 'Active'
      ? _kAmber
      : _kRed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _kBg,
          body: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFilterBar(),
                      const SizedBox(height: 16),
                      _buildTableHeader(),
                      const SizedBox(height: 4),
                      Expanded(child: _buildList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Export progress overlay
        if (_exporting)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _kGreen, strokeWidth: 3),
                    SizedBox(height: 16),
                    Text(
                      'Generating Excel file...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please wait',
                      style: TextStyle(fontSize: 12, color: _kSubText),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return UnifiedHeader(
      title: 'Procedure History',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 14,
            color: Colors.black54,
          ),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBlue.withOpacity(0.3)),
        ),
        child: Text(
          '${_all.length} Records',
          style: const TextStyle(
            color: _kBlue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        // ── Search ───────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() => _applyFilter()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by patient, area, mode, physician...',
                hintStyle: const TextStyle(color: _kSubText, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: _kSubText,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _applyFilter());
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _kSubText,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── Status filter chips ───────────────────────────────────────────────
        ...['All', 'Completed', 'Active', 'Incomplete'].map(
          (s) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _statusFilter = s;
                _applyFilter();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _statusFilter == s ? _kNavy : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusFilter == s ? _kNavy : _kBorder,
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusFilter == s ? Colors.white : _kSubText,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── Export All button ─────────────────────────────────────────────────
        Tooltip(
          message: 'Export all visible records to Excel',
          child: GestureDetector(
            onTap: _filtered.isNotEmpty ? _exportAll : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _filtered.isNotEmpty
                    ? _kGreen.withOpacity(0.1)
                    : _kBorder.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _filtered.isNotEmpty
                      ? _kGreen.withOpacity(0.35)
                      : _kBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_chart_rounded,
                    size: 16,
                    color: _filtered.isNotEmpty ? _kGreen : _kSubText,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Export All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filtered.isNotEmpty ? _kGreen : _kSubText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ── Refresh ───────────────────────────────────────────────────────────
        Tooltip(
          message: 'Refresh list',
          child: GestureDetector(
            onTap: _load,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: _kSubText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    // flex values must match _ProcedureRow: 2,3,2,2,3,2,2,1
    const cols = [
      ('DATE & TIME', 2),
      ('PATIENT', 3),
      ('AREA', 2),
      ('MODE', 2),
      ('PHYSICIAN', 3),
      ('DURATION', 2),
      ('STATUS', 2),
      ('ACTIONS', 1),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _kNavyLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: cols
            .map(
              (c) => Expanded(
                flex: c.$2,
                child: Text(
                  c.$1,
                  style: const TextStyle(
                    color: _kSubText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 56,
              color: _kSubText.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'No procedures found',
              style: TextStyle(
                color: _kSubText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search or filter',
              style: TextStyle(color: _kSubText, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = _filtered[i];
        return _ProcedureRow(
          procedure: p,
          dateStr: _formatDate(p.startTime),
          duration: _duration(p),
          modeColor: _modeColor(p.mode),
          statusColor: _statusColor(p.status),
          onTap: () => _openDetail(p),
          onExport: () => _exportSingle(p),
        );
      },
    );
  }

  void _openDetail(ProcedureModel p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProcedureDetailScreen(procedure: p)),
    );
  }

  Future<void> _exportSingle(ProcedureModel p) async {
    await _showExportDialog([p], isSingle: true);
  }

  Future<void> _exportAll() async {
    await _showExportDialog(_filtered, isSingle: false);
  }

  /// Shows a save-location dialog, then exports.
  Future<void> _showExportDialog(
    List<ProcedureModel> procs, {
    required bool isSingle,
  }) async {
    final ts = DateTime.now();
    final defaultName = isSingle
        ? 'procedure_${procs.first.patientId}_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}.xlsx'
        : 'raddmed_export_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.xlsx';

    // Get default documents dir for the initial directory suggestion
    final docsDir = await getApplicationDocumentsDirectory();

    // Show native macOS/Windows save dialog
    final FileSaveLocation? loc = await getSaveLocation(
      suggestedName: defaultName,
      initialDirectory: docsDir.path,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel Workbook', extensions: ['xlsx']),
      ],
    );

    if (loc == null) return; // user cancelled
    if (!mounted) return;

    // Show progress
    setState(() => _exporting = true);
    try {
      await _exportToExcel(procs, savePath: loc.path);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Parses the procedureLog JSON and extracts key settings from event messages.
  /// Pump rate is only shown for Endovorus/Endovascular mode — null (—) for all others.
  Map<String, String> _parseLogDetails(ProcedureModel p) {
    String powerSet = '—';
    String timerSet = '—';
    String pumpRate = '—';
    String cycleCount = p.numberCycle ?? '—';

    // Pump rate is only meaningful in Endovorus mode
    final isEndoMode =
        p.mode.toLowerCase() == 'endovorus' ||
        p.mode.toLowerCase() == 'endovascular';

    if (p.procedureLog != null && p.procedureLog!.isNotEmpty) {
      try {
        final entries = (jsonDecode(p.procedureLog!) as List)
            .map((e) => _LogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final e in entries) {
          final msg = e.message;
          // Extract power: matches "Power: 75 W"
          final pwrMatch = RegExp(r'Power:\s*(\d+)\s*W').firstMatch(msg);
          if (pwrMatch != null && powerSet == '—')
            powerSet = '${pwrMatch.group(1)} W';

          // Extract timer: matches "Timer: 5 min" or "Timer: 60 s"
          final timerMatch = RegExp(
            r'Timer:\s*([\d]+\s*(?:min|s))',
          ).firstMatch(msg);
          if (timerMatch != null && timerSet == '—')
            timerSet = timerMatch.group(1) ?? '—';

          // Extract pump rate (Endovorus only): matches "Flow: 5 m/s" or legacy "Flow: 50%"
          if (isEndoMode) {
            final pumpMatchMs = RegExp(r'Flow:\s*(\d+)\s*m\/s').firstMatch(msg);
            final pumpMatchPct = RegExp(r'Flow:\s*(\d+)%').firstMatch(msg);
            if (pumpMatchMs != null && pumpRate == '—')
              pumpRate = '${pumpMatchMs.group(1)} m/s';
            else if (pumpMatchPct != null && pumpRate == '—')
              pumpRate = '${pumpMatchPct.group(1)} m/s';
          }

          // Cycle count from log if not already in model field
          if (cycleCount == '—') {
            final cycleMatch = RegExp(r'Cycle\s*(\d+)').firstMatch(msg);
            if (cycleMatch != null) cycleCount = cycleMatch.group(1) ?? '—';
          }
        }
      } catch (_) {}
    }
    return {
      'power': powerSet,
      'timer': timerSet,
      'pumpRate': pumpRate, // '—' for non-Endovorus modes
      'cycleCount': cycleCount,
    };
  }

  Future<void> _exportToExcel(
    List<ProcedureModel> procs, {
    required String savePath,
  }) async {
    final excel = xl.Excel.createExcel();

    // ── Styles ─────────────────────────────────────────────────────────────
    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#0D1B2A'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
    );
    final altRowStyle = xl.CellStyle(
      backgroundColorHex: xl.ExcelColor.fromHexString('#F0F4F8'),
    );

    // ── Sheet 1: Procedure Summary ──────────────────────────────────────────
    final xl.Sheet summarySheet = excel['Procedure Summary'];
    excel.setDefaultSheet('Procedure Summary');

    final sumHeaders = [
      'Patient Name',
      'Patient ID',
      'Procedure Area',
      'Mode',
      'Done By (Staff Name)',
      'Staff User ID',
      'Power Set (W)',
      'Timer Set',
      'Pump Flow Rate',
      'Cycle Count (Footswitch)',
      'Antenna Type',
      'Antenna Serial No.',
      'Start Time',
      'End Time',
      'Duration',
      'Status',
    ];
    for (int c = 0; c < sumHeaders.length; c++) {
      final cell = summarySheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = xl.TextCellValue(sumHeaders[c]);
      cell.cellStyle = headerStyle;
    }

    for (int r = 0; r < procs.length; r++) {
      final p = procs[r];
      String dur = '—';
      try {
        if (p.endTime.isNotEmpty) {
          final diff = DateTime.parse(
            p.endTime,
          ).difference(DateTime.parse(p.startTime));
          dur = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
        }
      } catch (_) {}

      final details = _parseLogDetails(p);
      final row = [
        p.patientName,
        p.patientId,
        p.category,
        p.mode,
        p.initiatedByUserName,
        p.initiatedByUserId,
        details['power']!,
        details['timer']!,
        details['pumpRate']!,
        details['cycleCount']!,
        p.antenna,
        p.antennaSerialNumber,
        p.startTime,
        p.endTime.isNotEmpty ? p.endTime : '—',
        dur,
        p.status,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = summarySheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
        );
        cell.value = xl.TextCellValue(row[c]);
        if (r.isOdd) cell.cellStyle = altRowStyle;
      }
    }

    // ── Sheet 2: Event Logs ─────────────────────────────────────────────────
    final xl.Sheet logSheet = excel['Event Logs'];
    final logHeaders = [
      'Procedure ID',
      'Patient Name',
      'Patient ID',
      'Procedure Area',
      'Mode',
      'Staff Name',
      'Time',
      'Level',
      'Event Message',
    ];
    for (int c = 0; c < logHeaders.length; c++) {
      final cell = logSheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = xl.TextCellValue(logHeaders[c]);
      cell.cellStyle = headerStyle;
    }
    int logRow = 1;
    for (final p in procs) {
      if (p.procedureLog != null && p.procedureLog!.isNotEmpty) {
        try {
          final entries = (jsonDecode(p.procedureLog!) as List)
              .map((e) => _LogEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          for (final e in entries) {
            final row = [
              p.id,
              p.patientName,
              p.patientId,
              p.category,
              p.mode,
              p.initiatedByUserName,
              e.time,
              e.level.toUpperCase(),
              e.message,
            ];
            for (int c = 0; c < row.length; c++) {
              logSheet
                  .cell(
                    xl.CellIndex.indexByColumnRow(
                      columnIndex: c,
                      rowIndex: logRow,
                    ),
                  )
                  .value = xl.TextCellValue(
                row[c],
              );
            }
            logRow++;
          }
        } catch (_) {}
      }
    }

    // ── Save to chosen path ─────────────────────────────────────────────────
    try {
      final bytes = excel.encode();
      if (bytes != null) {
        await File(savePath).writeAsBytes(bytes);
        if (mounted) _showExportSuccess(savePath, procs.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  void _showExportSuccess(String path, int recordCount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 480,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: _kGreen.withOpacity(0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _kGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Successful',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kNavy,
                          ),
                        ),
                        Text(
                          '$recordCount record${recordCount == 1 ? '' : 's'} exported to Excel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kSubText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Path info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FILE LOCATION',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _kSubText,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: _kSubText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              path,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: _kNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Copy path',
                            child: InkWell(
                              onTap: () =>
                                  Clipboard.setData(ClipboardData(text: path)),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: _kSubText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '2 sheets: Procedure Summary + Event Logs',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kSubText.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Row Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ProcedureRow extends StatefulWidget {
  final ProcedureModel procedure;
  final String dateStr, duration;
  final Color modeColor, statusColor;
  final VoidCallback onTap, onExport;
  const _ProcedureRow({
    required this.procedure,
    required this.dateStr,
    required this.duration,
    required this.modeColor,
    required this.statusColor,
    required this.onTap,
    required this.onExport,
  });

  @override
  State<_ProcedureRow> createState() => _ProcedureRowState();
}

class _ProcedureRowState extends State<_ProcedureRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.procedure;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF8F9FF) : _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? _kBlue.withOpacity(0.2) : _kBorder,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: _kBlue.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Date
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dateStr.split('  ')[0],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                    Text(
                      widget.dateStr.split('  ').length > 1
                          ? widget.dateStr.split('  ')[1]
                          : '',
                      style: const TextStyle(fontSize: 11, color: _kSubText),
                    ),
                  ],
                ),
              ),
              // Patient
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.patientName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                    Text(
                      'ID: ${p.patientId}',
                      style: const TextStyle(fontSize: 11, color: _kSubText),
                    ),
                  ],
                ),
              ),
              // Area
              Expanded(
                flex: 2,
                child: Text(
                  p.category,
                  style: const TextStyle(fontSize: 13, color: _kNavy),
                ),
              ),
              // Mode
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.modeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.modeColor.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    p.mode,
                    style: TextStyle(
                      color: widget.modeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Physician
              Expanded(
                flex: 3,
                child: Text(
                  p.initiatedByUserName,
                  style: const TextStyle(fontSize: 13, color: _kNavy),
                ),
              ),
              // Duration
              Expanded(
                flex: 2,
                child: Text(
                  widget.duration,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.status,
                    style: TextStyle(
                      color: widget.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Actions
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: widget.onTap,
                      child: const Tooltip(
                        message: 'View Details',
                        child: Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: _kBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: widget.onExport,
                      child: const Tooltip(
                        message: 'Export to Excel',
                        child: Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: _kGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Procedure Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProcedureDetailScreen extends StatelessWidget {
  final ProcedureModel procedure;
  const ProcedureDetailScreen({super.key, required this.procedure});

  List<_LogEntry> get _logs {
    if (procedure.procedureLog == null || procedure.procedureLog!.isEmpty)
      return [];
    try {
      return (jsonDecode(procedure.procedureLog!) as List)
          .map((e) => _LogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String get _duration {
    try {
      if (procedure.endTime.isEmpty) return 'In progress';
      final diff = DateTime.parse(
        procedure.endTime,
      ).difference(DateTime.parse(procedure.startTime));
      return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    } catch (_) {
      return '—';
    }
  }

  Color get _modeColor {
    switch (procedure.mode.toLowerCase()) {
      case 'continuous':
        return _kBlue;
      case 'footswitch':
        return _kGreen;
      case 'endovascular':
      case 'endovorus':
        return _kPurple;
      default:
        return _kSubText;
    }
  }

  Color get _statusColor => procedure.status == 'Completed'
      ? _kGreen
      : procedure.status == 'Active'
      ? _kAmber
      : _kRed;

  Future<void> _exportToExcel(BuildContext context) async {
    final excel = xl.Excel.createExcel();
    final xl.Sheet sheet = excel['Procedure Details'];
    excel.setDefaultSheet('Procedure Details');

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#0D1B2A'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
    );

    // Parse settings from log
    // Pump rate only populated for Endovorus/Endovascular mode
    final isEndoMode =
        procedure.mode.toLowerCase() == 'endovorus' ||
        procedure.mode.toLowerCase() == 'endovascular';
    String powerSet = '—', timerSet = '—', pumpRate = '—';
    String cycleCount = procedure.numberCycle ?? '—';
    for (final e in _logs) {
      final msg = e.message;
      final pwrMatch = RegExp(r'Power:\s*(\d+)\s*W').firstMatch(msg);
      if (pwrMatch != null && powerSet == '—')
        powerSet = '${pwrMatch.group(1)} W';
      final timerMatch = RegExp(
        r'Timer:\s*([\d]+\s*(?:min|s))',
      ).firstMatch(msg);
      if (timerMatch != null && timerSet == '—')
        timerSet = timerMatch.group(1) ?? '—';
      // Pump rate: only for Endovorus mode, matches m/s or legacy %
      if (isEndoMode) {
        final pumpMatchMs = RegExp(r'Flow:\s*(\d+)\s*m\/s').firstMatch(msg);
        final pumpMatchPct = RegExp(r'Flow:\s*(\d+)%').firstMatch(msg);
        if (pumpMatchMs != null && pumpRate == '—')
          pumpRate = '${pumpMatchMs.group(1)} m/s';
        else if (pumpMatchPct != null && pumpRate == '—')
          pumpRate = '${pumpMatchPct.group(1)} m/s';
      }
      if (cycleCount == '—') {
        final cycleMatch = RegExp(r'Cycle\s*(\d+)').firstMatch(msg);
        if (cycleMatch != null) cycleCount = cycleMatch.group(1) ?? '—';
      }
    }

    // Info section
    final staffLabel =
        '${procedure.initiatedByUserName} (ID: ${procedure.initiatedByUserId})';
    final infoRows = [
      ['Field', 'Value'],
      ['Patient Name', procedure.patientName],
      ['Patient ID', procedure.patientId],
      ['Area / Category', procedure.category],
      ['Mode', procedure.mode],
      ['Physician', procedure.initiatedByUserName],
      ['Staff ID', procedure.initiatedByUserId],
      ['Physician (Full)', staffLabel],
      ['Power Set', powerSet],
      ['Timer Set', timerSet],
      ['Pump Rate', pumpRate],
      ['Cycle Count', cycleCount],
      ['Antenna', procedure.antenna],
      ['Antenna Serial', procedure.antennaSerialNumber],
      ['Start Time', procedure.startTime],
      ['End Time', procedure.endTime],
      ['Duration', _duration],
      ['Status', procedure.status],
    ];

    for (int r = 0; r < infoRows.length; r++) {
      for (int c = 0; c < infoRows[r].length; c++) {
        final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        cell.value = xl.TextCellValue(infoRows[r][c]);
        if (r == 0) cell.cellStyle = headerStyle;
      }
    }

    // Event log section
    final logSheet = excel['Event Log'];
    final logHeaders = ['Time', 'Level', 'Event'];
    for (int c = 0; c < logHeaders.length; c++) {
      final cell = logSheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = xl.TextCellValue(logHeaders[c]);
      cell.cellStyle = headerStyle;
    }
    final logs = _logs;
    for (int r = 0; r < logs.length; r++) {
      logSheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = xl.TextCellValue(
        logs[r].time,
      );
      logSheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1))
          .value = xl.TextCellValue(
        logs[r].level.toUpperCase(),
      );
      logSheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1))
          .value = xl.TextCellValue(
        logs[r].message,
      );
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fname =
          'raddmed_${procedure.patientId}_${procedure.id.substring(0, 8)}.xlsx';
      final file = File('${dir.path}/$fname');
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _kGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Exported!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved to:',
                    style: TextStyle(color: _kSubText, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      file.path,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: _kNavy,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _logs;
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: _kNavy,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Text(
                      'RAAD',
                      style: TextStyle(
                        color: _kRed,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'MED',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 22,
                  color: Colors.white.withOpacity(0.12),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                const Icon(
                  Icons.folder_open_rounded,
                  color: _kPurple,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${procedure.patientName} — Procedure Detail',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Print Report button
                GestureDetector(
                  onTap: () => PdfReportService.generateAndPrintProcedureReport(
                    procedure,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _kGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGreen.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print_rounded, size: 16, color: _kGreen),
                        SizedBox(width: 8),
                        Text(
                          'Save as PDF',
                          style: TextStyle(
                            color: _kGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: procedure info cards
                  SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _InfoCard(
                            title: 'PATIENT',
                            icon: Icons.person_outline,
                            color: _kBlue,
                            rows: [
                              _InfoRow('Name', procedure.patientName),
                              _InfoRow('Patient ID', procedure.patientId),
                              _InfoRow('Area', procedure.category),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InfoCard(
                            title: 'PROCEDURE',
                            icon: Icons.science_outlined,
                            color: _kPurple,
                            rows: [
                              _InfoRow(
                                'Mode',
                                procedure.mode,
                                valueColor: _modeColor,
                              ),
                              _InfoRow('Antenna', procedure.antenna),
                              _InfoRow(
                                'Serial No.',
                                procedure.antennaSerialNumber.isNotEmpty
                                    ? procedure.antennaSerialNumber
                                    : '—',
                              ),
                              _InfoRow(
                                'Physician',
                                procedure.initiatedByUserName,
                              ),
                              if (procedure.numberCycle != null)
                                _InfoRow('Cycles', procedure.numberCycle!),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InfoCard(
                            title: 'TIMING',
                            icon: Icons.schedule_rounded,
                            color: _kAmber,
                            rows: [
                              _InfoRow(
                                'Start',
                                _formatDate(procedure.startTime),
                              ),
                              _InfoRow(
                                'End',
                                procedure.endTime.isNotEmpty
                                    ? _formatDate(procedure.endTime)
                                    : 'In progress',
                              ),
                              _InfoRow('Duration', _duration),
                              _InfoRow(
                                'Status',
                                procedure.status,
                                valueColor: _statusColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right column: timeline/graph + event log
                  Expanded(
                    child: Column(
                      children: [
                        // Voltage-over-time graph (from log events)
                        if (logs.isNotEmpty) ...[
                          _EventTimelineChart(logs: logs),
                          const SizedBox(height: 14),
                        ],
                        // Event log
                        Expanded(child: _EventLogPanel(logs: logs)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Card
// ─────────────────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_InfoRow> rows;
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...rows,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: _kSubText, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _kNavy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Timeline Chart (based on log entries)
// ─────────────────────────────────────────────────────────────────────────────
class _EventTimelineChart extends StatelessWidget {
  final List<_LogEntry> logs;
  const _EventTimelineChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    // Determine key events from log
    final events = logs
        .where(
          (e) =>
              e.message.contains('PUMP') ||
              e.message.contains('OVEN') ||
              e.message.contains('Cycle') ||
              e.message.contains('Timer complete') ||
              e.message.contains('Footswitch'),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 14,
                  color: _kPurple,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'PROCEDURE TIMELINE',
                style: TextStyle(
                  color: _kPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${logs.length} events',
                style: const TextStyle(color: _kSubText, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No key events to chart',
                  style: TextStyle(color: _kSubText, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 80,
              child: CustomPaint(
                painter: _TimelinePainter(events: events),
                size: const Size(double.infinity, 80),
              ),
            ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Legend('Pump Event', _kOrange),
              _Legend('Oven Event', _kRed),
              _Legend('Cycle / Timer', _kPurple),
              _Legend('Footswitch', _kGreen),
              _Legend('Info', _kBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _Legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: _kSubText)),
    ],
  );
}

class _TimelinePainter extends CustomPainter {
  final List<_LogEntry> events;
  const _TimelinePainter({required this.events});

  Color _colorForEvent(_LogEntry e) {
    final m = e.message.toUpperCase();
    if (m.contains('PUMP')) return _kOrange;
    if (m.contains('OVEN')) return _kRed;
    if (m.contains('CYCLE') || m.contains('TIMER')) return _kPurple;
    if (m.contains('FOOTSWITCH')) return _kGreen;
    return _kBlue;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (events.isEmpty) return;

    // Draw baseline
    final linePaint = Paint()
      ..color = _kBorder
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint,
    );

    // Draw event dots
    final n = events.length;
    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : (i / (n - 1)) * size.width;
      final color = _colorForEvent(events[i]);
      final dotPaint = Paint()..color = color;
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(x, size.height / 2), 8, dotPaint);
      canvas.drawCircle(Offset(x, size.height / 2), 8, strokePaint);

      // Time label
      final textSpan = TextSpan(
        text: events[i].time,
        style: const TextStyle(color: _kSubText, fontSize: 9),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = (x - textPainter.width / 2).clamp(
        0.0,
        size.width - textPainter.width,
      );
      final above = i % 2 == 0;
      textPainter.paint(canvas, Offset(lx, above ? 2 : size.height - 14));
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Log Panel
// ─────────────────────────────────────────────────────────────────────────────
class _EventLogPanel extends StatefulWidget {
  final List<_LogEntry> logs;
  const _EventLogPanel({required this.logs});

  @override
  State<_EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<_EventLogPanel> {
  String _levelFilter = 'All';

  Color _logColor(String level) {
    switch (level) {
      case 'warning':
        return _kAmber;
      case 'success':
        return _kGreen;
      case 'error':
        return _kRed;
      default:
        return _kBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _levelFilter == 'All'
        ? widget.logs
        : widget.logs
              .where((e) => e.level == _levelFilter.toLowerCase())
              .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kNavyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, size: 14, color: _kGreen),
              const SizedBox(width: 8),
              const Text(
                'EVENT LOG',
                style: TextStyle(
                  color: _kGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              // Filter chips
              ...['All', 'info', 'warning', 'success', 'error'].map(
                (l) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _levelFilter = l),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _levelFilter == l
                            ? Colors.white.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.white.withOpacity(
                            _levelFilter == l ? 0.2 : 0.08,
                          ),
                        ),
                      ),
                      child: Text(
                        l == 'All'
                            ? 'All'
                            : l[0].toUpperCase() + l.substring(1),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _levelFilter == l
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${filtered.length} events',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No events',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.time,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _logColor(e.level).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.level.toUpperCase(),
                                style: TextStyle(
                                  color: _logColor(e.level),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.message,
                                style: TextStyle(
                                  color: i == 0 ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: i == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
