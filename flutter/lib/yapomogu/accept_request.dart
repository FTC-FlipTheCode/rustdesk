import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'agent_bindings.dart';
import 'bridge_client.dart';
import 'cm_window.dart';

// [agent] «Специалист просит подключиться»: our own request window instead of the stock connection
// manager. It answers the stock login request (Принять / Отклонить) and declines by itself after
// kYpAcceptSeconds. Connections that never asked (a password connection) are remembered by the banner.

const kYpAcceptSize = Size(440, 340);
const kYpAcceptSeconds = 30;

/// Connection ids this window asked about; the banner treats every other session as «по паролю».
final Set<int> ypAskedConnections = {};

/// The remote-control request waiting for an answer, or null (file transfer and the rest keep the stock window).
Client? pendingClient(List<Client> clients) {
  for (final c in clients) {
    if (!c.authorized && !c.disconnected && c.type_() == ClientType.remote) return c;
  }
  return null;
}

String ypInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'IT';
  return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
}

class YpAcceptRequest extends StatefulWidget {
  final Client client;
  const YpAcceptRequest({super.key, required this.client});
  @override
  State<YpAcceptRequest> createState() => _YpAcceptRequestState();
}

class _YpAcceptRequestState extends State<YpAcceptRequest> {
  final _bridge = BridgeClient(baseUrl: AgentBindings.bridgeUrl);
  Timer? _tick;
  int _left = kYpAcceptSeconds;
  String _name = '';
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    ypAskedConnections.add(widget.client.id);
    _name = widget.client.name;
    ypHoldWindow(kYpAcceptSize, Alignment.center, focus: true);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ypHoldWindow(kYpAcceptSize, Alignment.center);
      setState(() => _left--);
      if (_left <= 0) _answer(false);
    });
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
    super.dispose();
  }

  void _answer(bool accept) {
    if (_answered || !mounted) return;
    _answered = true;
    Provider.of<ServerModel>(context, listen: false).sendLoginResponse(widget.client, accept);
  }

  @override
  Widget build(BuildContext context) {
    final who = _name.isEmpty ? 'Специалист' : _name;
    return Material(
      color: Colors.white,
      child: Column(children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
          child: SvgPicture.asset('assets/yapomogu_logo.svg', height: 28),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(ypInitials(who),
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$who просит подключиться',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    const Text('Специалист техподдержки «Я ПОМОГУ!»',
                        style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: const Text(
                    'Он сможет видеть экран и управлять мышью и клавиатурой.\nЗакончить сеанс можно в любой момент.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
              ),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _answered ? null : () => _answer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Принять', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _answered ? null : () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Отклонить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Center(
                child: Text('Если не ответить, запрос отклонится через ${_left < 0 ? 0 : _left} с',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
