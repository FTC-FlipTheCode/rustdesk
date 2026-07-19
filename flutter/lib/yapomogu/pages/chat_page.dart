import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _firstMessage = true;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(AgentController ctrl) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await ctrl.sendMessage(text);
    if (_firstMessage) {
      setState(() => _firstMessage = false);
    }
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))), color: Colors.white),
        child: const Row(children: [
          Text('Чат с IT отделом', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ]),
      ),
      // Messages
      Expanded(
        child: Obx(() {
          final msgs = ctrl.messages;
          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: msgs.length + (_firstMessage ? 0 : 0),
            itemBuilder: (ctx, i) {
              if (!_firstMessage && i == 0) {
                return _TicketCreatedNotice();
              }
              final msg = msgs[_firstMessage ? i : i - 1];
              return _MessageBubble(msg: msg);
            },
          );
        }),
      ),
      // Input
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              decoration: InputDecoration(
                hintText: 'Введите сообщение...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
              onSubmitted: (_) => _send(ctrl),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _send(ctrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Отправить', style: TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ]),
      ),
    ]);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isIn = msg.isOutgoing; // incoming TO agent = from technician
    return Align(
      alignment: isIn ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isIn ? const Color(0xFFF1F5F9) : const Color(0xFF2563EB),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
            bottomLeft: isIn ? Radius.zero : const Radius.circular(12),
            bottomRight: isIn ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg.content, style: TextStyle(fontSize: 13, color: isIn ? const Color(0xFF1E293B) : Colors.white, height: 1.45)),
          const SizedBox(height: 4),
          Text(msg.time, style: TextStyle(fontSize: 11, color: isIn ? const Color(0xFF94A3B8) : Colors.white54)),
        ]),
      ),
    );
  }
}

class _TicketCreatedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('📋 Заявка создана автоматически', style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8))),
    ),
  );
}
