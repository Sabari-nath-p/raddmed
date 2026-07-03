import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raddmed/Models/ProcedureModel.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Services/SerialService.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
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
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _LogEntry {
  final String time;
  final String message;
  final String level;
  _LogEntry({required this.time, required this.message, required this.level});
  Map<String, dynamic> toJson() => {'time': time, 'msg': message, 'lvl': level};
}

/// Maps the stored mode string (enum name) → display label.
String _modeLabel(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'footswitch':
      return 'Footswitch';
    case 'continuous':
      return 'Continuous';
    case 'endovascular':
    case 'endovorus':
      return 'Endovorus';
    default:
      return 'Continuous';
  }
}

bool _isFootswitchMode(String m) => m == 'Footswitch';
bool _isEndoMode(String m) => m == 'Endovorus';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class ActiveAblationScreen extends StatefulWidget {
  final ProcedureModel? procedure;
  const ActiveAblationScreen({super.key, this.procedure});

  @override
  State<ActiveAblationScreen> createState() => _ActiveAblationScreenState();
}

class _ActiveAblationScreenState extends State<ActiveAblationScreen>
    with TickerProviderStateMixin {
  // ── Mode (fixed from procedure — no switching) ─────────────────────────────
  late final String _mode; // 'Continuous' | 'Footswitch' | 'Endovorus'

  // ── Parameters ─────────────────────────────────────────────────────────────
  int _powerWatts = 50;
  int _timerMinutes = 5; // Continuous only (minutes)
  int _timerSeconds = 60; // Footswitch / Endovorus (seconds)
  double _pumpFlow = 5.0; // Endovorus pump flow rate (0–15 m/s)

  // ── State machine ──────────────────────────────────────────────────────────
  bool _isPumpOn = false;
  bool _isOvenOn = false;
  bool _isMuted = false;
  bool _footswitchActive = false;

  // ── Pump waiting state (for footswitch/endo: pump waits for foot-switch) ───
  bool _pumpWaiting = false; // pump button pressed, awaiting footswitch signal

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _ovenTimer;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  int _cycleCount = 1;

  // ── Serial service ─────────────────────────────────────────────────────────
  final _serial = SerialService.instance;
  StreamSubscription<SerialCommand>? _serialSub;

  // ── Sensor values (from serial) ────────────────────────────────────────────
  double _shaftTemp = 0.0;
  double _edgeTemp = 0.0;
  double _voltage = 0.0;

  // ── Graph history ──────────────────────────────────────────────────────────
  static const int _maxPts = 80;
  final List<double> _shaftHist = [];
  final List<double> _edgeHist = [];
  final List<double> _voltageHist = [];

  // ── Logs ───────────────────────────────────────────────────────────────────
  final List<_LogEntry> _logs = [];

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _beepFlash = false;

  // ── Timestamps (for future log enrichment) ──────────────────────────────
  DateTime? _pumpOnAt;
  DateTime? _ovenOnAt;

  @override
  void initState() {
    super.initState();
    _mode = _modeLabel(widget.procedure?.mode);
    _remainingSeconds = _isFootswitchMode(_mode) || _isEndoMode(_mode)
        ? _timerSeconds
        : _timerMinutes * 60;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Subscribe to serial data stream
    _serialSub = _serial.dataStream.listen(_onSerialData);

    // Send start procedure command
    if (_serial.isConnected) {
      _serial.sendStartProcedure();
      _log('Serial: Sent START (11) to device.', level: 'success');
    } else {
      _log('Serial not connected — running in offline mode.', level: 'warning');
    }

    _log('System initialized — ${_mode} mode ready.', level: 'success');
    _log(
      'Power: $_powerWatts W  |  Timer: ${_timerDisplayStr()}',
      level: 'info',
    );
  }

  @override
  void dispose() {
    _serialSub?.cancel();
    _ovenTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Serial data handler ────────────────────────────────────────────────────
  void _onSerialData(SerialCommand cmd) {
    if (!mounted) return;
    setState(() {
      switch (cmd.type) {
        case SerialCommandType.shaftTemp:
          _shaftTemp = cmd.value;
          void pushHist(List<double> h, double v) {
            if (h.length >= _maxPts) h.removeAt(0);
            h.add(v);
          }
          pushHist(_shaftHist, _shaftTemp);
          break;
        case SerialCommandType.edgeTemp:
          _edgeTemp = cmd.value;
          void pushHist(List<double> h, double v) {
            if (h.length >= _maxPts) h.removeAt(0);
            h.add(v);
          }
          pushHist(_edgeHist, _edgeTemp);
          break;
        case SerialCommandType.voltage:
          _voltage = cmd.value;
          void pushHist(List<double> h, double v) {
            if (h.length >= _maxPts) h.removeAt(0);
            h.add(v);
          }
          pushHist(_voltageHist, _voltage);
          break;
        case SerialCommandType.footswitch:
          _scheduleLog('Footswitch ACTIVE (serial signal 25)', level: 'info');
          break;
        case SerialCommandType.unknown:
          if (cmd.raw != null) {
            _scheduleLog('Serial unknown: ${cmd.raw}', level: 'warning');
          }
          break;
      }
    });
  }

  // ── Logging ────────────────────────────────────────────────────────────────
  void _log(String msg, {String level = 'info'}) {
    final n = DateTime.now();
    final t =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, _LogEntry(time: t, message: msg, level: level));
      if (_logs.length > 120) _logs.removeLast();
    });
  }

  void _scheduleLog(String msg, {String level = 'info'}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _log(msg, level: level);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmt(int s) {
    if (s < 0) return '--:--';
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String _timerDisplayStr() {
    if (_mode == 'Continuous') return '$_timerMinutes min';
    return '$_timerSeconds s';
  }

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

  // ── Pump control ───────────────────────────────────────────────────────────
  // Endovorus / Footswitch: clicking pump button puts it in "waiting" state.
  //   When footswitch signal arrives → pump activates automatically.
  // Continuous: pump can toggle freely (no footswitch dependency).
  //
  // Oven always requires pump to be ON first (all modes).
  void _togglePump() {
    if (_isPumpOn) {
      // Turn pump off (always allowed)
      setState(() {
        _isPumpOn = false;
        _pumpWaiting = false;
      });
      _serial.sendPump(false);
      _log('PUMP OFF', level: 'info');
      _pumpOnAt = null;
      return;
    }

    if (_pumpWaiting) {
      // Cancel waiting state
      setState(() => _pumpWaiting = false);
      _log('Pump wait cancelled.', level: 'info');
      return;
    }

    // Toggle pump immediately for all modes
    setState(() {
      _isPumpOn = true;
      _pumpOnAt = DateTime.now();
    });
    _serial.sendPump(true);
    _log('PUMP ON — Power: $_powerWatts W', level: 'warning');
  }

  // ── Oven control ───────────────────────────────────────────────────────────
  // All modes: oven can only start if pump is ON.
  void _toggleOven() {
    // Continuous/Footswitch: oven requires pump ON.
    // Endovorus: oven requires pump OFF (mutually exclusive).
    if (!_isEndoMode(_mode) && !_isPumpOn) return;
    if (_isEndoMode(_mode) && _isPumpOn) return;

    _isOvenOn ? _stopOven() : _startOven();
  }

  void _startOven() {
    final initSecs = _mode == 'Continuous' ? _timerMinutes * 60 : _timerSeconds;
    setState(() {
      _isOvenOn = true;
      _elapsedSeconds = 0;
      // Do NOT reset _cycleCount here — only reset on End Procedure
      _remainingSeconds = initSecs;
      _shaftHist.clear();
      _edgeHist.clear();
      _voltageHist.clear();
    });
    _ovenOnAt = DateTime.now();

    // Send oven ON command via serial
    if (_mode == 'Continuous') {
      _serial.sendOvenContinuous(true);
    } else {
      _serial.sendOvenFootswitch(true);
    }
    _log('OVEN ON — Power: $_powerWatts W | Mode: $_mode', level: 'warning');

    _ovenTimer?.cancel();
    _ovenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isOvenOn) return;

        final shouldTick = true;

        setState(() {
          _elapsedSeconds++;

          // Beep
          if (!_isMuted && shouldTick) {
            _beepFlash = !_beepFlash;
            SystemSound.play(SystemSoundType.click);
          } else {
            _beepFlash = false;
          }

          // Countdown
          if (shouldTick) {
            _remainingSeconds = math.max(0, _remainingSeconds - 1);
            if (_remainingSeconds <= 0) {
              if (_isFootswitchMode(_mode) || _isEndoMode(_mode)) {
                _cycleCount++;
                _remainingSeconds = _timerSeconds;
                _scheduleLog('Cycle $_cycleCount ready.', level: 'success');
              }
              // Auto stop oven and pump
              _isOvenOn = false;
              _ovenTimer?.cancel();
              _beepFlash = false;
              _footswitchActive = false;
              _isPumpOn = false;
              _pumpWaiting = false;
              _pumpOnAt = null;
              _ovenOnAt = null;
              // Send oven OFF via serial
              if (_mode == 'Continuous') {
                _serial.sendOvenContinuous(false);
              } else {
                _serial.sendOvenFootswitch(false);
              }
              _serial.sendPump(false);
              _scheduleLog(
                'Timer complete — System auto-stopped (Oven & Pump OFF).',
                level: 'warning',
              );
            }
          }
        });
      });
    });
  }

  void _stopOven() {
    _ovenTimer?.cancel();
    setState(() {
      _isOvenOn = false;
      _beepFlash = false;
      _footswitchActive = false;
    });
    // Send oven OFF via serial
    if (_mode == 'Continuous') {
      _serial.sendOvenContinuous(false);
    } else {
      _serial.sendOvenFootswitch(false);
    }
    _log('OVEN OFF — Elapsed: ${_fmt(_elapsedSeconds)}', level: 'info');
    _ovenOnAt = null;
  }

  // ── Footswitch state is driven exclusively by serial signal 25 ─────────────

  // ── End Procedure ──────────────────────────────────────────────────────────
  Future<void> _endProcedure() async {
    if (_isOvenOn) _stopOven();
    if (_isPumpOn || _pumpWaiting) {
      setState(() {
        _isPumpOn = false;
        _pumpWaiting = false;
        _pumpOnAt = null;
      });
      _serial.sendPump(false);
    }
    // Reset cycle count on procedure end
    setState(() => _cycleCount = 1);
    _log('Procedure ended by user.', level: 'warning');

    if (widget.procedure != null) {
      final logJson = jsonEncode(_logs.map((e) => e.toJson()).toList());
      widget.procedure!.endTime = DateTime.now().toIso8601String();
      widget.procedure!.status = 'Completed';
      widget.procedure!.procedureLog = logJson;
      await ProcedureRepository.updateProcedure(widget.procedure!);
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) Navigator.of(context).pop();
  }

  void _confirmEnd() {
    if (!_isPumpOn && !_isOvenOn && !_pumpWaiting) {
      _endProcedure();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'End Procedure',
        message:
            'Hardware is still running. All hardware will be stopped and the log saved. Continue?',
        confirmLabel: 'End Procedure',
        confirmColor: _kRed,
        onConfirm: _endProcedure,
      ),
    );
  }

  void _showExitEndoDialog() {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Exit Endovorus Mode',
        message: 'This will stop the oven and pump. Are you sure?',
        confirmLabel: 'Exit',
        confirmColor: _kOrange,
        onConfirm: () {
          if (_isOvenOn) _stopOven();
          if (_isPumpOn || _pumpWaiting) {
            setState(() {
              _isPumpOn = false;
              _pumpWaiting = false;
            });
            _serial.sendPump(false);
          }
          _log('Exited Endovorus mode controls.', level: 'warning');
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD — strict no-scroll layout
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _buildMetricsRow(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left: parameters
                              Expanded(flex: 5, child: _buildParametersPanel()),
                              const SizedBox(width: 12),
                              // Right: controls + graphs
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildControlButtons(),
                                    if (_isFootswitchMode(_mode) ||
                                        _isEndoMode(_mode)) ...[
                                      const SizedBox(height: 10),
                                      _buildCycleCountRow(),
                                    ],
                                    const SizedBox(height: 10),
                                    Expanded(child: _buildGraphsPanel()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUMP WAITING BANNER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPumpWaitingBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: _kAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAmber.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          _PulsingDot(color: _kAmber),
          const SizedBox(width: 10),
          const Icon(
            Icons.electrical_services_rounded,
            size: 16,
            color: _kAmber,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'PUMP WAITING — Activate footswitch to start pump',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kAmber,
              ),
            ),
          ),
          GestureDetector(
            onTap: _togglePump, // cancel waiting
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kAmber.withOpacity(0.4)),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAmber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final proc = widget.procedure;
    final startTime = proc?.startTime != null
        ? DateTime.tryParse(proc!.startTime)
        : null;
    final startStr = startTime != null
        ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return UnifiedHeader(
      title: 'Active Ablation',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status badge
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, ch) =>
                Opacity(opacity: _isOvenOn ? _pulseAnim.value : 1.0, child: ch),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (_isOvenOn
                            ? _kRed
                            : (_isPumpOn || _pumpWaiting)
                            ? _kGreen
                            : _kSubText)
                        .withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOvenOn
                      ? _kRed
                      : (_isPumpOn || _pumpWaiting)
                      ? _kGreen
                      : _kSubText,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _isOvenOn
                          ? _kRed
                          : (_isPumpOn || _pumpWaiting)
                          ? _kGreen
                          : _kSubText,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isOvenOn
                        ? 'ABLATING'
                        : _isPumpOn
                        ? 'PUMP ON'
                        : _pumpWaiting
                        ? 'PUMP WAIT'
                        : 'STANDBY',
                    style: TextStyle(
                      color: _isOvenOn
                          ? _kRed
                          : (_isPumpOn || _pumpWaiting)
                          ? _kGreen
                          : _kSubText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPurple.withOpacity(0.5)),
            ),
            child: Text(
              _mode.toUpperCase(),
              style: const TextStyle(
                color: _kPurple,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          if (proc != null) ...[
            const SizedBox(width: 10),
            _vDiv(),
            _hChip('Patient', proc.patientName),
            _vDiv(),
            _hChip('Area', proc.category.isNotEmpty ? proc.category : 'N/A'),
            _vDiv(),
            _hChip('Start', startStr),
            _vDiv(),
            _hChip('Physician', proc.initiatedByUserName),
          ],
        ],
      ),
    );
  }

  Widget _vDiv() => Container(
    width: 1,
    height: 26,
    color: Colors.grey.shade300,
    margin: const EdgeInsets.symmetric(horizontal: 14),
  );
  Widget _hChip(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1B2332),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SIDEBAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final proc = widget.procedure;
    return Container(
      width: 230,
      color: _kNavyLight,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient
          _sideBlock('PATIENT', Icons.person_outline, _kBlue, [
            _sRow('Name', proc?.patientName ?? 'N/A'),
            _sRow('ID', proc?.patientId ?? 'N/A'),
            _sRow('Area', proc?.category ?? 'N/A'),
          ]),
          const SizedBox(height: 10),
          // Procedure
          _sideBlock('PROCEDURE', Icons.science_outlined, _kPurple, [
            _sRow('Antenna', proc?.antenna ?? 'N/A'),
            _sRow(
              'Serial',
              (proc != null && proc.antennaSerialNumber.isNotEmpty)
                  ? proc.antennaSerialNumber
                  : 'N/A',
            ),
            _sRow('Mode', _mode),
            _sRow('Power', '$_powerWatts W'),
          ]),
          const SizedBox(height: 10),
          // Log
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 12, color: _kGreen),
                      const SizedBox(width: 5),
                      const Text(
                        'SYSTEM LOG',
                        style: TextStyle(
                          color: _kGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _logs.clear()),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No events.',
                              style: TextStyle(color: _kSubText, fontSize: 10),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (_, i) {
                              final e = _logs[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.time,
                                      style: const TextStyle(
                                        color: _kSubText,
                                        fontSize: 8,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(top: 3),
                                      decoration: BoxDecoration(
                                        color: _logColor(e.level),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        e.message,
                                        style: TextStyle(
                                          color: i == 0
                                              ? Colors.white
                                              : Colors.white54,
                                          fontSize: 9,
                                          fontWeight: i == 0
                                              ? FontWeight.w700
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
            ),
          ),
          const SizedBox(height: 10),
          // Status bottom strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _isOvenOn
                  ? _kRed.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isOvenOn
                    ? _kRed.withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isOvenOn
                      ? Icons.local_fire_department
                      : _isPumpOn
                      ? Icons.water_drop
                      : _pumpWaiting
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_outline,
                  color: _isOvenOn
                      ? _kRed
                      : (_isPumpOn || _pumpWaiting)
                      ? _kGreen
                      : _kSubText,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _isOvenOn
                      ? 'Ablation Active'
                      : _isPumpOn
                      ? 'Pump Running'
                      : _pumpWaiting
                      ? 'Pump Waiting…'
                      : 'System Ready',
                  style: TextStyle(
                    color: _isOvenOn
                        ? _kRed
                        : (_isPumpOn || _pumpWaiting)
                        ? _kGreen
                        : _kSubText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideBlock(
    String title,
    IconData icon,
    Color color,
    List<Widget> rows,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ...rows,
      ],
    ),
  );

  Widget _sRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        Text(l, style: const TextStyle(color: _kSubText, fontSize: 10)),
        const Spacer(),
        Flexible(
          child: Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // METRICS ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMetricsRow() {
    final shaftColor = _shaftTemp > 80 ? _kRed : _kAmber;
    final metrics = <_MDef>[
      _MDef(
        'Shaft Temp',
        _shaftTemp.toStringAsFixed(1),
        '°C',
        shaftColor,
        Icons.thermostat,
      ),
      _MDef(
        'Edge Temp',
        _edgeTemp.toStringAsFixed(1),
        '°C',
        _kGreen,
        Icons.device_thermostat,
      ),
      _MDef('Power', _voltage.toStringAsFixed(1), 'W', _kPurple, Icons.bolt),
      _MDef('Elapsed', _fmt(_elapsedSeconds), '', _kBlue, Icons.timer_outlined),
      if (_mode == 'Continuous')
        _MDef(
          'Remaining',
          _isOvenOn ? _fmt(_remainingSeconds) : '--:--',
          '',
          _kRed,
          Icons.hourglass_bottom_rounded,
        )
      else
        _MDef(
          'Cycle Timer',
          _fmt(_remainingSeconds),
          '',
          _kRed,
          Icons.replay_outlined,
        ),
    ];

    return SizedBox(
      height: 180,
      child: Row(
        children: metrics
            .map(
              (m) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _MetricCard(def: m, active: _isOvenOn),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PARAMETERS PANEL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildParametersPanel() {
    // Parameters are locked only while the oven (ablation) is actively running.
    final locked = _isOvenOn;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 16, color: _kBlue),
              ),
              const SizedBox(width: 10),
              const Text(
                'Parameters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                ),
              ),
              const Spacer(),
              if (locked) _LockBadge(),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 14),
          // Power
          Expanded(
            child: _BigParamControl(
              label: 'Output Power',
              icon: Icons.bolt,
              color: _kBlue,
              value: _powerWatts,
              unit: 'W',
              hint: '5 – 150 W',
              min: 5,
              max: 150,
              step: 5,
              locked: locked,
              onChanged: (v) {
                setState(() => _powerWatts = v);
                _serial.sendPower(v);
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 12),
          // Timer
          Expanded(
            child: _BigParamControl(
              label: _mode == 'Continuous' ? 'Duration' : 'Cycle Timer',
              icon: Icons.timer_outlined,
              color: _kGreen,
              value: _mode == 'Continuous' ? _timerMinutes : _timerSeconds,
              unit: _mode == 'Continuous' ? 'min' : 's',
              hint: _mode == 'Continuous' ? '1 – 60 min' : '10 – 300 s',
              min: _mode == 'Continuous' ? 1 : 10,
              max: _mode == 'Continuous' ? 60 : 300,
              step: _mode == 'Continuous' ? 1 : 10,
              locked: locked,
              onChanged: (v) {
                setState(() {
                  if (_mode == 'Continuous') {
                    _timerMinutes = v;
                    if (!_isOvenOn) _remainingSeconds = v * 60;
                  } else {
                    _timerSeconds = v;
                    if (!_isOvenOn) _remainingSeconds = v;
                  }
                });
                final secs = _mode == 'Continuous' ? v * 60 : v;
                _serial.sendTimer(secs);
              },
            ),
          ),
          // Pump flow (Endovorus only) — 0–15 m/s
          if (_isEndoMode(_mode)) ...[
            const SizedBox(height: 12),
            const Divider(color: _kBorder, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: _BigParamControl(
                label: 'Pump Flow Rate',
                icon: Icons.water_drop_outlined,
                color: _kOrange,
                value: _pumpFlow.toInt(),
                unit: 'm/s',
                hint: '0 – 15 m/s',
                min: 0,
                max: 15,
                step: 1,
                locked: locked,
                onChanged: (v) {
                  setState(() => _pumpFlow = v.toDouble());
                  _serial.sendPumpFlowRate(v);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROL BUTTONS (Pump + Oven — same visual weight)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildControlButtons() {
    // Pump logic:
    //   - Endovorus: clicking pump enters "waiting" state (auto-activates when footswitch fires).
    //   - Continuous/Footswitch: pump toggles immediately.
    //   - Pump is disabled if oven is ON.
    //
    // Oven logic:
    //   - Continuous/Footswitch: Oven can only start if pump is ON.
    //   - Endovorus: Oven and Pump are mutually exclusive (oven requires pump OFF).

    final bool pumpEnabled = !_isOvenOn;
    final bool ovenEnabled = _isEndoMode(_mode) ? !_isPumpOn : _isPumpOn;

    // Pump button label
    String pumpLabel;
    if (_isPumpOn) {
      pumpLabel = 'TURN OFF PUMP';
    } else if (_pumpWaiting) {
      pumpLabel = 'WAITING…';
    } else {
      pumpLabel = 'TURN ON PUMP';
    }

    // Pump status line
    String pumpStatus;
    if (_isOvenOn) {
      pumpStatus = 'Oven is active';
    } else if (_isPumpOn) {
      if (_isEndoMode(_mode)) {
        pumpStatus = 'Running at ${_pumpFlow.toInt()} m/s';
      } else {
        pumpStatus = 'Pump running';
      }
    } else if (_pumpWaiting) {
      pumpStatus = 'Activate footswitch…';
    } else {
      pumpStatus = 'Pump is off';
    }

    // Oven status line
    String ovenStatus;
    if (_isOvenOn) {
      ovenStatus = 'Ablation in progress';
    } else if (_isEndoMode(_mode)) {
      ovenStatus = _isPumpOn ? 'Stop pump first' : 'Ready to start';
    } else {
      ovenStatus = _isPumpOn ? 'Ready to start' : 'Start pump first';
    }

    // Oven disabled hint
    String ovenDisabledHint;
    if (_isEndoMode(_mode)) {
      ovenDisabledHint = 'Stop pump first';
    } else {
      ovenDisabledHint = 'Start pump first';
    }

    return Row(
      children: [
        // ── Pump ──
        Expanded(
          child: _HardwareButton(
            label: pumpLabel,
            icon: _pumpWaiting
                ? Icons.hourglass_top_rounded
                : Icons.water_drop_rounded,
            active: _isPumpOn || _pumpWaiting,
            activeColor: _pumpWaiting ? _kAmber : _kOrange,
            inactiveColor: _kGreen,
            enabled: pumpEnabled,
            disabledHint: _isOvenOn ? 'Stop oven first' : null,
            onTap: _togglePump,
            statusLine: pumpStatus,
            pulseAnim: (_isPumpOn || _pumpWaiting) ? _pulseAnim : null,
          ),
        ),
        const SizedBox(width: 10),
        // ── Oven ──
        Expanded(
          child: _HardwareButton(
            label: _isOvenOn ? 'STOP OVEN' : 'START',
            icon: Icons.microwave_outlined,
            active: _isOvenOn,
            activeColor: _kRed,
            inactiveColor: _kNavy,
            enabled: ovenEnabled,
            disabledHint: !ovenEnabled ? ovenDisabledHint : null,
            onTap: _toggleOven,
            statusLine: ovenStatus,
            pulseAnim: _isOvenOn ? _pulseAnim : null,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CYCLE COUNT ROW (Footswitch + Endovorus)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCycleCountRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _cycleCount > 1 ? _kPurple.withOpacity(0.3) : _kBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.repeat_rounded, size: 18, color: _kPurple),
          ),
          const SizedBox(width: 12),
          const Text(
            'Current Cycle',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kNavy,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: _kPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kPurple.withOpacity(0.25)),
            ),
            child: Text(
              '# $_cycleCount',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOOTSWITCH STATUS (read-only — driven by serial command 25)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFootswitchStatus() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: _footswitchActive
            ? _kGreen.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _footswitchActive ? _kGreen : _kBorder,
          width: _footswitchActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.electrical_services_rounded,
            size: 12,
            color: _kSubText,
          ),
          const SizedBox(width: 6),
          const Text(
            'FOOTSWITCH',
            style: TextStyle(
              fontSize: 10,
              color: _kSubText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Icon(
            _footswitchActive ? Icons.touch_app : Icons.touch_app_outlined,
            size: 18,
            color: _footswitchActive ? _kGreen : _kSubText,
          ),
          const SizedBox(width: 8),
          Text(
            _footswitchActive
                ? 'ACTIVE — timer counting'
                : 'Waiting for signal 25…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _footswitchActive ? _kGreen : _kSubText,
            ),
          ),
          if (_footswitchActive) ...[
            const SizedBox(width: 8),
            _PulsingDot(color: _kGreen),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GRAPHS PANEL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGraphsPanel() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  size: 16,
                  color: _kPurple,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Live Sensor Graphs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                ),
              ),
              const Spacer(),
              if (_isOvenOn)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: _kGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Power graph with set-power reference line
          Expanded(
            child: _MiniGraph(
              label: 'Power',
              unit: 'W',
              data: _voltageHist,
              color: _kPurple,
              current: _voltage,
              setPower: _powerWatts.toDouble(), // set-power reference line
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          // Mute toggle
          _BarBtn(
            label: _isMuted ? 'Unmute Sound' : 'Mute Sound',
            icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            active: _isMuted,
            activeColor: _kAmber,
            onTap: () => setState(() => _isMuted = !_isMuted),
          ),
          const SizedBox(width: 10),
          // Beep flash
          if (_isOvenOn && !_isMuted && _beepFlash)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _kRed.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, color: _kRed, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'BEEP',
                    style: TextStyle(
                      color: _kRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _confirmEnd,
            icon: const Icon(
              Icons.stop_circle_outlined,
              color: _kNavy,
              size: 16,
            ),
            label: const Text(
              'End Procedure',
              style: TextStyle(
                color: _kNavy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              side: const BorderSide(color: _kBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Big Parameter Control Widget
// ─────────────────────────────────────────────────────────────────────────────
class _BigParamControl extends StatelessWidget {
  final String label, unit, hint;
  final IconData icon;
  final Color color;
  final int value, min, max, step;
  final bool locked;
  final Function(int) onChanged;

  const _BigParamControl({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.hint,
    required this.min,
    required this.max,
    required this.step,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: locked ? _kSubText : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: locked ? _kSubText : _kNavy,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: (locked ? _kSubText : color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value $unit',
                style: TextStyle(
                  color: locked ? _kSubText : color,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Decrease
            _BigStepBtn(
              icon: Icons.remove_rounded,
              color: color,
              enabled: !locked && value > min,
              onTap: () => onChanged(value - step),
            ),
            // Progress bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 24,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          locked ? _kSubText.withOpacity(0.3) : color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _kSubText,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(pct * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: locked ? _kSubText : color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Increase
            _BigStepBtn(
              icon: Icons.add_rounded,
              color: color,
              enabled: !locked && value < max,
              onTap: () => onChanged(value + step),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigStepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _BigStepBtn({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? color.withOpacity(0.25) : _kBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 30,
          color: enabled ? color : _kSubText.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hardware Button (Pump / Oven — same style)
// ─────────────────────────────────────────────────────────────────────────────
class _HardwareButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor, inactiveColor;
  final bool enabled;
  final String? disabledHint;
  final String statusLine;
  final VoidCallback onTap;
  final Animation<double>? pulseAnim;

  const _HardwareButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.enabled,
    required this.statusLine,
    required this.onTap,
    this.disabledHint,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = active
        ? activeColor
        : enabled
        ? inactiveColor
        : _kSubText;
    Widget btn = GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: enabled
              ? effectiveColor.withOpacity(active ? 0.12 : 0.07)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? effectiveColor.withOpacity(active ? 0.5 : 0.25)
                : _kBorder,
            width: active ? 2 : 1,
          ),
          boxShadow: active && enabled
              ? [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: enabled ? effectiveColor : _kSubText),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: enabled ? effectiveColor : _kSubText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              !enabled && disabledHint != null ? disabledHint! : statusLine,
              style: TextStyle(
                fontSize: 12,
                color: active ? effectiveColor.withOpacity(0.8) : _kSubText,
              ),
            ),
          ],
        ),
      ),
    );

    if (pulseAnim != null) {
      return AnimatedBuilder(
        animation: pulseAnim!,
        builder: (_, child) =>
            Transform.scale(scale: pulseAnim!.value, child: child),
        child: btn,
      );
    }
    return btn;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini Graph  (auto-scaling Y axis + set-power reference line)
// ─────────────────────────────────────────────────────────────────────────────
class _MiniGraph extends StatelessWidget {
  final String label, unit;
  final List<double> data;
  final Color color;
  final double current;
  final double? setPower; // optional reference line (watts)

  const _MiniGraph({
    required this.label,
    required this.unit,
    required this.data,
    required this.color,
    required this.current,
    this.setPower,
  });

  @override
  Widget build(BuildContext context) {
    // Auto-scale: derive minY / maxY from the actual data with 10 % padding.
    double minY = 0, maxY = 1;
    if (data.isNotEmpty) {
      minY = data.reduce(math.min);
      maxY = data.reduce(math.max);
      // Make sure the set-power line is always visible in range
      if (setPower != null) {
        if (setPower! > maxY) maxY = setPower!;
        if (setPower! < minY) minY = setPower!;
      }
      final span = (maxY - minY).abs();
      final pad = span < 1e-6 ? 1.0 : span * 0.15; // flat-line guard
      minY -= pad;
      maxY += pad;
    } else if (setPower != null) {
      // No data yet, but show set-power line
      minY = 0;
      maxY = setPower! * 1.3;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
            ),
            if (setPower != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kOrange.withOpacity(0.3)),
                ),
                child: Text(
                  'Set: ${setPower!.toInt()} $unit',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _kOrange,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              '${current.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withOpacity(0.12)),
            ),
            child: data.length < 2
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (setPower != null)
                          Text(
                            'Set: ${setPower!.toInt()} $unit',
                            style: TextStyle(
                              color: _kOrange.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Waiting for data…',
                          style: TextStyle(color: _kSubText, fontSize: 10),
                        ),
                      ],
                    ),
                  )
                : SizedBox.expand(
                    child: CustomPaint(
                      painter: _LinePainter(
                        data: List<double>.from(data),
                        color: color,
                        minY: minY,
                        maxY: maxY,
                        setPower: setPower,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double minY, maxY;
  final double? setPower;

  const _LinePainter({
    required this.data,
    required this.color,
    required this.minY,
    required this.maxY,
    this.setPower,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final range = maxY - minY;
    if (range == 0) return;

    const pad = 6.0;
    final drawH = size.height - pad * 2;

    double yForVal(double v) =>
        size.height - pad - ((v - minY) / range).clamp(0.0, 1.0) * drawH;

    // ── Draw set-power reference line ────────────────────────────────────────
    if (setPower != null) {
      final lineY = yForVal(setPower!);
      final dashPaint = Paint()
        ..color = _kOrange.withOpacity(0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Dashed line
      const dashLen = 6.0;
      const gapLen = 4.0;
      double x = 0;
      while (x < size.width) {
        final end = math.min(x + dashLen, size.width);
        canvas.drawLine(Offset(x, lineY), Offset(end, lineY), dashPaint);
        x += dashLen + gapLen;
      }

      // Label on right side
      final tp = TextPainter(
        text: TextSpan(
          text: '${setPower!.toInt()} W',
          style: TextStyle(
            color: _kOrange.withOpacity(0.9),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width - tp.width - 4, lineY - tp.height - 2),
      );
    }

    // ── Draw data line ───────────────────────────────────────────────────────
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final step = size.width / (data.length - 1);

    final path = Path();
    final fill = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = yForVal(data[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo((data.length - 1) * step, size.height);
    fill.close();

    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, paint);

    // Current-value dot at the rightmost point
    final lx = (data.length - 1) * step;
    final ly = yForVal(data.last);
    canvas.drawCircle(Offset(lx, ly), 3.5, Paint()..color = color);
    canvas.drawCircle(
      Offset(lx, ly),
      3.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.data.length != data.length ||
      old.color != color ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.setPower != setPower;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _MDef {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _MDef(this.label, this.value, this.unit, this.color, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _MDef def;
  final bool active;
  const _MetricCard({required this.def, required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: active ? def.color.withOpacity(0.25) : _kBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: def.color.withOpacity(active ? 0.07 : 0.0),
          blurRadius: 10,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(def.icon, size: 24, color: def.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                def.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kSubText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              def.value,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: def.color,
                height: 1,
              ),
            ),
            if (def.unit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  def.unit,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _kSubText,
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

class _LockBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _kAmber.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _kAmber.withOpacity(0.3)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_rounded, size: 11, color: _kAmber),
        SizedBox(width: 4),
        Text(
          'LOCKED',
          style: TextStyle(
            color: _kAmber,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
}

class _BarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;
  const _BarBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor = _kBlue,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active ? activeColor.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? activeColor.withOpacity(0.3) : _kBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: active ? activeColor : _kNavy),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? activeColor : _kNavy,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _a = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(_a.value),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: confirmColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    ),
    content: Text(
      message,
      style: const TextStyle(fontSize: 13, color: _kSubText),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel', style: TextStyle(color: _kSubText)),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          onConfirm();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          confirmLabel,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
