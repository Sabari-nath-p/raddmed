import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raddmed/Models/Enums/UserType.dart';
import 'package:raddmed/Screens/ProcedureHistoryScreen/ProcedureHistoryScreen.dart';
import 'package:raddmed/Screens/ActiveAblationScreen/ActiveAblationScreen.dart';
import 'package:raddmed/Screens/CreateAblationScreen/CreateAblationScreen.dart';
import 'package:raddmed/Screens/PatientScreen/PatientScreen.dart';
import 'package:raddmed/Screens/UserManagmentScreen/UserManagementScreen.dart';
import 'package:raddmed/Services/SerialService.dart';

import 'package:raddmed/Models/UserModel.dart';
import 'package:raddmed/Repositories/PatientRepository.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Screens/AdminSettingsScreen/AdminSettingsScreen.dart';
import 'package:raddmed/Screens/AuthenticationScreen/AuthenticationScreen.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';
import 'package:raddmed/Models/Enums/InstrumentAccess.dart';

class DashboardScreen extends StatelessWidget {
  final UserModel currentUser;

  const DashboardScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          UnifiedHeader(
            title: 'Dashboard',
            subtitle: 'Overview of your ablation system',
            currentUser: currentUser,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(flex: 13, child: _SystemStatusCard()),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 9,
                        child: _SummaryCard(currentUser: currentUser),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _QuickActionsCard(currentUser: currentUser),
                ],
              ),
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

// Removed _Header as it's replaced by UnifiedHeader

// --- System Status Card ---
class _SystemStatusCard extends StatefulWidget {
  const _SystemStatusCard();

  @override
  State<_SystemStatusCard> createState() => _SystemStatusCardState();
}

