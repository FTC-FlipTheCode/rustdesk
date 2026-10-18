import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';
import '../bridge_client.dart';
import '../screenshot.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _capturing = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(AgentController ctrl) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await ctrl.sendMessage(text);
    _scrollDown();
  }

  Future<void> _screenshot(AgentController ctrl) async {
    setState(() => _capturing = true);
    Uint8List? png;
    try {
      png = await captureScreenWithoutAgent();
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
    if (!mounted) return;
    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось сделать снимок экрана')));
      return;
    }
    final shot = png;
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отправить снимок экрана?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Снимок увидят только сотрудники IT-отдела. Он попадёт в чат и в заявку.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(8),
                child: Image.memory(shot, height: 240, fit: BoxFit.contain)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (send == true) {
      await ctrl.sendScreenshot(shot);
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))), color: Colors.white),
        child: const Row(children: [
          Text('Чат с IT отделом', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ]),
      ),
      Expanded(
        child: Obx(() {
          final msgs = ctrl.messages.toList();
          _scrollDown();
          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: msgs.length,
            itemBuilder: (ctx, i) {
              final m = msgs[i];
              switch (m.kind) {
                case ChatKind.note:
                  return _Note(msg: m);
                case ChatKind.solve:
                  return _SolveCard(ticket: m.ticket!);
                case ChatKind.rate:
                  return RateCard(ticket: m.ticket!);
                case ChatKind.text:
                  return _MessageBubble(msg: m);
              }
            },
          );
        }),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
        child: Row(children: [
          Tooltip(
            message: 'Отправить снимок экрана',
            child: OutlinedButton(
              onPressed: _capturing ? null : () => _screenshot(ctrl),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _capturing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_outlined, size: 20, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 8),
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
          if (msg.image != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(msg.image!, width: 220, fit: BoxFit.cover)),
            const SizedBox(height: 6),
          ],
          Text(msg.content, style: TextStyle(fontSize: 13, color: isIn ? const Color(0xFF1E293B) : Colors.white, height: 1.45)),
          const SizedBox(height: 4),
          Text(msg.time, style: TextStyle(fontSize: 11, color: isIn ? const Color(0xFF94A3B8) : Colors.white54)),
        ]),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final ChatMessage msg;
  const _Note({required this.msg});
  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (msg.tone) {
      NoteTone.good => (const Color(0xFFF0FDF4), const Color(0xFFBBF7D0), const Color(0xFF15803D)),
      NoteTone.muted => (const Color(0xFFF8FAFC), const Color(0xFFE2E8F0), const Color(0xFF475569)),
      NoteTone.info => (const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), const Color(0xFF1D4ED8)),
    };
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
        child: Text(msg.content, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: fg)),
      ),
    );
  }
}

class _SolveCard extends StatefulWidget {
  final AgentTicket ticket;
  const _SolveCard({required this.ticket});
  @override
  State<_SolveCard> createState() => _SolveCardState();
}

class _SolveCardState extends State<_SolveCard> {
  bool _busy = false;

  Future<void> _answer(bool accepted) async {
    setState(() => _busy = true);
    await Get.find<AgentController>().answerSolution(widget.ticket, accepted: accepted);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Проблема решена?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('${t.technician.isEmpty ? 'Техник' : t.technician} закрыл заявку «${t.title}». Подтвердите или напишите, что осталось.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: _busy ? null : () => _answer(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
            child: const Text('Да, всё работает'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: _busy ? null : () => _answer(false),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFFECACA))),
            child: const Text('Нет, проблема осталась'),
          )),
        ]),
      ]),
    );
  }
}

const _rateLabels = ['', 'Плохо', 'Так себе', 'Нормально', 'Хорошо', 'Отлично'];

/// 1–5 stars and an optional comment; used in the chat and from «Мои заявки».
class RateCard extends StatefulWidget {
  final AgentTicket ticket;
  final VoidCallback? onDone;
  const RateCard({super.key, required this.ticket, this.onDone});
  @override
  State<RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<RateCard> {
  int _value = 0;
  bool _busy = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await Get.find<AgentController>().rateTicket(widget.ticket, _value, comment: _comment.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Оцените, пожалуйста, работу', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('Заявка #${t.id}${t.technician.isEmpty ? '' : ' · ${t.technician}'}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                label: '$i из 5',
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: _busy ? null : () => setState(() => _value = i),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: i <= _value ? const Color(0xFFFEF3C7) : Colors.white,
                      border: Border.all(color: i <= _value ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A), width: 1.5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.star_rounded, color: i <= _value ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),
          Text(_rateLabels[_value], style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _comment,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Комментарий, если хотите (необязательно)',
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(children: [
          ElevatedButton(
            onPressed: _value == 0 || _busy ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Отправить оценку'),
          ),
          const SizedBox(width: 8),
          if (widget.onDone == null)
            TextButton(onPressed: _busy ? null : () => Get.find<AgentController>().postponeRating(t), child: const Text('Позже')),
        ]),
      ]),
    );
  }
}
