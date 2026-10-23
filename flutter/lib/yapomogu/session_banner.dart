import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'accept_request.dart';
import 'agent_bindings.dart';
import 'bridge_client.dart';
import 'cm_window.dart';

// [agent] "Техник подключён" banner. It replaces the stock connection-manager window
// (the --cm process, which alone knows the session) while a technician is connected
// and authorised; approvals, chat and file transfer keep the stock window.

const kYpBannerSize = Size(560, 44);
final Map<int, DateTime> _startedAt = {}; // connection id → first seen, for the timer

/// The connection to show as a banner, or null to keep the stock window.
Client? bannerClient(List<Client> clients) {
  if (clients.isEmpty || clients.any((c) => !c.authorized)) return null;
  for (final c in clients) {
    if (!c.disconnected && c.type_() == ClientType.remote) return c;
  }
  return null;
}

class YpSessionBanner extends StatefulWidget {
  final Client client;
  const YpSessionBanner({super.key, required this.client});
  @override
  State<YpSessionBanner> createState() => _YpSessionBannerState();
}

class _YpSessionBannerState extends State<YpSessionBanner> {
  final _bridge = BridgeClient(baseUrl: AgentBindings.bridgeUrl);
  late final DateTime _since;
  Timer? _tick;
  String _name = '';
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _since = _startedAt.putIfAbsent(widget.client.id, DateTime.now);
    _name = widget.client.name;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      ypHoldWindow(kYpBannerSize, Alignment.topCenter); // the stock code may hide or resize it after us
      setState(() {});
    });
    ypHoldWindow(kYpBannerSize, Alignment.topCenter, focus: true);
    _lookupName();
  }

  Future<void> _lookupName() async {
    try {
      final name = await _bridge.technicianName(await bind.mainGetMyId(), widget.client.peerId);
      if (name != null && mounted) setState(() => _name = name);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    windowManager.setSizeAlignment(kConnectionManagerWindowSizeClosedChat, Alignment.topRight);
    super.dispose();
  }

  Future<void> _end() async {
    setState(() => _ending = true);
    bind.cmCloseConnection(connId: widget.client.id);
    try {
      await _bridge.sessionEnded(await bind.mainGetMyId());
    } catch (_) {}
  }

  String get _elapsed {
    final d = DateTime.now().difference(_since);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  /// The technician came in with the unattended-access password: that mode is on and nobody was asked.
  /// (RustDesk may also let a recent peer back in without asking; that stays a normal green session.)
  bool get _byPassword =>
      !ypAskedConnections.contains(widget.client.id) && bind.mainGetOptionSync(key: kOptionApproveMode) == 'password';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _byPassword ? const Color(0xFFB45309) : const Color(0xFF16A34A),
      child: DragToMoveArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Техник '),
                  TextSpan(text: _name.isEmpty ? 'IT-отдела' : _name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: _byPassword ? ' подключился по паролю' : ' подключён к вашему компьютеру'),
                ]),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Text(_elapsed, style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _ending ? null : _end,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB91C1C),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(_ending ? 'Завершаем…' : 'Завершить сеанс', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
