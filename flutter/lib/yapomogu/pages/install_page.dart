import 'package:flutter/material.dart';

/// First screen of a non-installed (portable) copy. GPO installs are silent
/// and never show it.
class YapomoguInstallPage extends StatefulWidget {
  final Future<void> Function({required bool desktopIcon}) onInstall;
  const YapomoguInstallPage({super.key, required this.onInstall});

  @override
  State<YapomoguInstallPage> createState() => _YapomoguInstallPageState();
}

class _YapomoguInstallPageState extends State<YapomoguInstallPage> {
  bool _desktopIcon = true;
  bool _installing = false;

  Future<void> _install() async {
    setState(() => _installing = true);
    await widget.onInstall(desktopIcon: _desktopIcon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          width: 400,
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
              const Text('Установка агента', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Агент нужен, чтобы IT-отдел мог помочь вам: чат, заявки и удалённый доступ по вашему разрешению. '
                'Агент будет запускаться вместе с Windows.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _desktopIcon,
                onChanged: _installing ? null : (v) => setState(() => _desktopIcon = v ?? true),
                title: const Text('Ярлык на рабочем столе', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: _installing ? null : _install,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  child: Text(_installing ? 'Устанавливаем…' : 'Установить',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              if (_installing) ...[
                const SizedBox(height: 10),
                const Text('Windows может попросить разрешение на установку — нажмите «Да».',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
