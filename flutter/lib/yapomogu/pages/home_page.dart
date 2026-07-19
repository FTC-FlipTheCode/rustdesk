import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';
import 'chat_page.dart';

enum AgentTab { home, chat, tickets, sysinfo }

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});
  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  AgentTab _tab = AgentTab.home;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(children: [
        _Sidebar(currentTab: _tab, onTabChange: (t) => setState(() => _tab = t)),
        Expanded(child: _content(ctrl)),
      ]),
    );
  }

  Widget _content(AgentController ctrl) {
    switch (_tab) {
      case AgentTab.home:  return _HomeContent(ctrl: ctrl, onGoChat: () => setState(() => _tab = AgentTab.chat));
      case AgentTab.chat:  return const ChatPage();
      case AgentTab.tickets: return const TicketsPage();
      case AgentTab.sysinfo: return const SysinfoPage();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AgentTab currentTab;
  final void Function(AgentTab) onTabChange;
  const _Sidebar({required this.currentTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Container(
      width: 220,
      color: const Color(0xFF1E293B),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x12FFFFFF)))),
          child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Avatar(ctrl.contactName.value),
            const SizedBox(height: 10),
            Text(ctrl.contactName.value.isEmpty ? 'Пользователь' : ctrl.contactName.value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9))),
            const SizedBox(height: 2),
            Text(ctrl.companyName.value, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ])),
        ),
        // Nav
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Obx(() => Column(children: [
              _navItem(AgentTab.home, '🏠', 'Главная'),
              _navItem(AgentTab.chat, '💬', 'Чат с IT отделом',
                badge: ctrl.messages.where((m) => m.isOutgoing && m.id != null).length),
              _navItem(AgentTab.tickets, '📋', 'Заявки'),
              _navItem(AgentTab.sysinfo, '💻', 'Информация о системе'),
            ])),
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x12FFFFFF)))),
          child: Row(children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))),
            const SizedBox(width: 6),
            const Text('Подключён к серверу', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
        ),
      ]),
    );
  }

  Widget _navItem(AgentTab tab, String icon, String label, {int badge = 0}) {
    final active = currentTab == tab;
    return GestureDetector(
      onTap: () => onTabChange(tab),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: active ? const Color(0x2638BDF8) : Colors.transparent,
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.normal, color: active ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)))),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(99)),
              child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);
  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase() : '?';
    return Container(
      width: 40, height: 40,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF334155)),
      child: Center(child: Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
    );
  }
}

// ── Home content ──────────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  final AgentController ctrl;
  final VoidCallback onGoChat;
  const _HomeContent({required this.ctrl, required this.onGoChat});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Главная', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        Obx(() => _RemoteCard(peerId: ctrl.peerId.value)),
        const SizedBox(height: 14),
        _ChatCta(onTap: onGoChat),
        const SizedBox(height: 14),
        const _LastTicketBar(),
      ]),
    );
  }
}

class _RemoteCard extends StatefulWidget {
  final String peerId;
  const _RemoteCard({required this.peerId});
  @override
  State<_RemoteCard> createState() => _RemoteCardState();
}

class _RemoteCardState extends State<_RemoteCard> {
  bool _passVisible = false;

  @override
  Widget build(BuildContext context) {
    final formattedId = _formatId(widget.peerId);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFAFAFA),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ID ДЛЯ ПОДКЛЮЧЕНИЯ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: .6)),
          const SizedBox(height: 4),
          Text(formattedId, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: 3, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Пароль сессии', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(width: 8),
            Text(_passVisible ? '••••••' : '••••••', style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF374151))),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _passVisible = !_passVisible),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Text(_passVisible ? 'Скрыть' : 'Показать', style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
              ),
            ),
          ]),
        ])),
        const SizedBox(width: 16),
        Container(width: 1, height: 54, color: const Color(0xFFE2E8F0)),
        const SizedBox(width: 16),
        const SizedBox(
          width: 160,
          child: Text('Сообщите этот ID технику, чтобы он мог подключиться к вашему компьютеру', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5)),
        ),
      ]),
    );
  }

  String _formatId(String id) {
    // Format like "483 291 047"
    if (id.length >= 9) {
      return '${id.substring(0, 3)} ${id.substring(3, 6)} ${id.substring(6)}';
    }
    return id;
  }
}

class _ChatCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ChatCta({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDBEAFE)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFEFF6FF),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('💬', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Чат с IT отделом', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
          SizedBox(height: 3),
          Text('Задайте вопрос или сообщите о проблеме', style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6))),
        ])),
        const Icon(Icons.chevron_right, color: Color(0xFF3B82F6)),
      ]),
    ),
  );
}

class _LastTicketBar extends StatelessWidget {
  const _LastTicketBar();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(children: [
      _StatusBadge('Открыта'),
      SizedBox(width: 12),
      Expanded(child: Text('Последняя заявка', style: TextStyle(fontSize: 13, color: Color(0xFF374151)))),
      Text('—', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(99)),
    child: Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF854D0E))),
  );
}

// Temporary stubs — Task 8 will create these as separate files
class TicketsPage extends StatelessWidget { const TicketsPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text('Заявки')); }
class SysinfoPage extends StatelessWidget { const SysinfoPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text('Информация о системе')); }
