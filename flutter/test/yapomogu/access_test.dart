import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_hbb/yapomogu/access_policy.dart';
import 'package:flutter_hbb/yapomogu/access_sync.dart';
import 'package:flutter_hbb/yapomogu/bridge_client.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('planFor', () {
    test('switched on with a password: permanent password and no click', () {
      final plan = planFor(unattended: true, password: 'pw-123');
      expect(plan.permanentPassword, 'pw-123');
      expect(plan.approveMode, 'password');
      expect(plan.verificationMethod, 'use-permanent-password');
    });

    test('switched off, or no password yet: the stock behaviour with no permanent password', () {
      expect(planFor(unattended: false, password: 'pw-123'),
          const AccessPlan(approveMode: '', verificationMethod: ''));
      expect(planFor(unattended: true, password: null), const AccessPlan(approveMode: '', verificationMethod: ''));
      expect(planFor(unattended: true, password: ''), const AccessPlan(approveMode: '', verificationMethod: ''));
    });
  });

  group('BridgeClient access', () {
    test('enroll returns the secret, and null when the bridge already gave one (409)', () async {
      var status = 200;
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        expect(req.url.path, '/api/device/p1/enroll');
        return status == 200 ? _json({'agent_secret': 's3cret'}) : _json({'detail': 'already_enrolled'}, status);
      }));
      expect(await client.enroll('p1'), 's3cret');
      status = 409;
      expect(await client.enroll('p1'), isNull);
    });

    test('fetchAccess sends the secret and parses the state; null when refused', () async {
      var status = 200;
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        expect(req.url.path, '/api/device/p1/access');
        expect(req.headers['X-Agent-Secret'], 's3cret');
        return status == 200 ? _json({'unattended': true, 'password': 'pw-123'}) : _json({'detail': 'bad_agent_secret'}, status);
      }));
      final state = await client.fetchAccess('p1', 's3cret');
      expect(state!.unattended, isTrue);
      expect(state.password, 'pw-123');
      status = 403;
      expect(await client.fetchAccess('p1', 's3cret'), isNull);
    });
  });

  group('AccessSync', () {
    test('enrolls once, keeps the secret and applies the plan each round', () async {
      SharedPreferences.setMockInitialValues({});
      var enrolls = 0;
      final plans = <AccessPlan>[];
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        if (req.method == 'POST') {
          enrolls++;
          return _json({'agent_secret': 's3cret'});
        }
        expect(req.headers['X-Agent-Secret'], 's3cret');
        return _json({'unattended': true, 'password': 'pw-123'});
      }));
      final sync = AccessSync(bridge: client, getPeerId: () async => 'p1', apply: (p) async => plans.add(p));

      await sync.sync();
      await sync.sync();

      expect(enrolls, 1);
      expect(plans.length, 2);
      expect(plans.last.permanentPassword, 'pw-123');
      expect((await SharedPreferences.getInstance()).getString('yp_agent_secret'), 's3cret');
    });

    test('touches nothing while the bridge does not know the device yet', () async {
      SharedPreferences.setMockInitialValues({});
      final plans = <AccessPlan>[];
      final client = BridgeClient(
          baseUrl: 'http://test', httpClient: MockClient((req) async => _json({'detail': 'device_not_found'}, 404)));
      final sync = AccessSync(bridge: client, getPeerId: () async => 'p1', apply: (p) async => plans.add(p));

      await sync.sync();

      expect(plans, isEmpty);
      expect((await SharedPreferences.getInstance()).getString('yp_agent_secret'), isNull);
    });

    test('switching the mode off clears the permanent password', () async {
      SharedPreferences.setMockInitialValues({'yp_agent_secret': 's3cret'});
      final plans = <AccessPlan>[];
      final client = BridgeClient(
          baseUrl: 'http://test', httpClient: MockClient((req) async => _json({'unattended': false, 'password': null})));
      final sync = AccessSync(bridge: client, getPeerId: () async => 'p1', apply: (p) async => plans.add(p));

      await sync.sync();

      expect(plans.single.permanentPassword, isNull);
      expect(plans.single.approveMode, '');
    });

    test('a bridge outage leaves the settings alone', () async {
      SharedPreferences.setMockInitialValues({'yp_agent_secret': 's3cret'});
      final plans = <AccessPlan>[];
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async => throw Exception('offline')));
      final sync = AccessSync(bridge: client, getPeerId: () async => 'p1', apply: (p) async => plans.add(p));

      await sync.sync();

      expect(plans, isEmpty);
    });
  });
}
