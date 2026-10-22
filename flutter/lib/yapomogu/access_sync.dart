import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'access_policy.dart';
import 'bridge_client.dart';

// [agent] Unattended access: once an hour ask the bridge whether technicians may connect without the
// client pressing «Принять». The bridge derives and rotates the password; this agent only applies it to
// RustDesk. The one-time agent secret that proves this computer to the bridge lives in SharedPreferences;
// the password itself is never written by us.

const _kAgentSecretKey = 'yp_agent_secret';

class AccessSync {
  final BridgeClient bridge;
  final Future<String> Function() getPeerId;

  /// Sets the RustDesk options a plan describes (the native side, see access_apply.dart).
  final Future<void> Function(AccessPlan) apply;
  AccessSync({required this.bridge, required this.getPeerId, required this.apply});

  static const _firstCheck = Duration(minutes: 1);
  static const _interval = Duration(hours: 1);
  Timer? _timer;
  bool _busy = false;

  void start() {
    Timer(_firstCheck, sync);
    _timer = Timer.periodic(_interval, (_) => sync());
  }

  void stop() => _timer?.cancel();

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    try {
      final peerId = await getPeerId();
      final prefs = await SharedPreferences.getInstance();
      var secret = prefs.getString(_kAgentSecretKey);
      if (secret == null) {
        secret = await bridge.enroll(peerId);
        if (secret == null) return; // not confirmed yet, or enrolled before: try again later
        await prefs.setString(_kAgentSecretKey, secret);
      }
      final state = await bridge.fetchAccess(peerId, secret);
      if (state == null) return;
      await apply(planFor(unattended: state.unattended, password: state.password));
    } catch (_) {
      // offline or bridge down: the next round retries, the current settings stay as they are
    } finally {
      _busy = false;
    }
  }
}
