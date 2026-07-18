import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yapomogu/yapomogu/bridge_client.dart';

http.Client mockClient(int status, Object body) => MockClient((_) async =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}));

void main() {
  group('BridgeClient.identifyCompany', () {
    test('returns CompanyInfo on 200', () async {
      final client = BridgeClient(
        baseUrl: 'http://test',
        httpClient: mockClient(200, {'entity_id': 42, 'company_name': 'ООО Тест'}),
      );
      final result = await client.identifyCompany('7701234567', 'peer1');
      expect(result.entityId, 42);
      expect(result.companyName, 'ООО Тест');
    });

    test('throws BridgeException on 404', () async {
      final client = BridgeClient(
        baseUrl: 'http://test',
        httpClient: mockClient(404, {'detail': 'company_not_found'}),
      );
      expect(() => client.identifyCompany('0000000000', 'peer1'),
          throwsA(isA<BridgeException>().having((e) => e.statusCode, 'statusCode', 404)));
    });
  });

  group('BridgeClient.identifyContact', () {
    test('returns pending status with null contact id when not found', () async {
      final client = BridgeClient(
        baseUrl: 'http://test',
        httpClient: mockClient(200, {'status': 'pending', 'glpi_contact_id': null}),
      );
      final result = await client.identifyContact(peerId: 'p1', entityId: 1, phone: '+79991234567');
      expect(result.status, 'pending');
      expect(result.glpiContactId, isNull);
    });

    test('returns needs_clarification with hint', () async {
      final client = BridgeClient(
        baseUrl: 'http://test',
        httpClient: mockClient(200, {'status': 'needs_clarification', 'hint': 'add_phone'}),
      );
      final result = await client.identifyContact(peerId: 'p1', entityId: 1, name: 'Иванов');
      expect(result.status, 'needs_clarification');
      expect(result.hint, 'add_phone');
    });
  });

  group('BridgeClient.deviceStatus', () {
    test('returns confirmed with contact id', () async {
      final client = BridgeClient(
        baseUrl: 'http://test',
        httpClient: mockClient(200, {'status': 'confirmed', 'glpi_contact_id': 99}),
      );
      final result = await client.deviceStatus('peer1');
      expect(result.status, 'confirmed');
      expect(result.glpiContactId, 99);
    });
  });

  group('BridgeClient.getMessages', () {
    test('returns list of messages', () async {
      final client = BridgeClient(
        baseUrl: 'http://test',
        httpClient: MockClient((_) async => http.Response(
            jsonEncode([
              {'id': 1, 'content': 'Привет', 'created_at': '2026-07-18T10:00:00'},
            ]),
            200,
            headers: {'content-type': 'application/json'})),
      );
      final msgs = await client.getMessages('peer1');
      expect(msgs, hasLength(1));
      expect(msgs.first.content, 'Привет');
    });
  });
}
