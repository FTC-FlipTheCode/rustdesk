import 'package:flutter/material.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  bool _showOpen = true;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))), color: Colors.white),
        child: const Row(children: [Text('Заявки', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Toggle
            Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _toggleBtn('Открытые', _showOpen, () => setState(() => _showOpen = true)),
                _toggleBtn('Закрытые', !_showOpen, () => setState(() => _showOpen = false)),
              ]),
            ),
            const SizedBox(height: 16),
            if (_showOpen)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Нет открытых заявок.\nСоздайте заявку через чат с IT отделом.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.6)),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Нет закрытых заявок.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2563EB) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : const Color(0xFF64748B))),
    ),
  );
}
