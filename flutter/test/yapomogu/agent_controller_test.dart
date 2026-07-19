import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yapomogu/yapomogu/bridge_client.dart';
import 'package:yapomogu/yapomogu/sse_client.dart';
import 'package:yapomogu/yapomogu/agent_controller.dart';

http.Client _mock(int status, Object body) => MockClient((_) async =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}));

AgentController _makeController(http.Client httpClient) {
  SharedPreferences.setMockInitialValues({});
  return AgentController(
    bridgeClient: BridgeClient(baseUrl: 'http://test', httpClient: httpClient),
    sseClient: SseClient(baseUrl: 'http://test', httpClient: httpClient),
    getPeerId: () async => 'test-peer-id',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial step is inn', () async {
    final ctrl = _makeController(_mock(200, {}));
    await Future.delayed(Duration.zero); // let onInit complete
    expect(ctrl.step.value, SetupStep.inn);
  });

  test('submitInn sets company and advances to contact step', () async {
    final ctrl = _makeController(_mock(200, {'entity_id': 5, 'company_name': 'ООО Рога'}));
    await Future.delayed(Duration.zero);
    await ctrl.submitInn('7701234567');
    expect(ctrl.step.value, SetupStep.contact);
    expect(ctrl.companyName.value, 'ООО Рога');
    expect(ctrl.entityId.value, 5);
  });

  test('submitInn 404 sets error and stays on inn', () async {
    final ctrl = _makeController(_mock(404, {'detail': 'company_not_found'}));
    await Future.delayed(Duration.zero);
    await ctrl.submitInn('0000000000');
    expect(ctrl.step.value, SetupStep.inn);
    expect(ctrl.error.value, contains('не найдена'));
  });

  test('submitContact pending advances to waiting and starts polling', () async {
    int callCount = 0;
    final ctrl = _makeController(MockClient((_) async {
      callCount++;
      // first call: identifyContact, second: deviceStatus
      if (callCount == 1) return http.Response(jsonEncode({'status': 'pending', 'glpi_contact_id': null}), 200, headers: {'content-type': 'application/json'});
      return http.Response(jsonEncode({'status': 'pending'}), 200, headers: {'content-type': 'application/json'});
    }));
    await Future.delayed(Duration.zero);
    ctrl.entityId.value = 5;
    await ctrl.submitContact(phone: '+79991234567');
    expect(ctrl.step.value, SetupStep.waiting);
    ctrl.stopPolling();
  });

  test('submitContact needs_clarification advances to needsClarification', () async {
    final ctrl = _makeController(_mock(200, {'status': 'needs_clarification', 'hint': 'add_phone'}));
    await Future.delayed(Duration.zero);
    ctrl.entityId.value = 5;
    await ctrl.submitContact(name: 'Иванов');
    expect(ctrl.step.value, SetupStep.needsClarification);
    expect(ctrl.clarificationHint.value, 'add_phone');
  });

  test('sendMessage adds outgoing ChatMessage', () async {
    final ctrl = _makeController(_mock(200, {'ok': true}));
    await Future.delayed(Duration.zero);
    ctrl.peerId.value = 'test-peer-id';
    await ctrl.sendMessage('Привет');
    expect(ctrl.messages, hasLength(1));
    expect(ctrl.messages.first.content, 'Привет');
    expect(ctrl.messages.first.isOutgoing, false);
  });
}
