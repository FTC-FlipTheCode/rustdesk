import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';
import '../bridge_client.dart';
import 'chat_page.dart' show RateCard;

/// «Мои заявки»: GLPI tickets of this computer, live statuses, confirm a solution, rate closed ones.
class TicketsPage extends StatefulWidget {
  final VoidCallback? onOpenChat;
  const TicketsPage({super.key, this.onOpenChat});
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  bool _showOpen = true;

  @override
  void initState() {
    super.initState();
    Get.find<AgentController>().loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))), color: Colors.white),
        child: Row(children: [
          const Expanded(child: Text('Мои заявки', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
          Obx(() => TextButton.icon(
                onPressed: ctrl.ticketsLoading.value ? null : ctrl.loadTickets,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(ctrl.ticketsLoading.value ? 'Обновляем…' : 'Обновить', style: const TextStyle(fontSize: 12)),
              )),
        ]),
      ),
      Expanded(
        child: Obx(() {
          final all = ctrl.tickets.toList();
          final open = all.where((t) => t.isOpen).toList();
          final closed = all.where((t) => !t.isOpen).toList();
          final shown = _showOpen ? open : closed;
          return ListView(padding: const EdgeInsets.all(20), children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _toggleBtn('Открытые (${open.length})', _showOpen, () => setState(() => _showOpen = true)),
                  _toggleBtn('Закрытые (${closed.length})', !_showOpen, () => setState(() => _showOpen = false)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            if (ctrl.ticketsError.value.isNotEmpty)
              _empty(ctrl.ticketsError.value)
            else if (shown.isEmpty && !ctrl.ticketsLoading.value)
              _empty(_showOpen ? 'Нет открытых заявок.\nОпишите проблему в чате с IT отделом — заявка создастся сама.' : 'Закрытых заявок пока нет.')
            else
              ...shown.map((t) => _TicketRow(ticket: t, onOpenChat: widget.onOpenChat)),
            const SizedBox(height: 10),
            const Text('Здесь все заявки по этому компьютеру, в том числе созданные техником по телефону.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ]);
        }),
      ),
    ]);
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(40),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.6)),
      );

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : const Color(0xFF64748B))),
        ),
      );
}

/// Colours of a status pill by GLPI status.
(Color, Color) statusColors(int status) => switch (status) {
      1 => (const Color(0xFFFEF9C3), const Color(0xFF854D0E)),
      2 || 3 => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      4 => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      5 => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };

class StatusPill extends StatelessWidget {
  final AgentTicket ticket;
  const StatusPill(this.ticket, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(ticket.status);
    final label = ticket.awaitsConfirmation ? 'Решена — подтвердите' : ticket.statusLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

String ticketDate(String raw) {
  final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (d == null) return '';
  const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${d.day} ${months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _TicketRow extends StatelessWidget {
  final AgentTicket ticket;
  final VoidCallback? onOpenChat;
  const _TicketRow({required this.ticket, this.onOpenChat});

  void _rate(BuildContext context, AgentTicket t) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(width: 440, child: RateCard(ticket: t, onDone: () => Navigator.pop(ctx))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final ctrl = Get.find<AgentController>();
    final meta = [
      if (t.date.isNotEmpty) 'Создана ${ticketDate(t.date)}',
      if (t.technician.isNotEmpty) 'Исполнитель: ${t.technician}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.awaitsConfirmation ? const Color(0xFFF0FDF4) : Colors.white,
        border: Border.all(color: t.awaitsConfirmation ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, child: Text('#${t.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(meta, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ])),
          const SizedBox(width: 10),
          if (!t.isOpen && t.rating != null)
            Text('★' * t.rating! + '☆' * (5 - t.rating!), style: const TextStyle(fontSize: 15, color: Color(0xFFF59E0B)))
          else if (!t.isOpen)
            TextButton(onPressed: () => _rate(context, t), child: const Text('Оценить работу'))
          else
            StatusPill(t),
        ]),
        if (t.awaitsConfirmation) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Row(children: [
              ElevatedButton(
                onPressed: () async {
                  if (await ctrl.answerSolution(t, accepted: true) && context.mounted) {
                    _rate(context, ctrl.tickets.firstWhereOrNull((x) => x.id == t.id) ?? t);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                child: const Text('Проблема решена'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await ctrl.answerSolution(t, accepted: false);
                  onOpenChat?.call();
                },
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFFECACA))),
                child: const Text('Нет, осталась'),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
