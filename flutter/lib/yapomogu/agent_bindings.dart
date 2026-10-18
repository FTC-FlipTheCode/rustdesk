import 'package:get/get.dart';
import 'bridge_client.dart';
import 'sse_client.dart';
import 'agent_controller.dart';
import 'sysinfo_collector.dart';
import 'updater.dart';

// Call AgentBindings.init() once at app startup (in main.dart or desktop_home_page.dart initState)
class AgentBindings {
  static const bridgeUrl = 'https://agent.yapomogu.com';

  static void init(Future<String> Function() getPeerId) {
    if (Get.isRegistered<AgentController>()) return; // already initialized
    final client = BridgeClient(baseUrl: bridgeUrl);
    final sse = SseClient(baseUrl: bridgeUrl);
    Get.put(AgentController(
      bridgeClient: client,
      sseClient: sse,
      getPeerId: getPeerId,
      collectSysinfo: SysinfoCollector().collectReport,
    ), permanent: true);
    AgentUpdater(bridge: client, getPeerId: getPeerId).start();
  }
}
