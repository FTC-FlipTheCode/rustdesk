import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';
import '../sysinfo_collector.dart';

class SysinfoPage extends StatefulWidget {
  const SysinfoPage({super.key});
  @override
  State<SysinfoPage> createState() => _SysinfoPageState();
}

class _SysinfoPageState extends State<SysinfoPage> {
  SysInfo? _info;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ctrl = Get.find<AgentController>();
      final info = await SysinfoCollector().collect(ctrl.peerId.value);
      setState(() { _info = info; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      Expanded(child: _body()),
    ]);
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))), color: Colors.white),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Информация о системе', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      OutlinedButton(
        onPressed: _loading ? null : _load,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        child: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Обновить', style: TextStyle(fontSize: 12, color: Color(0xFF374151))),
      ),
    ]),
  );

  Widget _body() {
    if (_loading && _info == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));
    if (_info == null) return const SizedBox();
    final s = _info!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _grid([
          _card('ID для подключения', s.peerId, isId: true),
          _card('Компьютер', s.computerName),
          _card('Операционная система', s.os, wide: false),
          _card('Процессор', s.cpu),
          _card('Оперативная память', s.ram),
          _card('IP-адрес', s.ip),
          _card('Последняя перезагрузка', s.lastBoot),
          _diskCard(s),
        ]),
        const SizedBox(height: 16),
        _HealthSection(items: s.health, onRecheck: _load),
      ]),
    );
  }

  Widget _grid(List<Widget> cards) => Wrap(spacing: 12, runSpacing: 12, children: cards);

  Widget _card(String label, String value, {bool wide = false, bool isId = false}) => SizedBox(
    width: wide ? double.infinity : 240,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: .5)),
        const SizedBox(height: 6),
        isId
            ? Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF2563EB), letterSpacing: 3, fontFamily: 'monospace'))
            : Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      ]),
    ),
  );

  Widget _diskCard(SysInfo s) => SizedBox(
    width: 240,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ДИСК C:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: .5)),
        const SizedBox(height: 6),
        Text(s.disk, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: 1 - s.diskFreePercent,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(s.diskFreePercent * 100).toStringAsFixed(0)}% свободно', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ]),
    ),
  );
}

class _HealthSection extends StatelessWidget {
  final List<HealthItem> items;
  final VoidCallback onRecheck;
  const _HealthSection({required this.items, required this.onRecheck});

  @override
  Widget build(BuildContext context) {
    final hasIssues = items.any((i) => i.severity == HealthSeverity.warn || i.severity == HealthSeverity.err);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Состояние системы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: hasIssues ? const Color(0xFFFEF9C3) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(hasIssues ? 'Требует внимания' : 'Хорошее', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: hasIssues ? const Color(0xFF854D0E) : const Color(0xFF15803D))),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onRecheck,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              minimumSize: Size.zero,
            ),
            child: const Text('Проверить', style: TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ),
        ]),
        const SizedBox(height: 12),
        ...items.map((item) => _HealthItemWidget(item: item)),
      ]),
    );
  }
}

class _HealthItemWidget extends StatelessWidget {
  final HealthItem item;
  const _HealthItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, titleColor) = switch (item.severity) {
      HealthSeverity.err  => (const Color(0xFFFEF2F2), const Color(0xFFFECACA), '🔴', const Color(0xFFDC2626)),
      HealthSeverity.warn => (const Color(0xFFFFFBEB), const Color(0xFFFDE68A), '⚠️', const Color(0xFF92400E)),
      HealthSeverity.info => (const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), 'ℹ️', const Color(0xFF1D4ED8)),
      HealthSeverity.ok   => (const Color(0xFFF0FDF4), const Color(0xFFBBF7D0), '✅', const Color(0xFF15803D)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(9)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor)),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(item.subtitle!, style: TextStyle(fontSize: 12, color: titleColor.withOpacity(.75))),
          ],
        ])),
      ]),
    );
  }
}