class _SystemStatusCardState extends State<_SystemStatusCard> {
  final _serial = SerialService.instance;
  String? _selectedPort;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serial.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = status.error;
        });
      }
    });
    // Pre-select first available port
    final ports = _serial.availablePorts;
    if (ports.isNotEmpty) _selectedPort = ports.first;
  }

  void _refreshPorts() {
    setState(() {
      final ports = _serial.availablePorts;
      if (!ports.contains(_selectedPort)) {
        _selectedPort = ports.isNotEmpty ? ports.first : null;
      }
    });
  }

  void _toggleConnection() {
    if (_serial.isConnected) {
      _serial.disconnect();
      setState(() {});
    } else if (_selectedPort != null) {
      setState(() {
        _connecting = true;
        _error = null;
      });
      final ok = _serial.connect(_selectedPort!);
      setState(() {
        _connecting = false;
        if (!ok) _error = 'Connection failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ports = _serial.availablePorts;
    final connected = _serial.isConnected;

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.monitor_heart_outlined,
            title: 'System Status',
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Image Area
              Expanded(
                flex: 5,
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      Positioned(
                        bottom: 16,
                        child: Text(
                          'RADDMED Ablation Device',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 40),
              // Device Details + Port Selection
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Connection Status ──
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: connected
                                ? Colors.green
                                : _connecting
                                ? Colors.amber
                                : Colors.red.shade400,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (connected ? Colors.green : Colors.red)
                                    .withOpacity(0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          connected
                              ? 'Connected'
                              : _connecting
                              ? 'Connecting...'
                              : 'Disconnected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: connected
                                ? Colors.green.shade700
                                : const Color(0xFF1B2332),
                          ),
                        ),
                      ],
                    ),
                    if (connected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 24),
                        child: Text(
                          'Port: ${_serial.connectedPort}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // ── Port Selection Dropdown ──
                    Row(
                      children: [
                        Text(
                          'Serial Port',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _refreshPorts,
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Refresh ports',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: connected ? Colors.grey.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: connected
                              ? Colors.green.shade200
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: ports.contains(_selectedPort)
                              ? _selectedPort
                              : null,
                          hint: Text(
                            ports.isEmpty
                                ? 'No ports detected'
                                : 'Select a port...',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                          items: ports.map((p) {
                            return DropdownMenuItem<String>(
                              value: p,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.usb_rounded,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: connected
                              ? null
                              : (val) => setState(() => _selectedPort = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Error ──
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Connect / Disconnect Button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_selectedPort == null && !connected) || _connecting
                            ? null
                            : _toggleConnection,
                        icon: Icon(
                          connected
                              ? Icons.link_off_rounded
                              : Icons.usb_rounded,
                          size: 18,
                        ),
                        label: Text(
                          connected ? 'Disconnect' : 'Connect',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: connected
                              ? Colors.red.shade50
                              : const Color(0xFFE31820),
                          foregroundColor: connected
                              ? Colors.red.shade700
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: connected
                                ? BorderSide(color: Colors.red.shade200)
                                : BorderSide.none,
                          ),
                          elevation: connected ? 0 : 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Static Device Info ──
                    // const _DetailRow(label: 'Device Model', value: 'RAAD-2000'),
                    // const SizedBox(height: 12),
                    const _DetailRow(
                      label: 'Firmware Version',
                      value: 'v1.0.0',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Summary Card ---
class _SummaryCard extends StatefulWidget {
  final UserModel currentUser;
  const _SummaryCard({required this.currentUser});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  int _totalProcedures = 0;
  int _completedProcedures = 0;
  int _totalPatients = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final procedures = ProcedureRepository.getAllProcedures();
    final patients = PatientRepository.getAllPatients();

    setState(() {
      _totalProcedures = procedures.length;
      _completedProcedures = procedures
          .where((p) => p.status == 'Completed')
          .length;
      _totalPatients = patients.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.analytics_outlined,
            title: "Analytics Summary",
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  icon: Icons.work_outline,
                  color: Colors.blue,
                  count: _totalProcedures.toString().padLeft(2, '0'),
                  label: 'Procedures',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  count: _completedProcedures.toString().padLeft(2, '0'),
                  label: 'Completed',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  icon: Icons.people_outline,
                  color: Colors.purple,
                  count: _totalPatients.toString().padLeft(2, '0'),
                  label: 'Patients',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Assigned Categories',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.currentUser.accessInstruments.map((inst) {
              final (color, icon) = _accessStyle(inst);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      _instLabel(inst),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _accessStyle(InstrumentAccess inst) {
    switch (inst) {
      case InstrumentAccess.liver:
        return (Colors.orange, Icons.local_hospital_rounded);
      case InstrumentAccess.lung:
        return (Colors.red, Icons.favorite_rounded);
      case InstrumentAccess.kidney:
        return (Colors.blue, Icons.water_drop_rounded);
      case InstrumentAccess.bone:
        return (Colors.grey, Icons.medical_services_rounded);
      case InstrumentAccess.thyroid:
        return (Colors.purple, Icons.adjust_rounded);
      case InstrumentAccess.endovenuos:
        return (Colors.teal, Icons.timeline_rounded);
      case InstrumentAccess.breast:
        return (Colors.pink, Icons.face_3_rounded);
      case InstrumentAccess.uterus:
        return (Colors.deepPurple, Icons.child_care_rounded);
    }
  }

  String _instLabel(InstrumentAccess inst) {
    final s = inst.name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return s[0].toUpperCase() + s.substring(1);
  }
}

// --- Quick Actions Card ---
class _QuickActionsCard extends StatelessWidget {
  final UserModel currentUser;

  const _QuickActionsCard({required this.currentUser});

  void _showInfusionDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _InfusionDialog());
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: Icons.bolt, title: 'Quick Actions'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) =>
                            NewProcedureScreen(currentUser: currentUser),
                      ),
                    );
                  },
                  child: _ActionBox(
                    icon: Icons.gps_fixed,
                    color: const Color(0xFFE31820),
                    title: 'New Ablation',
                    subtitle: 'Start a new\nablation procedure',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => PatientsScreen()),
                    );
                  },
                  child: _ActionBox(
                    icon: Icons.person_add_alt_1,
                    color: Colors.blue,
                    title: 'Add Patient',
                    subtitle: 'Register a\nnew patient',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const ProcedureHistoryScreen(),
                      ),
                    );
                  },
                  child: const _ActionBox(
                    icon: Icons.history,
                    color: Colors.orange,
                    title: 'History',
                    subtitle: 'View procedure\nhistory',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Quick Infusion Mode button
              Expanded(
                child: InkWell(
                  onTap: () => _showInfusionDialog(context),
                  child: const _ActionBox(
                    icon: Icons.water_drop_rounded,
                    color: Color(0xFF0891B2),
                    title: 'Infusion Mode',
                    subtitle: 'Quick infusion\npump control',
                  ),
                ),
              ),
              if (currentUser.userType == UserType.admin) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              AdminSettingsScreen(currentUser: currentUser),
                        ),
                      );
                    },
                    child: const _ActionBox(
                      icon: Icons.settings,
                      color: Colors.purple,
                      title: 'Admin Settings',
                      subtitle: 'Manage hospital\nand staff',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Infusion Mode Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _InfusionDialog extends StatefulWidget {
  const _InfusionDialog();

  @override
  State<_InfusionDialog> createState() => _InfusionDialogState();
}

class _InfusionDialogState extends State<_InfusionDialog> {
  final _serial = SerialService.instance;
  int _flowRate = 0; // 0–250 Liter/min
  bool _isRunning = false;

  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    // Tell the device an infusion session is starting.
    _serial.send('2001');
  }

  void _toggleInfusion() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _serial.sendInfusionFlowRate(
        _flowRate.toDouble(),
      ); // ensure flow rate is set before starting
      _serial.sendPump(true);
    } else {
      _serial.sendPump(false);
    }
  }

  void _close() {
    if (_isRunning) {
      _serial.sendPump(false);
    }
    _repeatTimer?.cancel();
    Navigator.of(context).pop();
  }

  void _setFlowRate(int value) {
    final clamped = value.clamp(0, 250);
    if (clamped == _flowRate) return;
    setState(() => _flowRate = clamped);

    _serial.sendInfusionFlowRate(_flowRate.toDouble());
  }

  void _step(int delta) {
    _setFlowRate(_flowRate + delta);
  }

  // ── Long-press continuous stepping ─────────────────────────────────────
  void _startRepeating(int delta) {
    _step(delta); // immediate single-tap response
    _repeatTimer?.cancel();
    // Small initial delay before rapid-fire kicks in, like most native steppers.
    _repeatTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        _step(delta);
      });
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF0891B2);
    const navyDark = Color(0xFF0D1B2A);
    const borderCol = Color(0xFFE4E8EF);
    const subText = Color(0xFF8A96A8);
    const green = Color(0xFF00C896);
    const red = Color(0xFFE3192B);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cyan.withOpacity(0.12), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: cyan.withOpacity(0.15)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: cyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Infusion Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: navyDark,
                        ),
                      ),
                      Text(
                        'Quick infusion pump control',
                        style: TextStyle(fontSize: 12, color: subText),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Running indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isRunning
                          ? green.withOpacity(0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isRunning ? green.withOpacity(0.4) : borderCol,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isRunning ? green : subText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isRunning ? 'RUNNING' : 'IDLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _isRunning ? green : subText,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Flow Rate Control ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(
                    'FLOW RATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: subText,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Value display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: cyan.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cyan.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$_flowRate',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: cyan,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Liter/min',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: subText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // +/- controls
                  Row(
                    children: [
                      // Minus (tap = -1, long-press = continuous)
                      Expanded(
                        child: GestureDetector(
                          onTap: _flowRate > 0 ? () => _step(-1) : null,
                          onLongPressStart: _flowRate > 0
                              ? (_) => _startRepeating(-1)
                              : null,
                          onLongPressEnd: (_) => _stopRepeating(),
                          onLongPressUp: _stopRepeating,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 56,
                            decoration: BoxDecoration(
                              color: _flowRate > 0
                                  ? cyan.withOpacity(0.08)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _flowRate > 0
                                    ? cyan.withOpacity(0.3)
                                    : borderCol,
                              ),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 28,
                              color: _flowRate > 0
                                  ? cyan
                                  : subText.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Range label
                      Text(
                        '0 – 250 Liter/min',
                        style: TextStyle(
                          fontSize: 12,
                          color: subText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Plus (tap = +1, long-press = continuous)
                      Expanded(
                        child: GestureDetector(
                          onTap: _flowRate < 250 ? () => _step(1) : null,
                          onLongPressStart: _flowRate < 250
                              ? (_) => _startRepeating(1)
                              : null,
                          onLongPressEnd: (_) => _stopRepeating(),
                          onLongPressUp: _stopRepeating,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 56,
                            decoration: BoxDecoration(
                              color: _flowRate < 250
                                  ? cyan.withOpacity(0.08)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _flowRate < 250
                                    ? cyan.withOpacity(0.3)
                                    : borderCol,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 28,
                              color: _flowRate < 250
                                  ? cyan
                                  : subText.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Slider (0 – 250, draggable)
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: cyan,
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: cyan,
                      overlayColor: cyan.withOpacity(0.15),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                      ),
                    ),
                    child: Slider(
                      value: _flowRate.toDouble(),
                      min: 0,
                      max: 250,
                      divisions: 250,
                      label: '$_flowRate Liter/min',
                      onChanged: (value) => _setFlowRate(value.round()),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Start / Stop button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _toggleInfusion,
                      icon: Icon(
                        _isRunning
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isRunning ? 'STOP INFUSION' : 'START INFUSION',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? red : cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isRunning ? 0 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: subText),
                  const SizedBox(width: 6),
                  Text(
                    'CMD: ${_isRunning ? "1401 (ON)" : "1400 (OFF)"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: subText,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _close,
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: subText,
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
    );
  }
}

// --- Footer ---
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final connected = SerialService.instance.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected ? Colors.green : Colors.red.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                connected
                    ? 'System Ready — ${SerialService.instance.connectedPort}'
                    : 'Device Not Connected',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'RADDMED Ablation System v1.0.0',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Shared Reusable Components ---

class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFE31820)), // Red from Auth
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2332), // Dark Navy from Auth
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(width: 32, height: 2, color: const Color(0xFFE31820)),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String count;
  final String label;

  const _SummaryBox({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 32),
          Text(
            count,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B2332),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ActionBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1B2332),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1B2332),
            ),
          ),
        ),
      ],
    );
  }
}

// Removed _BrandLogo
