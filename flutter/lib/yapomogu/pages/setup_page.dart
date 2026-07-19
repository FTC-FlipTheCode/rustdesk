import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _innCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _usePhone = true;

  @override
  void dispose() {
    _innCtrl.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Obx(() => _buildCard(ctrl)),
      ),
    );
  }

  Widget _buildCard(AgentController ctrl) {
    final step = ctrl.step.value;
    return Container(
      width: 380,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepDots(currentIndex: _stepIndex(step)),
          const SizedBox(height: 22),
          if (step == SetupStep.inn) ..._innStep(ctrl),
          if (step == SetupStep.contact) ..._contactStep(ctrl),
          if (step == SetupStep.needsClarification) ..._clarificationStep(ctrl),
          if (step == SetupStep.waiting) ..._waitingStep(ctrl),
        ],
      ),
    );
  }

  int _stepIndex(SetupStep s) {
    if (s == SetupStep.inn) return 0;
    if (s == SetupStep.contact || s == SetupStep.needsClarification) return 1;
    return 2;
  }

  List<Widget> _innStep(AgentController ctrl) => [
    const Text('Ваша организация', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    const Text('Введите ИНН компании — мы найдём её в системе', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
    const SizedBox(height: 18),
    _label('ИНН организации'),
    _textField(_innCtrl, '7701234567', TextInputType.number),
    if (ctrl.error.value.isNotEmpty) ...[
      const SizedBox(height: 8),
      Text(ctrl.error.value, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
    ],
    const SizedBox(height: 16),
    _primaryBtn('Далее', ctrl.isLoading.value, () => ctrl.submitInn(_innCtrl.text)),
  ];

  List<Widget> _contactStep(AgentController ctrl) => [
    Text(ctrl.companyName.value, style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    const Text('Кто вы?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    const Text('Укажите ваш телефон или ФИО', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
    const SizedBox(height: 16),
    Row(children: [
      _toggleBtn('Телефон', _usePhone, () => setState(() => _usePhone = true)),
      const SizedBox(width: 8),
      _toggleBtn('ФИО', !_usePhone, () => setState(() => _usePhone = false)),
    ]),
    const SizedBox(height: 12),
    if (_usePhone) ...[
      _label('Номер телефона'),
      _textField(_phoneCtrl, '+7 900 000 00 00', TextInputType.phone),
    ] else ...[
      _label('Фамилия Имя'),
      _textField(_nameCtrl, 'Иванов Иван', TextInputType.name),
    ],
    if (ctrl.error.value.isNotEmpty) ...[
      const SizedBox(height: 8),
      Text(ctrl.error.value, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
    ],
    const SizedBox(height: 16),
    _primaryBtn('Отправить', ctrl.isLoading.value, () => ctrl.submitContact(
      phone: _usePhone ? _phoneCtrl.text : null,
      name: !_usePhone ? _nameCtrl.text : null,
    )),
  ];

  List<Widget> _clarificationStep(AgentController ctrl) {
    final needPhone = ctrl.clarificationHint.value == 'add_phone';
    return [
      const Text('Уточните данные', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        needPhone ? 'Найдено несколько человек с таким именем. Добавьте номер телефона.' : 'Найдено несколько человек с таким номером. Добавьте ФИО.',
        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 16),
      if (needPhone) ...[
        _label('Номер телефона'),
        _textField(_phoneCtrl, '+7 900 000 00 00', TextInputType.phone),
      ] else ...[
        _label('Фамилия Имя'),
        _textField(_nameCtrl, 'Иванов Иван', TextInputType.name),
      ],
      if (ctrl.error.value.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(ctrl.error.value, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
      ],
      const SizedBox(height: 16),
      _primaryBtn('Отправить', ctrl.isLoading.value, () => ctrl.submitContact(
        phone: needPhone ? _phoneCtrl.text : null,
        name: !needPhone ? _nameCtrl.text : null,
      )),
    ];
  }

  List<Widget> _waitingStep(AgentController ctrl) => [
    const Center(child: SizedBox(width: 52, height: 52, child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF2563EB)))),
    const SizedBox(height: 20),
    const Center(child: Text('Ожидаем подтверждения', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
    const SizedBox(height: 8),
    const Center(child: Text('Техник проверит ваши данные и активирует устройство.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
    const SizedBox(height: 20),
    _ghostBtn('Написать в IT прямо сейчас', () {
      // Open chat even before confirmed — sends via Chatwoot pending flow
      ctrl.step.value = SetupStep.confirmed; // temporary to show chat
    }),
  ];

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151), letterSpacing: .4)),
  );

  Widget _textField(TextEditingController c, String hint, TextInputType type) => TextField(
    controller: c,
    keyboardType: type,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    ),
  );

  Widget _primaryBtn(String label, bool loading, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        disabledBackgroundColor: const Color(0xFF93C5FD),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );

  Widget _ghostBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 11),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
    ),
  );

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(7),
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF374151)))),
      ),
    ),
  );
}

class _StepDots extends StatelessWidget {
  final int currentIndex;
  const _StepDots({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < 3; i++) ...[
        _dot(i),
        if (i < 2) _line(i),
      ],
    ]);
  }

  Widget _dot(int i) {
    final isDone = i < currentIndex;
    final isActive = i == currentIndex;
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? const Color(0xFF22C55E) : isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
      ),
      child: Center(child: isDone
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? Colors.white : const Color(0xFF64748B)))),
    );
  }

  Widget _line(int i) => Expanded(
    child: Container(height: 2, color: i < currentIndex ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
  );
}
