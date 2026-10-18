import 'dart:async';
import 'dart:io';

import 'bridge_client.dart';
import 'build_info.dart';

// [agent] Auto-update: every 6 h ask the bridge which build this computer should run
// (pilots first, the rest two days later), download it, check SHA-256 and reinstall
// silently over the current installation. Never during a technician's session.

class AgentUpdater {
  final BridgeClient bridge;
  final Future<String> Function() getPeerId;
  AgentUpdater({required this.bridge, required this.getPeerId});

  static const _firstCheck = Duration(minutes: 10);
  static const _interval = Duration(hours: 6);
  Timer? _timer;
  bool _busy = false;

  void start() {
    if (!Platform.isWindows || kYpBuild == 0) return; // dev builds never replace themselves
    Timer(_firstCheck, check);
    _timer = Timer.periodic(_interval, (_) => check());
  }

  void stop() => _timer?.cancel();

  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    try {
      final update = await bridge.checkUpdate(await getPeerId(), kYpBuild);
      if (update == null || await technicianConnected()) return;
      final exe = File('${Directory.systemTemp.path}\\yapomogu-agent-${update.build}.exe');
      await exe.writeAsBytes(await bridge.download(update.url), flush: true);
      if (await fileSha256(exe.path) != update.sha256.toLowerCase()) {
        await exe.delete();
        return;
      }
      // The installer stops every running copy of the agent, this one included.
      await Process.start(exe.path, ['--silent-install'], mode: ProcessStartMode.detached);
    } catch (_) {
      // next round retries
    } finally {
      _busy = false;
    }
  }
}

Future<String> _powershell(String script) async {
  final r = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
  return (r.stdout as String).trim();
}

Future<String> fileSha256(String path) async =>
    (await _powershell("(Get-FileHash -Algorithm SHA256 -LiteralPath '${path.replaceAll("'", "''")}').Hash")).toLowerCase();

/// A connection-manager process (`--cm`) exists only while someone is connected.
Future<bool> technicianConnected() async {
  final name = Platform.resolvedExecutable.split('\\').last.replaceAll("'", "''");
  final out = await _powershell(
      "@(Get-CimInstance Win32_Process -Filter \"Name='$name'\" | Where-Object { \$_.CommandLine -like '*--cm*' }).Count");
  return (int.tryParse(out) ?? 1) > 0; // unknown → assume busy, try later
}
