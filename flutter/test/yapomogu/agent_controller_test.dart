import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_hbb/yapomogu/bridge_client.dart';
import 'package:flutter_hbb/yapomogu/sse_client.dart';
import 'package:flutter_hbb/yapomogu/agent_controller.dart';

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
    expect(ctrl.error.value, contains('не нашли'));
    expect(ctrl.error.value, contains(kYpHotlinePhone));
  });

  test('submitInn re-reads peer id when it was empty at startup', () async {
    SharedPreferences.setMockInitialValues({});
    String? sentPeerId;
    final ctrl = AgentController(
      bridgeClient: BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        sentPeerId = jsonDecode(req.body)['peer_id'] as String?;
        return http.Response(jsonEncode({'entity_id': 5, 'company_name': 'ООО Рога'}), 200,
            headers: {'content-type': 'application/json'});
      })),
      sseClient: SseClient(baseUrl: 'http://test', httpClient: _mock(200, {})),
      getPeerId: () async => 'late-peer-id',
    );
    ctrl.peerId.value = ''; // ID was not generated yet when the agent started
    await ctrl.submitInn('7701234567');
    expect(sentPeerId, 'late-peer-id');
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

  test('submitContact reports the PC hardware once registered', () async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final ctrl = AgentController(
      bridgeClient: BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        paths.add(req.url.path);
        if (req.url.path.endsWith('/sysinfo')) return http.Response('', 204);
        return http.Response(jsonEncode({'status': 'pending', 'glpi_contact_id': null}), 200,
            headers: {'content-type': 'application/json'});
      })),
      sseClient: SseClient(baseUrl: 'http://test', httpClient: _mock(200, {})),
      getPeerId: () async => 'test-peer-id',
      collectSysinfo: () async => {'hostname': 'PC'},
    );
    ctrl.peerId.value = 'test-peer-id';
    ctrl.entityId.value = 5;
    await ctrl.submitContact(phone: '+79991234567');
    ctrl.stopPolling();
    await Future.delayed(Duration.zero);
    expect(paths, contains('/api/device/test-peer-id/sysinfo'));
  });

  test('submitContact with an unidentified company sends the client back to the INN step', () async {
    final ctrl = _makeController(_mock(422, {'detail': 'company_not_identified'}));
    await Future.delayed(Duration.zero);
    ctrl.step.value = SetupStep.contact;
    ctrl.entityId.value = 0;
    await ctrl.submitContact(name: 'Иванов');
    expect(ctrl.step.value, SetupStep.inn);
    expect(ctrl.error.value, contains('ИНН'));
  });
}
