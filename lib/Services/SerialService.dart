import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Singleton service that manages serial port communication with the
/// RADDMED ablation device.
///
/// ## Protocol Reference
/// ### Outgoing (App → Device)
/// | Cmd  | Format       | Description                          |
/// |------|--------------|--------------------------------------|
/// | 11   | `11\n`       | Start procedure                      |
/// | 12   | `12{VAL}\n`  | Set power (e.g. `1275` = 75 W)       |
/// | 13   | `13{VAL}\n`  | Set timer (e.g. `13300` = 300 s)     |
/// | 14   | `1401\n`     | Pump ON                              |
/// |      | `1400\n`     | Pump OFF                             |
/// | 15   | `1500\n`     | Oven OFF (Continuous)                |
/// |      | `1501\n`     | Oven ON  (Continuous)                |
/// | 16   | `1600\n`     | Oven OFF (Footswitch/Endovorus)      |
/// |      | `1601\n`     | Oven ON  (Footswitch/Endovorus)      |
/// | 17   | `17{VAL}\n`  | Set pump flow rate (Endovorus)       |
/// | 18   | `18{VAL}\n`  | Set infusion flow rate               |
///
/// ### Incoming (Device → App)
/// Current (Nextion-style) format — plain decimal values, no scaling:
/// | Tag       | Format         | Description                                  |
/// |-----------|----------------|-----------------------------------------------|
/// | `n1.val`  | `n1.val=150\n` | Power, direct value (e.g. 150 = 150 W)       |
/// | `n2.val`  | `n2.val=120\n` | Shaft temperature, direct value (°C)         |
/// | `n3.val`  | `n3.val=160\n` | Edge temperature, direct value (°C)          |
/// | `tm0.en`  | `tm0.en=1\n`   | Footswitch PRESSED (level signal, held down) |
/// |           | `tm0.en=0\n`   | Footswitch RELEASED                          |
///
/// The footswitch is a level (dead-man) signal, not a one-shot pulse:
///  - `tm0.en=1` fires whatever action is currently armed — turns the pump
///    ON while waiting (Endovorus phase 1), starts the oven while armed
///    (Footswitch mode / Endovorus phase 2), or resumes a paused oven.
///  - `tm0.en=0` pauses a running oven (Footswitch / Endovorus modes) and,
///    in Endovorus mode, turns the pump back OFF (re-arming it so the next
///    press turns it back on).
///
/// Legacy hex protocol (kept as a fallback for older firmware):
/// | Cmd  | Format       | Description                          |
/// |------|--------------|--------------------------------------|
/// | 22   | `22{DATA}\n` | Shaft temperature (×10, e.g. 22E6=37.0°C, 0xE6=230) |
/// | 23   | `23{DATA}\n` | Edge temperature  (×10, hex)         |
/// | 24   | `24{DATA}\n` | Power           (×10, hex)          |
/// | 25   | `25\n`       | Footswitch activated                 |
/// |26    | 26{DATA}\n | Endovonuse Pumb on          (×10, hex)              |
class SerialService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  SerialService._();
  static final SerialService instance = SerialService._();

  // ── Port state ─────────────────────────────────────────────────────────────
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSub;
  String? _connectedPortName;
  final StringBuffer _buffer = StringBuffer();

  // ── Public state ───────────────────────────────────────────────────────────
  bool get isConnected => _port?.isOpen ?? false;
  String? get connectedPort => _connectedPortName;

  // ── Streams ────────────────────────────────────────────────────────────────
  final _statusCtrl = StreamController<SerialConnectionStatus>.broadcast();
  Stream<SerialConnectionStatus> get statusStream => _statusCtrl.stream;

  final _dataCtrl = StreamController<SerialCommand>.broadcast();
  Stream<SerialCommand> get dataStream => _dataCtrl.stream;

  // ── Configuration ──────────────────────────────────────────────────────────
  int baudRate = 115200;

  // ── Port Discovery ─────────────────────────────────────────────────────────
  /// Returns all serial + PTY ports available on this machine.
  ///
  /// `flutter_libserialport` (via `libserialport`) only enumerates real
  /// hardware ports through the OS device manager (IOKit on macOS, udev on
  /// Linux). It intentionally skips pseudo-terminal (PTY) devices such as
  /// `/dev/ttys*`, `/dev/ptyp*`, etc., which are commonly used by serial
  /// simulators, virtual COM tools, and socat tunnels.
  ///
  /// This override merges both lists so that PTY ports appear in the dropdown.
  List<String> get availablePorts {
    final hw = SerialPort.availablePorts; // hardware / USB-serial / BT-serial
    // final pty = _scanPtyDevices();
    // Merge, preserving order: hardware first, then PTY-only entries.
    return [...hw]; //...pty.where((p) => !hw.contains(p))];
  }

  /// Scans `/dev/` for pseudo-terminal and software-serial devices.
  /// On macOS the relevant patterns are:
  ///   - `/dev/ttys*`   – slave PTYs (socat, screen, minicom targets)
  ///   - `/dev/ptyp*`   – BSD-style master PTYs
  ///   - `/dev/tty.*`   – macOS IOKit cu/tty pairs (already in hw list but
  ///                       caught here as fallback)

  /// Returns a user-friendly map of port name → description.

  // ── Connect ────────────────────────────────────────────────────────────────

  /// Returns true when [portName] is a pseudo-terminal device.
  /// PTY slaves cannot accept hardware serial port configuration (baud rate
  /// via IOKit, flow control, etc.) — applying it causes SP_ERR_FAIL (code 2).

  /// Opens the given serial port for read/write communication.
  bool connect(String portName) {
    disconnect(); // Clean up any existing connection

    try {
      _port = SerialPort(portName);

      // Open first — libserialport validates the path at this point.
      // For PTY devices we MUST open before calling config, otherwise the
      // library tries to query IOKit for a device that doesn't exist in the
      // hardware registry and returns SP_ERR_FAIL (error code 2 = ENOENT).
      if (!_port!.openReadWrite()) {
        final err = SerialPort.lastError;

        _statusCtrl.add(
          SerialConnectionStatus(
            connected: false,
            portName: portName,
            error: 'Failed to open port: $err',
          ),
        );
        _port!.dispose();
        _port = null;
        return false;
      }

      // Apply serial configuration only for real hardware ports.
      // Pseudo-terminal devices don't support IOKit-based baud rate config;
      // they inherit whatever the master side sets.

      _connectedPortName = portName;

      // Start listening
      _reader = SerialPortReader(_port!, timeout: 100);
      _readerSub = _reader!.stream.listen(
        _onData,
        onError: (e) {
          _statusCtrl.add(
            SerialConnectionStatus(
              connected: false,
              portName: portName,
              error: 'Read error: $e',
            ),
          );
        },
        cancelOnError: false,
      );

      _statusCtrl.add(
        SerialConnectionStatus(connected: true, portName: portName),
      );
      return true;
    } catch (e) {
      _statusCtrl.add(
        SerialConnectionStatus(
          connected: false,
          portName: portName,
          error: 'Connection error: $e',
        ),
      );
      _port?.dispose();
      _port = null;
      return false;
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  void disconnect() {
    _readerSub?.cancel();
    _readerSub = null;
    _reader = null;
    _buffer.clear();

    if (_port != null) {
      if (_port!.isOpen) _port!.close();
      _port!.dispose();
      _port = null;
    }

    if (_connectedPortName != null) {
      _statusCtrl.add(
        SerialConnectionStatus(connected: false, portName: _connectedPortName),
      );
      _connectedPortName = null;
    }
  }

  // ── Hex helper ─────────────────────────────────────────────────────────────
  /// Converts [value] to uppercase hexadecimal string, zero-padded to at
  /// least 2 digits.
  /// e.g.  10 → '0A'   (not 'A')
  ///       16 → '10'
  ///      255 → 'FF'
  ///      300 → '012C'
  static String _toHex(int value) {
    final hex = value.toRadixString(16).toUpperCase();
    // Ensure minimum 2 hex digits so 10 → '0A', giving '120A' not '12A'
    return hex.length < 2 ? hex.padLeft(2, '0') : hex;
  }

  // ── Send Command ───────────────────────────────────────────────────────────
  /// Sends a command string to the device.
  /// Always prints to debug console regardless of connection state.
  bool send(String cmd) {
    log("send : $cmd");
    var command = hexToNumber(cmd).toString();
    log("send  HEX: $command");

    var newcomd = hexToBytes(cmd);
    log(newcomd.toString());
    if (_port == null || !_port!.isOpen) return false;
    try {
      //final bytes = Uint8List.fromList();
      _port!.write(newcomd);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Convenience Senders ────────────────────────────────────────────────────

  /// Send `11` — start procedure
  bool sendStartProcedure() => send('11');

  /// Send `1100` — activation screen opened in Continuous mode
  /// Send `1101` — activation screen opened in Footswitch / Endovascular mode
  bool sendActivation(bool footswitchOrEndo) =>
      send(footswitchOrEndo ? '1101' : '1100');

  /// Send `12{HEX2}` — set power in watts, value zero-padded to ≥2 hex digits
  /// e.g.  10 W → '120A'
  ///       75 W → '124B'
  ///      150 W → '1296'
  bool sendPower(int watts) => send('12${_toHex(watts)}');

  /// Send `13{HEX2}` — set timer in seconds, value zero-padded to ≥2 hex digits
  /// e.g.  10 s → '130A'
  ///       60 s → '133C'
  ///      300 s → '1312C'
  bool sendTimer(int seconds) => send('13${_toHex(seconds)}');

  /// Send `1401` / `1400` — pump ON / OFF
  bool sendPump(bool on) => send(on ? '1401' : '1400');

  /// Send `1501` / `1500` — oven ON/OFF in Continuous mode
  bool sendOvenContinuous(bool on) => send(on ? '1501' : '1500');

  /// Send `1601` / `1600` — oven ON/OFF in Footswitch/Endovorus mode
  bool sendOvenFootswitch(bool on) => send(on ? '1601' : '1600');

  /// Send `17{HEX2}` — set pump flow rate in Endovorus mode
  /// Value = rateL × 10 (tenths of L/min), zero-padded to ≥2 hex digits
  /// e.g. 1.0 L/min → 10 → '170A'
  ///      5.0 L/min → 50 → '1732'
  bool sendPumpFlowRate(double rateL) {
    final raw = (rateL).round();
    return send('17${_toHex(raw)}');
  }

  /// Send `18{HEX2}` — set infusion flow rate (value in L/min × 10, encoded as hex)
  /// e.g. 1.0 L/min → 10 → '180A'
  bool sendInfusionFlowRate(double rateL) {
    final raw = (rateL).round();
    // decimal value of 18 is 24
    return send('18${_toHex(raw)}');
    // return send('24${raw}');
  }

  // ── Incoming Data Parser ───────────────────────────────────────────────────
  void _onData(Uint8List data) {
    // Guard the whole receive path: this runs on every byte chunk from the
    // reader stream, and a thrown exception here happens synchronously
    // inside the listen() callback, so it does NOT reach the subscription's
    // onError — it would otherwise surface as an uncaught error and the
    // failure would be invisible to the user. Catch it, log it, and surface
    // it on dataStream so screens listening for SerialCommand can show it.
    try {
      final chunk = String.fromCharCodes(data);
      _buffer.write(chunk);

      // Process complete lines (newline-terminated)
      while (true) {
        final content = _buffer.toString();
        final nlIdx = content.indexOf('\n');
        if (nlIdx == -1) break;

        final line = content.substring(0, nlIdx).trim();
        _buffer.clear();
        _buffer.write(content.substring(nlIdx + 1));

        if (line.isEmpty) continue;
        log("GET : $line");
        try {
          _parseLine(line);
        } catch (e, st) {
          log("Serial parse error for line '$line': $e", stackTrace: st);
          _dataCtrl.add(
            SerialCommand(
              type: SerialCommandType.unknown,
              value: 0,
              raw: 'PARSE ERROR: $e (line="$line")',
            ),
          );
        }
      }
    } catch (e, st) {
      log("Serial receive error: $e", stackTrace: st);
      _buffer.clear(); // drop whatever partial data caused the failure
      _dataCtrl.add(
        SerialCommand(
          type: SerialCommandType.unknown,
          value: 0,
          raw: 'RECEIVE ERROR: $e',
        ),
      );
    }
  }

  void _parseLine(String line) {
    print(line);

    // ── Current (Nextion-style) protocol ────────────────────────────────────
    // n1.val=<int> → power (direct value, no scaling), e.g. n1.val=150 = 150 W
    // n2.val=<int> → shaft temperature (direct value, °C)
    // n3.val=<int> → edge temperature (direct value, °C)
    // tm0.en=1/0   → footswitch level signal: 1 = pressed/held, 0 = released
    if (line.startsWith('n1.val=')) {
      final v = int.tryParse(line.substring('n1.val='.length).trim());
      if (v != null) {
        _dataCtrl.add(
          SerialCommand(
            type: SerialCommandType.voltage,
            value: v.toDouble(),
            raw: line,
          ),
        );
        return;
      }
    }

    if (line.startsWith('n2.val=')) {
      final v = int.tryParse(line.substring('n2.val='.length).trim());
      if (v != null) {
        _dataCtrl.add(
          SerialCommand(
            type: SerialCommandType.shaftTemp,
            value: v.toDouble(),
            raw: line,
          ),
        );
        return;
      }
    }

    if (line.startsWith('n3.val=')) {
      final v = int.tryParse(line.substring('n3.val='.length).trim());
      if (v != null) {
        _dataCtrl.add(
          SerialCommand(
            type: SerialCommandType.edgeTemp,
            value: v.toDouble(),
            raw: line,
          ),
        );
        return;
      }
    }

    if (line.startsWith('tm0.en=')) {
      final v = int.tryParse(line.substring('tm0.en='.length).trim());
      if (v != null) {
        _dataCtrl.add(
          SerialCommand(
            type: SerialCommandType.footswitch,
            // Level signal: 1 = pressed/held, 0 = released. Any non-zero
            // value is treated as "pressed" so the app stays robust to
            // stray values from the panel.
            value: v == 0 ? 0.0 : 1.0,
            raw: line,
          ),
        );
        return;
      }
    }

    // ── Legacy hex protocol (fallback for older firmware) ──────────────────
    // Command 25 — footswitch (exact match, no data payload)
    if (line == '25') {
      _dataCtrl.add(
        const SerialCommand(
          type: SerialCommandType.footswitch,
          value: 1.0,
          raw: '25',
        ),
      );
      return;
    }

    // Commands 22xx, 23xx, 24xx — sensor data
    if (line.length >= 3) {
      final prefix = line.substring(0, 2);
      final dataStr = line.substring(2);
      // Device sends sensor readings as hex text (matching the hex-based
      // outgoing protocol, see _toHex/hexToBytes above) — e.g. "22FF" means
      // raw hex FF (255), not decimal 255. Parsing this as decimal silently
      // fails (returns null) whenever the value contains A-F, so no data
      // event is emitted and the live graph never updates for that sample.
      final rawVal = int.tryParse(dataStr, radix: 16);
      

      if (rawVal != null) {
        switch (prefix) {
          case '22':
            _dataCtrl.add(
              SerialCommand(
                type: SerialCommandType.shaftTemp,
                value: rawVal / 10.0,
                raw: line, // unparsed line, e.g. for temporary debug display
              ),
            );
            return;
          case '23':
            _dataCtrl.add(
              SerialCommand(
                type: SerialCommandType.edgeTemp,
                value: rawVal / 10.0,
                raw: line,
              ),
            );
            return;
          case '24':
            _dataCtrl.add(
              SerialCommand(
                type: SerialCommandType.voltage,
                value: rawVal / 10.0,
                raw: line,
              ),
            );
            return;
        }
      }
    }

    // Unknown command — emit as raw for debugging
    _dataCtrl.add(
      SerialCommand(type: SerialCommandType.unknown, value: 0, raw: line),
    );
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────
  void dispose() {
    disconnect();
    _statusCtrl.close();
    _dataCtrl.close();
  }

  void sendShaftTemp(int v) {
    send("27${_toHex(v)}");
  }

  void sendEdgeTemp(int v) {
    send("28${_toHex(v)}");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

/// The type of data received from the device.
enum SerialCommandType {
  shaftTemp, // n2.val (legacy: 22)
  edgeTemp, // n3.val (legacy: 23)
  voltage, // n1.val — power (legacy: 24)
  footswitch, // tm0.en — level signal, value 1.0=pressed / 0.0=released (legacy: 25)
  unknown,
}

/// A parsed incoming command from the device.
class SerialCommand {
  final SerialCommandType type;
  final double value;
  final String? raw;
  const SerialCommand({required this.type, required this.value, this.raw});

  @override
  String toString() =>
      'SerialCommand($type, $value${raw != null ? ', raw=$raw' : ''})';
}

/// Connection status event.
class SerialConnectionStatus {
  final bool connected;
  final String? portName;
  final String? error;
  const SerialConnectionStatus({
    required this.connected,
    this.portName,
    this.error,
  });
}

// String hexToString(String hex) {
//   // Strip common prefixes/whitespace, just in case
//   final cleanHex = hex.replaceAll(RegExp(r'\s+'), '').replaceAll('0x', '');

//   if (cleanHex.length % 2 != 0) {
//     throw FormatException('Invalid hex string: odd length');
//   }

//   final bytes = <int>[];
//   for (int i = 0; i < cleanHex.length; i += 2) {
//     final byteHex = cleanHex.substring(i, i + 2);
//     bytes.add(int.parse(byteHex, radix: 16));
//   }

//   return utf8.decode(bytes);
// }

int hexToNumber(String hex) {
  final cleanHex = hex.trim().replaceAll('0x', '').replaceAll('0X', '');
  return int.parse(cleanHex, radix: 16);
}

Uint8List hexToBytes(String hex) {
  // Remove spaces if present
  hex = hex.replaceAll(' ', '').toUpperCase();

  if (hex.length.isOdd) {
    throw Exception('Hex string must have an even number of characters');
  }

  final bytes = <int>[];

  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }

  return Uint8List.fromList(bytes);
}
