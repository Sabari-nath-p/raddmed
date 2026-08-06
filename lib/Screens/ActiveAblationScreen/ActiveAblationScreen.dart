import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raddmed/Models/ProcedureModel.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Services/SerialService.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';

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
const _kTeal = Color(0xFF0EA5A5);

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
  int _pumpFlow = 5; // Endovorus pump flow rate (0–250 L/min)
  int _shaftTempTarget = 60; // NEW: Shaft temperature target (°C)
  int _edgeTempTarget = 60; // NEW: Edge temperature target (°C)

  // ── SET button tracking (must press SET before pump can turn on) ───────────
  bool _powerSet = false;
  bool _timerSet = false;
  bool _flowSet = false; // Endovorus only
  bool _shaftTempSet = false; // NEW
  bool _edgeTempSet = false; // NEW

  // ── State machine ──────────────────────────────────────────────────────────
  bool _isPumpOn = false;
  bool _isOvenOn = false;
  bool _isPaused = false; // NEW: Continuous-mode pause state
  bool _isMuted = false;
  bool _footswitchActive = false;

  // ── Pump waiting state: in footswitch mode, pump is on but oven awaits footswitch
  bool _pumpWaiting = false;

  // ── Footswitch oven pending: pump ON, waiting for footswitch to start oven ─
  bool _awaitingFootswitch =
      false; // footswitch mode: pump on, oven not yet started

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

  // ── Logs (kept for procedure-log persistence; preview widget removed) ──────
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

    // Send activation command on screen open:
    //   1100 → Continuous mode
    //   1101 → Footswitch or Endovascular mode

    final isFootOrEndo = _isFootswitchMode(_mode) || _isEndoMode(_mode);
    _serial.sendActivation(isFootOrEndo);
    _log(
      'Serial: Sent ACTIVATION (${isFootOrEndo ? '1101' : '1100'}) to device.',
      level: 'success',
    );

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
    // TEMPORARY DEBUG: beep + snackbar on every raw serial receive, showing
    // the value exactly as it arrived on the wire (no hex/decimal parsing
    // applied) so mis-decoded readings can be spotted against RealTerm.
    // Remove once the hex-parsing path is confirmed correct on hardware.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RAW: ${cmd.raw ?? "(no raw)"}  [${cmd.type.name}]'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
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

          // ── Endovascular: footswitch turns PUMP ON (phase 1) ──
          if (_isEndoMode(_mode) && _pumpWaiting && !_isPumpOn) {
            _scheduleLog(
              'Footswitch received — Pump turning ON.',
              level: 'success',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _pumpWaiting = false;
                _isPumpOn = true;
                _pumpOnAt = DateTime.now();
              });
              // Endovascular pump is driven by the flow-rate command, not
              // the generic pump on/off command — send the real flow value.
              _serial.sendPumpFlowRate(_pumpFlow.toDouble());
              _log(
                'PUMP ON (footswitch triggered) — sent Flow Rate $_pumpFlow L/min',
                level: 'warning',
              );
            });
            break;
          }

          // ── Endovascular: footswitch starts OVEN (phase 2, pump already OFF) ──
          if (_isEndoMode(_mode) &&
              _awaitingFootswitch &&
              !_isPumpOn &&
              !_isOvenOn) {
            _awaitingFootswitch = false;
            _scheduleLog(
              'Footswitch received — starting oven.',
              level: 'success',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _startOven();
            });
            break;
          }

          // ── Footswitch mode: footswitch starts OVEN ──
          if (_isFootswitchMode(_mode) &&
              _isPumpOn &&
              !_isOvenOn &&
              _awaitingFootswitch) {
            _awaitingFootswitch = false;
            _scheduleLog(
              'Footswitch received — starting oven.',
              level: 'success',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _startOven();
            });
          }
          break;
        case SerialCommandType.unknown:
          if (cmd.raw != null) {
            _scheduleLog('Serial unknown: ${cmd.raw}', level: 'warning');
          }
          break;
      }
    });
  }

  // ── Logging (kept for procedure-log persistence) ───────────────────────────
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

  // ── Beep sound handling ─────────────────────────────────────────────────
  // Uses native OS system sounds via dart:io Process.run — no asset files
  // required. Platform dispatch:
  //   macOS   → afplay on built-in /System/Library/Sounds/*.aiff files
  //   Windows → PowerShell [console]::Beep(freq, ms)
  //   Linux   → paplay on freedesktop system sounds (best-effort)
  // If the process call fails for any reason, falls back to SystemSound.
  Future<void> _playBeep({bool long = false}) async {
    try {
      if (Platform.isMacOS) {
        if (long) {
          // Play two system sounds back-to-back for a distinct "end" alert.
          await Process.run('afplay', ['/System/Library/Sounds/Glass.aiff']);
          await Future.delayed(const Duration(milliseconds: 100));
          await Process.run('afplay', ['/System/Library/Sounds/Glass.aiff']);
        } else {
          await Process.run('afplay', ['/System/Library/Sounds/Tink.aiff']);
        }
      } else if (Platform.isWindows) {
        if (long) {
          // Three high-pitched beeps to signal timer end.
          await Process.run('powershell', ['-c', '[console]::Beep(1000,400)']);
          await Future.delayed(const Duration(milliseconds: 100));
          await Process.run('powershell', ['-c', '[console]::Beep(1000,400)']);
          await Future.delayed(const Duration(milliseconds: 100));
          await Process.run('powershell', ['-c', '[console]::Beep(1200,600)']);
        } else {
          // Short tick beep every second.
          await Process.run('powershell', ['-c', '[console]::Beep(800,200)']);
        }
      } else if (Platform.isLinux) {
        final sound = long ? 'complete' : 'audio-volume-change';
        await Process.run('paplay', [
          '--property=media.role=event',
          '/usr/share/sounds/freedesktop/stereo/$sound.oga',
        ]);
      } else {
        // Generic fallback for any other platform.
        SystemSound.play(long ? SystemSoundType.alert : SystemSoundType.click);
      }
    } catch (_) {
      // If the OS command fails (sound not found, permission, etc.)
      // fall back to Flutter's built-in system sound.
      SystemSound.play(long ? SystemSoundType.alert : SystemSoundType.click);
    }
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

  // ── Pump control ───────────────────────────────────────────────────────────
  // Continuous:  pump turns ON immediately after SET; oven requires pump ON.
  // Footswitch:  pump turns ON immediately; oven armed by button + footswitch.
  // Endovascular:
  //   Phase 1 — click Pump → wait for footswitch → pump turns ON.
  //   Phase 2 — pump OFF → click Oven → wait for footswitch → oven starts.
  void _togglePump() {
    // ── Endovascular mode ──
    if (_isEndoMode(_mode)) {
      if (_isPumpOn) {
        // Turn pump off — send flow-rate command with value 0 (this is
        // the actual "pump off" signal for this hardware).
        _serial.sendPumpFlowRate(0);

        setState(() {
          _isPumpOn = false;
          _awaitingFootswitch = false;
        });
        _log('PUMP OFF — sent Flow Rate 0 L/min', level: 'info');
        _pumpOnAt = null;
        return;
      }
      if (_pumpWaiting) {
        // Cancel the pump footswitch wait — also send Flow Rate 0 so the
        // device is explicitly told to stand down, in case it latched
        // anything while armed and waiting for the footswitch.
        _serial.sendPumpFlowRate(0);
        setState(() => _pumpWaiting = false);
        _log(
          'Pump footswitch wait cancelled — sent Flow Rate 0 L/min',
          level: 'info',
        );
        return;
      }
      // Guard: SET must be confirmed
      final canTurnOn = _powerSet && _timerSet && _flowSet;
      if (!canTurnOn) {
        _log(
          'Set Power, Timer and Flow Rate before turning on pump.',
          level: 'warning',
        );
        return;
      }

      // NOTE: Flow rate is intentionally NOT sent yet — the device only
      // receives it once the footswitch confirms the pump turning ON.
      setState(() => _pumpWaiting = true);
      _serial.sendPumpFlowRate(_pumpFlow.toDouble());

      _log(
        'Endovascular: waiting for footswitch to turn pump ON…',
        level: 'warning',
      );
      return;
    }

    // ── Continuous / Footswitch modes ──
    if (_isPumpOn) {
      // Turn pump off — also cancels any pending footswitch wait
      setState(() {
        _isPumpOn = false;
        _pumpWaiting = false;
        _awaitingFootswitch = false;
      });
      _serial.sendPump(false);
      _log('PUMP OFF', level: 'info');
      _pumpOnAt = null;
      return;
    }

    if (_pumpWaiting) {
      setState(() => _pumpWaiting = false);
      _log('Pump wait cancelled.', level: 'info');
      return;
    }

    // Guard: SET must have been pressed for power and timer.
    final canTurnOn = _powerSet && _timerSet;
    if (!canTurnOn) {
      _log('Set Power and Timer before turning on pump.', level: 'warning');
      return;
    }

    // Turn pump ON immediately
    setState(() {
      _isPumpOn = true;
      _pumpOnAt = DateTime.now();
    });
    _serial.sendPump(true);
    _log('PUMP ON — Power: $_powerWatts W', level: 'warning');
  }

  // ── Oven control ───────────────────────────────────────────────────────────
  // Continuous:   oven requires pump ON → starts immediately.
  // Footswitch:   click oven → arm → footswitch signal → oven starts.
  // Endovascular: pump must be OFF; click oven → arm → footswitch → oven starts.
  void _toggleOven() {
    // ── Footswitch mode ──
    if (_isFootswitchMode(_mode)) {
      if (_isOvenOn) {
        _stopOven();
        return;
      }
      if (_awaitingFootswitch) {
        _stopOven();

        setState(() => _awaitingFootswitch = false);
        _log('Footswitch wait cancelled.', level: 'info');
        return;
      }
      if (!_isPumpOn) return;
      setState(() => _awaitingFootswitch = true);

      _serial.sendOvenFootswitch(true);
      _log(
        'Footswitch mode: oven armed — waiting for footswitch signal…',
        level: 'warning',
      );
      return;
    }

    // ── Endovascular mode ──
    if (_isEndoMode(_mode)) {
      if (_isOvenOn) {
        _stopOven();
        return;
      }
      if (_awaitingFootswitch) {
        // Cancel oven wait — was previously re-sending "start" first due
        // to a dead branch below; now it only sends the stop command.
        _stopOven();
        setState(() => _awaitingFootswitch = false);
        _log('Oven footswitch wait cancelled.', level: 'info');
        return;
      }
      // Arm oven — wait for footswitch signal
      _serial.sendOvenFootswitch(true);
      setState(() => _awaitingFootswitch = true);
      _log(
        'Endovascular: oven armed — waiting for footswitch signal…',
        level: 'warning',
      );
      return;
    }

    if (!_isPumpOn) return;
    _isOvenOn ? _stopOven() : _startOven();
  }

  void _startOven() {
    final initSecs = _mode == 'Continuous' ? _timerMinutes * 60 : _timerSeconds;
    setState(() {
      _isOvenOn = true;
      _isPaused = false;
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

    _runOvenTimerLoop();
  }

  // Extracted so Pause/Resume (Continuous mode only) can restart the
  // countdown without resetting elapsed/remaining seconds.
  void _runOvenTimerLoop() {
    _ovenTimer?.cancel();
    _ovenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isOvenOn || _isPaused) return;

        setState(() {
          _elapsedSeconds++;

          // Countdown
          _remainingSeconds = math.max(0, _remainingSeconds - 1);

          if (_remainingSeconds <= 0) {
            _beepFlash = false;
            if (!_isMuted) _playBeep(long: true); // long beep on completion

            final bool isCyclic =
                _isFootswitchMode(_mode) || _isEndoMode(_mode);
            if (isCyclic) {
              _cycleCount++;
              _remainingSeconds = _timerSeconds;
              _scheduleLog('Cycle $_cycleCount ready.', level: 'success');
            }

            // Stop the oven for this cycle — pump handling differs by mode.
            _isOvenOn = false;
            _isPaused = false;
            _ovenTimer?.cancel();
            _beepFlash = false;
            _footswitchActive = false;
            _ovenOnAt = null;

            if (_isFootswitchMode(_mode)) {
              // Footswitch mode is cyclic: the pump was never switched
              // off by a footswitch signal, so it stays ON between
              // cycles. Only the oven stops here, then re-arms right
              // away so the next footswitch press starts the next
              // cycle directly — no need to re-press Pump/Oven.
              _serial.sendOvenFootswitch(false);
              _awaitingFootswitch = true;
              _serial.sendOvenFootswitch(true);
              _scheduleLog(
                'Cycle complete — Oven OFF (Pump still ON) — armed for next footswitch press.',
                level: 'warning',
              );
            } else if (_isEndoMode(_mode)) {
              // Endovascular mode: the pump is left running as-is — only
              // the oven stops here. (Previously the pump was force-stopped
              // via Flow Rate 0 before re-arming; no longer needed.)
              _serial.sendOvenFootswitch(false);
              _scheduleLog(
                'Timer complete — Oven OFF (Pump left running if it was on).',
                level: 'warning',
              );
            } else {
              // Continuous mode — single cycle. Only the oven stops; the
              // pump is left running as-is if it was already on.
              _serial.sendOvenContinuous(false);
              _scheduleLog(
                'Timer complete — Oven OFF (Pump left running if it was on).',
                level: 'warning',
              );
            }
          } else {
            // Regular tick beep
            if (!_isMuted) {
              _beepFlash = !_beepFlash;
              _playBeep();
            } else {
              _beepFlash = false;
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
      _isPaused = false;
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

  // ── Pause / Resume (Continuous mode only) ───────────────────────────────
  // Pausing sends an oven-OFF command and stops the countdown timer while
  // preserving elapsed/remaining seconds. Resuming re-sends oven-ON and
  // continues the countdown from where it left off. "End Procedure" stays
  // available at all times, paused or not.
  void _togglePause() {
    if (_mode != 'Continuous' || !_isOvenOn) return;

    if (!_isPaused) {
      // ── Pause ──
      _ovenTimer?.cancel();
      _serial.sendOvenContinuous(false);
      setState(() => _isPaused = true);
      _log(
        'OVEN PAUSED — Elapsed: ${_fmt(_elapsedSeconds)}  Remaining: ${_fmt(_remainingSeconds)}',
        level: 'warning',
      );
    } else {
      // ── Resume ──
      _serial.sendOvenContinuous(true);
      setState(() => _isPaused = false);
      _log(
        'OVEN RESUMED — Remaining: ${_fmt(_remainingSeconds)}',
        level: 'warning',
      );
      _runOvenTimerLoop();
    }
  }

  // ── Footswitch state is driven exclusively by serial signal 25 ─────────────

  // ── End Procedure ──────────────────────────────────────────────────────────
  Future<void> _endProcedure() async {
    if (_isOvenOn) _stopOven();
    if (_isPumpOn || _pumpWaiting) {
      setState(() {
        _isPumpOn = false;
        _pumpWaiting = false;
        _awaitingFootswitch = false;
        _pumpOnAt = null;
      });
      if (_isEndoMode(_mode)) {
        // Endovascular pump is stopped via Flow Rate 0 — send it whether
        // the pump was actually running or still waiting for the
        // footswitch, so the device is always told to stand down.
        _serial.sendPumpFlowRate(0);
      } else {
        _serial.sendPump(false);
      }
    }
    // Reset cycle count and SET flags on procedure end
    setState(() {
      _cycleCount = 1;
      _powerSet = false;
      _timerSet = false;
      _flowSet = false;
      _shaftTempSet = false;
      _edgeTempSet = false;
      _isPaused = false;
    });
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
              _awaitingFootswitch = false;
            });
            // Endovascular pump is stopped via Flow Rate 0 — send it
            // whether it was actually running or still waiting for the
            // footswitch, so the device is always told to stand down.
            _serial.sendPumpFlowRate(0);
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
                //     _buildSidebar(),
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

    final statusColor = _isPaused
        ? _kAmber
        : _isOvenOn
        ? _kRed
        : (_isPumpOn || _pumpWaiting)
        ? _kGreen
        : _kSubText;
    final statusLabel = _isPaused
        ? 'PAUSED'
        : _isOvenOn
        ? 'ABLATING'
        : _isPumpOn
        ? 'PUMP ON'
        : _pumpWaiting
        ? 'PUMP WAIT'
        : 'STANDBY';

    return UnifiedHeader(
      title: 'Active Ablation',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status badge
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, ch) => Opacity(
              opacity: (_isOvenOn && !_isPaused) ? _pulseAnim.value : 1.0,
              child: ch,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
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
  // SIDEBAR (system-log preview removed)
  // ─────────────────────────────────────────────────────────────────────────

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
          _isPaused ? _kAmber : _kRed,
          _isPaused
              ? Icons.pause_circle_outline
              : Icons.hourglass_bottom_rounded,
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
                  child: _MetricCard(def: m, active: _isOvenOn && !_isPaused),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PARAMETERS PANEL
  //   Row 1: Power | Duration
  //   Row 2: Shaft Temp Target | Edge Temp Target
  //   Row 3: Pump Flow Rate (Endovorus only)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildParametersPanel() {
    // Parameters are locked only while the oven (ablation) is actively running
    // (including while paused — the procedure is still considered in progress).
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
          const SizedBox(height: 10),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 10),

          // ── Row 1: Power | Duration ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BigParamControl(
                    label: 'Output Power',
                    icon: Icons.bolt,
                    color: _kBlue,
                    value: _powerWatts,
                    unit: 'W',
                    hint: '5–150 W',
                    min: 0,
                    max: 150,
                    step: 5,
                    locked: locked,
                    isSet: _powerSet,
                    onChanged: (v) {
                      setState(() {
                        _powerWatts = v;
                        _powerSet = false; // changing value resets SET state
                      });
                    },
                    onSet: (v) {
                      setState(() => _powerSet = true);
                      _serial.sendPower(v);
                      _log(
                        'SET Power: $v W → sent 12${v.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                        level: 'info',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigParamControl(
                    label: _mode == 'Continuous' ? 'Duration' : 'Cycle Timer',
                    icon: Icons.timer_outlined,
                    color: _kGreen,
                    value: _mode == 'Continuous'
                        ? _timerMinutes
                        : _timerSeconds,
                    unit: _mode == 'Continuous' ? 'min' : 's',
                    hint: _mode == 'Continuous' ? '1–60 min' : '10–300 s',
                    min: _mode == 'Continuous' ? 1 : 10,
                    max: _mode == 'Continuous' ? 60 : 300,
                    step: 1,
                    locked: locked,
                    isSet: _timerSet,
                    onChanged: (v) {
                      setState(() {
                        if (_mode == 'Continuous') {
                          _timerMinutes = v;
                          if (!_isOvenOn) _remainingSeconds = v * 60;
                        } else {
                          _timerSeconds = v;
                          if (!_isOvenOn) _remainingSeconds = v;
                        }
                        _timerSet = false; // changing value resets SET state
                      });
                    },
                    onSet: (v) {
                      setState(() => _timerSet = true);
                      //   final secs = _mode == 'Continuous' ? v * 60 : v;
                      _serial.sendTimer(v);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 10),

          // ── Row 2: Shaft Temp Target | Edge Temp Target ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BigParamControl(
                    label: 'Shaft Temp Target',
                    icon: Icons.thermostat,
                    color: _kAmber,
                    value: _shaftTempTarget,
                    unit: '°C',
                    hint: '20–100 °C',
                    min: 20,
                    max: 100,
                    step: 1,
                    locked: locked,
                    isSet: _shaftTempSet,
                    onChanged: (v) {
                      setState(() {
                        _shaftTempTarget = v;
                        _shaftTempSet = false;
                      });
                    },
                    onSet: (v) {
                      setState(() => _shaftTempSet = true);
                      // Requires SerialService.sendShaftTemp(int) — see
                      // note at top of this file.
                      _serial.sendShaftTemp(v);
                      _log(
                        'SET Shaft Temp Target: $v °C → sent 18${v.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                        level: 'info',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigParamControl(
                    label: 'Edge Temp Target',
                    icon: Icons.device_thermostat,
                    color: _kOrange,
                    value: _edgeTempTarget,
                    unit: '°C',
                    hint: '20–100 °C',
                    min: 20,
                    max: 100,
                    step: 1,
                    locked: locked,
                    isSet: _edgeTempSet,
                    onChanged: (v) {
                      setState(() {
                        _edgeTempTarget = v;
                        _edgeTempSet = false;
                      });
                    },
                    onSet: (v) {
                      setState(() => _edgeTempSet = true);
                      // Requires SerialService.sendEdgeTemp(int) — see
                      // note at top of this file.
                      _serial.sendEdgeTemp(v);
                      _log(
                        'SET Edge Temp Target: $v °C → sent 19${v.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                        level: 'info',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Row 3: Pump Flow Rate (Endovorus only) — 0–250 L/min ──
          if (_isEndoMode(_mode)) ...[
            const SizedBox(height: 10),
            const Divider(color: _kBorder, height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: _BigParamControl(
                label: 'Pump Flow Rate',
                icon: Icons.water_drop_outlined,
                color: _kOrange,
                value: _pumpFlow,
                unit: 'L/min',
                hint: '0–250 L/min',
                min: 0,
                max: 250,
                step: 1,
                locked: locked,
                isSet: _flowSet,
                onChanged: (v) {
                  setState(() {
                    _pumpFlow = v;
                    _flowSet = false; // changing value resets SET state
                  });
                },
                onSet: (v) {
                  // NOTE: The flow-rate value is no longer sent to the
                  // device here. It is staged locally and only actually
                  // transmitted when the pump turns ON (real value) or
                  // OFF (value 0) — see _togglePump() / _onSerialData().
                  setState(() => _flowSet = true);
                  _log(
                    'SET Pump Flow: $v L/min (staged — sent when pump turns ON)',
                    level: 'info',
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROL BUTTONS (Pump + Oven + optional Pause for Continuous mode)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildControlButtons() {
    // Continuous:    pump SET → ON immediately; oven needs pump ON.
    // Footswitch:    pump SET → ON immediately; click oven → arm → footswitch → oven.
    // Endovascular:  pump SET → click pump → arm → footswitch → pump ON;
    //                pump OFF → click oven → arm → footswitch → oven starts.

    final bool setReady =
        _powerSet && _timerSet && (!_isEndoMode(_mode) || _flowSet);

    // Pump enabled if: not oven running, AND (setReady, or pump already on/waiting)
    final bool pumpEnabled =
        !_isOvenOn &&
        !_awaitingFootswitch &&
        (setReady || _isPumpOn || _pumpWaiting);

    // Oven enabled:
    //   Continuous:    pump must be ON
    //   Footswitch:    pump must be ON (to arm footswitch wait)
    //   Endovascular:  pump must be fully OFF (not waiting, not on)
    final bool ovenEnabled = _isEndoMode(_mode)
        ? (!_isPumpOn && !_pumpWaiting) // pump fully off
        : _isPumpOn; // continuous & footswitch: pump on

    // ── Pump button ──
    String pumpLabel;
    if (_isPumpOn) {
      pumpLabel = 'TURN OFF PUMP';
    } else if (_pumpWaiting) {
      pumpLabel = 'CANCEL WAIT';
    } else {
      pumpLabel = 'TURN ON PUMP';
    }

    String pumpStatus;
    if (_isOvenOn) {
      pumpStatus = _isPaused ? 'Oven is paused' : 'Oven is active';
    } else if (_isPumpOn) {
      pumpStatus = _isEndoMode(_mode)
          ? 'Running at $_pumpFlow L/min'
          : 'Pump running';
    } else if (_pumpWaiting) {
      pumpStatus = 'Waiting for footswitch…';
    } else if (!setReady) {
      pumpStatus = _isEndoMode(_mode)
          ? 'Set Power, Timer & Flow first'
          : 'Set Power & Timer first';
    } else {
      pumpStatus = 'Pump is off';
    }

    // ── Oven button ──
    String ovenLabel;
    if (_isOvenOn) {
      ovenLabel = 'STOP';
    } else if (_awaitingFootswitch) {
      ovenLabel = 'CANCEL WAIT';
    } else {
      ovenLabel = 'START';
    }

    String ovenStatus;
    if (_isOvenOn) {
      ovenStatus = _isPaused
          ? 'Paused — tap Resume to continue'
          : 'Ablation in progress';
    } else if (_awaitingFootswitch) {
      ovenStatus = 'Waiting for footswitch…';
    } else if (_isFootswitchMode(_mode)) {
      ovenStatus = _isPumpOn ? 'Click to arm footswitch' : 'Start pump first';
    } else if (_isEndoMode(_mode)) {
      if (_isPumpOn || _pumpWaiting) {
        ovenStatus = 'Turn pump off first';
      } else {
        ovenStatus = 'Click to arm footswitch';
      }
    } else {
      ovenStatus = _isPumpOn ? 'Ready to start' : 'Start pump first';
    }

    String ovenDisabledHint;
    if (_isEndoMode(_mode)) {
      ovenDisabledHint = _pumpWaiting
          ? 'Pump footswitch pending'
          : 'Turn pump off first';
    } else {
      ovenDisabledHint = 'Start pump first';
    }

    final showPause = _mode == 'Continuous';

    return Row(
      children: [
        // ── Pump ──
        Expanded(
          child: _HardwareButton(
            label: pumpLabel,
            icon: _pumpWaiting
                ? Icons.electrical_services_rounded
                : Icons.water_drop_rounded,
            active: _isPumpOn || _pumpWaiting,
            activeColor: _pumpWaiting ? _kAmber : _kOrange,
            inactiveColor: setReady ? _kGreen : _kSubText,
            enabled: pumpEnabled,
            disabledHint: _isOvenOn
                ? (_isPaused ? 'Resume/Stop oven first' : 'Stop oven first')
                : _awaitingFootswitch
                ? 'Oven footswitch armed'
                : !setReady
                ? (_isEndoMode(_mode)
                      ? 'Set Power, Timer & Flow first'
                      : 'Set Power & Timer first')
                : null,
            onTap: _togglePump,
            statusLine: pumpStatus,
            pulseAnim: (_isPumpOn || _pumpWaiting) ? _pulseAnim : null,
          ),
        ),
        const SizedBox(width: 10),
        // ── Oven ──
        Expanded(
          child: _HardwareButton(
            label: ovenLabel,
            icon: _awaitingFootswitch
                ? Icons.electrical_services_rounded
                : Icons.microwave_outlined,
            active: _isOvenOn || _awaitingFootswitch,
            activeColor: _isPaused
                ? _kAmber
                : (_awaitingFootswitch ? _kAmber : _kRed),
            inactiveColor: _kNavy,
            enabled: ovenEnabled,
            disabledHint: !ovenEnabled ? ovenDisabledHint : null,
            onTap: _toggleOven,
            statusLine: ovenStatus,
            pulseAnim: (_isOvenOn && !_isPaused) || _awaitingFootswitch
                ? _pulseAnim
                : null,
          ),
        ),
        // ── Pause / Resume (Continuous mode only) ──
        if (showPause) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _HardwareButton(
              label: _isPaused ? 'RESUME' : 'PAUSE',
              icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              active: _isPaused,
              activeColor: _kAmber,
              inactiveColor: _kBlue,
              enabled: _isOvenOn,
              disabledHint: !_isOvenOn ? 'Start oven first' : null,
              onTap: _togglePause,
              statusLine: _isPaused
                  ? 'Paused at ${_fmt(_elapsedSeconds)}'
                  : (_isOvenOn ? 'Tap to pause ablation' : 'Oven not running'),
              pulseAnim: _isPaused ? _pulseAnim : null,
            ),
          ),
        ],
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
              if (_isOvenOn && !_isPaused)
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
                )
              else if (_isOvenOn && _isPaused)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: _kAmber,
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
          if (_isOvenOn && !_isPaused && !_isMuted && _beepFlash)
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
          // End Procedure — always available, regardless of pause state.
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
// Big Parameter Control Widget — real Slider + drag + long-press step buttons.
// Uniform sizing is used across every parameter (Power, Duration, Shaft
// Temp, Edge Temp, Pump Flow) so the control/button footprint stays
// consistent whether it's shown one-per-row or two-per-row.
// ─────────────────────────────────────────────────────────────────────────────
class _BigParamControl extends StatelessWidget {
  final String label, unit, hint;
  final IconData icon;
  final Color color;
  final int value, min, max, step;
  final bool locked;

  /// Whether the SET button has been confirmed for this parameter.
  /// True = value was sent to device. Resets when value changes.
  final bool isSet;
  final Function(int) onChanged;

  /// Callback fired when the SET button is tapped (sends value to device).
  final Function(int)? onSet;

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
    required this.isSet,
    required this.onChanged,
    this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final confirmedColor = isSet && !locked ? _kGreen : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: locked ? _kSubText : color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: locked ? _kSubText : _kNavy,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Value display badge — green border when SET is confirmed
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (locked ? _kSubText : color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                // border: isSet && !locked
                //     ? Border.all(color: _kGreen, width: 2)
                //     : null,
              ),
              child: Text(
                '$value $unit',
                style: TextStyle(
                  color: locked ? _kSubText : color,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // SET button — turns green with checkmark when confirmed
            if (onSet != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: locked ? null : () => onSet!(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: locked
                        ? Colors.grey.shade100
                        : isSet
                        ? _kGreen.withOpacity(0.12)
                        : color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: locked
                          ? _kBorder
                          : isSet
                          ? _kGreen.withOpacity(0.7)
                          : color.withOpacity(0.5),
                      width: isSet && !locked ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSet && !locked) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: _kGreen,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        'SET',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: locked ? _kSubText : confirmedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Decrease (tap = -step, long-press = auto-repeat)
            _BigStepBtn(
              icon: Icons.remove_rounded,
              color: color,
              enabled: !locked && value > min,
              onStep: () => onChanged(math.max(min, value - step)),
            ),
            // Slider — drag to set value directly, snapped to `step`.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 22,
                        activeTrackColor: locked
                            ? _kSubText.withOpacity(0.3)
                            : color,
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: locked ? _kSubText : color,
                        overlayColor: color.withOpacity(0.15),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 14,
                        ),
                        trackShape: const RoundedRectSliderTrackShape(),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 22,
                        ),
                      ),
                      child: Slider(
                        value: value.toDouble().clamp(
                          min.toDouble(),
                          max.toDouble(),
                        ),
                        min: min.toDouble(),
                        max: max.toDouble(),
                        divisions: math.max(1, ((max - min) / step).round()),
                        onChanged: locked
                            ? null
                            : (v) {
                                // Snap to nearest step and report as int.
                                final newVal =
                                    ((v - min) / step).round() * step + min;
                                onChanged(newVal.clamp(min, max));
                              },
                      ),
                    ),
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
                            fontSize: 11,
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
            // Increase (tap = +step, long-press = auto-repeat)
            _BigStepBtn(
              icon: Icons.add_rounded,
              color: color,
              enabled: !locked && value < max,
              onStep: () => onChanged(math.min(max, value + step)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Step button that supports a single tap (one step) and a long-press
/// that auto-repeats the step at a fixed interval until released.
class _BigStepBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onStep;
  const _BigStepBtn({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onStep,
  });

  @override
  State<_BigStepBtn> createState() => _BigStepBtnState();
}

class _BigStepBtnState extends State<_BigStepBtn> {
  Timer? _repeatTimer;

  void _startAutoRepeat() {
    _stopAutoRepeat();
    // Small initial delay then repeat quickly while held.
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      widget.onStep();
    });
  }

  void _stopAutoRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onStep : null,
      onLongPressStart: widget.enabled ? (_) => _startAutoRepeat() : null,
      onLongPressEnd: widget.enabled ? (_) => _stopAutoRepeat() : null,
      onLongPressCancel: widget.enabled ? _stopAutoRepeat : null,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: widget.enabled
              ? widget.color.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.enabled ? widget.color.withOpacity(0.25) : _kBorder,
          ),
        ),
        child: Icon(
          widget.icon,
          size: 26,
          color: widget.enabled ? widget.color : _kSubText.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hardware Button (Pump / Oven / Pause — same style)
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
                fontSize: 70,
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
                    fontSize: 25,
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
