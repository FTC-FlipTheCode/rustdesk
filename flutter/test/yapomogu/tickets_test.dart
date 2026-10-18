import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_hbb/yapomogu/bridge_client.dart';
import 'package:flutter_hbb/yapomogu/sse_client.dart';
import 'package:flutter_hbb/yapomogu/agent_controller.dart';

Map<String, dynamic> _ticket(int id, int status, {String label = '', int? rating, bool open = true}) => {
      'id': id, 'title': 'Принтер', 'status': status, 'status_label': label, 'date': '2026-10-18 10:43:00',
      'solvedate': null, 'technician': 'Алексей Петров', 'rating': rating, 'is_open': open,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BridgeClient tickets', () {
    test('getTickets parses the list', () async {
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        expect(req.url.path, '/api/device/p1/tickets');
        return http.Response.bytes(utf8.encode(jsonEncode([_ticket(4822, 5, label: 'Решена')])), 200,
            headers: {'content-type': 'application/json'});
      }));
      final list = await client.getTickets('p1');
      expect(list.single.id, 4822);
      expect(list.single.awaitsConfirmation, isTrue);
      expect(list.single.statusLabel, 'Решена');
    });

    test('checkUpdate is null on 204 and parses an offered build', () async {
      var offer = false;
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((req) async {
        expect(req.url.queryParameters['build'], '40');
        return offer
            ? http.Response(jsonEncode({'build': 41, 'sha256': 'ab', 'url': '/download/agent/ab'}), 200)
            : http.Response('', 204);
      }));
      expect(await client.checkUpdate('p1', 40), isNull);
      offer = true;
      expect((await client.checkUpdate('p1', 40))!.build, 41);
    });

    test('technicianName is null for an unknown technician', () async {
      final client = BridgeClient(baseUrl: 'http://test', httpClient: MockClient((_) async => http.Response('{}', 404)));
      expect(await client.technicianName('p1', '900111'), isNull);
    });
  });

  group('AgentController ticket events', () {
    late List<http.Request> sent;

    AgentController make() {
      SharedPreferences.setMockInitialValues({});
      sent = [];
      final http.Client mock = MockClient((req) async {
        sent.add(req);
        return http.Response(jsonEncode({'ok': true}), 200, headers: {'content-type': 'application/json'});
      });
      return AgentController(
        bridgeClient: BridgeClient(baseUrl: 'http://test', httpClient: mock),
        sseClient: SseClient(baseUrl: 'http://test', httpClient: mock),
        getPeerId: () async => 'p1',
      );
    }

    test('chat message events still become bubbles', () async {
      final ctrl = make();
      await Future.delayed(Duration.zero);
      ctrl.handleEvent({'type': 'message', 'id': 7, 'content': 'Сейчас подключусь'});
      expect(ctrl.messages.last.kind, ChatKind.text);
      expect(ctrl.messages.last.content, 'Сейчас подключусь');
    });

    test('created and in-progress tickets add notes, not bubbles', () async {
      final ctrl = make();
      await Future.delayed(Duration.zero);
      ctrl.handleEvent({'type': 'ticket', 'created': true, 'ticket': _ticket(501, 1, label: 'Новая')});
      ctrl.handleEvent({'type': 'ticket', 'ticket': _ticket(501, 2, label: 'В работе')});
      expect(ctrl.messages.map((m) => m.kind), everyElement(ChatKind.note));
      expect(ctrl.messages.first.content, contains('#501 создана'));
      expect(ctrl.messages.last.content, contains('взята в работу'));
      expect(ctrl.tickets.single.status, 2);
    });

    test('solved ticket asks to confirm; yes closes it and asks for a rating', () async {
      final ctrl = make();
      await Future.delayed(Duration.zero);
      ctrl.handleEvent({'type': 'ticket', 'ticket': _ticket(501, 5, label: 'Решена')});
      expect(ctrl.messages.last.kind, ChatKind.solve);

      await ctrl.answerSolution(ctrl.tickets.single, accepted: true);
      expect(sent.last.url.path, '/api/device/p1/tickets/501/solution');
      expect(jsonDecode(sent.last.body)['accepted'], isTrue);
      expect(ctrl.messages.any((m) => m.kind == ChatKind.solve), isFalse);
      expect(ctrl.messages.last.kind, ChatKind.rate);
      expect(ctrl.tickets.single.isOpen, isFalse);

      await ctrl.rateTicket(ctrl.tickets.single, 5, comment: 'Спасибо');
      expect(sent.last.url.path, '/api/device/p1/tickets/501/rating');
      expect(jsonDecode(sent.last.body), {'value': 5, 'comment': 'Спасибо'});
      expect(ctrl.messages.any((m) => m.kind == ChatKind.rate), isFalse);
      expect(ctrl.tickets.single.rating, 5);
    });

    test('no reopens the ticket', () async {
      final ctrl = make();
      await Future.delayed(Duration.zero);
      ctrl.handleEvent({'type': 'ticket', 'ticket': _ticket(501, 5)});
      await ctrl.answerSolution(ctrl.tickets.single, accepted: false);
      expect(jsonDecode(sent.last.body)['accepted'], isFalse);
      expect(ctrl.tickets.single.status, 2);
      expect(ctrl.messages.last.content, contains('снова в работе'));
    });
  });
}
