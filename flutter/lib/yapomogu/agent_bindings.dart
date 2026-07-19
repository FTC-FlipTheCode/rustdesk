import 'package:get/get.dart';
import 'bridge_client.dart';
import 'sse_client.dart';
import 'agent_controller.dart';

// Call AgentBindings.init() once at app startup (in main.dart or desktop_home_page.dart initState)
class AgentBindings {
  static const _bridgeUrl = 'https://agent.yapomogu.com';

  static void init(Future<String> Function() getPeerId) {
    if (Get.isRegistered<AgentController>()) return; // already initialized
    final client = BridgeClient(baseUrl: _bridgeUrl);
    final sse = SseClient(baseUrl: _bridgeUrl);
    Get.put(AgentController(
      bridgeClient: client,
      sseClient: sse,
      getPeerId: getPeerId,
    ), permanent: true);
  }
}
