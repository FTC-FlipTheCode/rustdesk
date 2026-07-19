import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../agent_controller.dart';
import 'setup_page.dart';
import 'home_page.dart';

class YapomoguRootPage extends StatelessWidget {
  const YapomoguRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentController>();
    return Obx(() {
      switch (ctrl.step.value) {
        case SetupStep.confirmed:
          return const AgentHomePage();
        case SetupStep.rejected:
          return const _RejectedPage();
        default:
          return const SetupPage();
      }
    });
  }
}

class _RejectedPage extends StatelessWidget {
  const _RejectedPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 24, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❌', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Устройство отклонено', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Обратитесь к системному администратору.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}
