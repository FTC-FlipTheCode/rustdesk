import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SseClient {
  final String baseUrl;
  final http.Client _http;

  SseClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Stream<Map<String, dynamic>> subscribe(String peerId) async* {
    final request = http.Request('GET', Uri.parse('$baseUrl/api/device/$peerId/events'));
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    final response = await _http.send(request);
    final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final payload = line.substring(6).trim();
        if (payload.isNotEmpty) {
          try {
            yield jsonDecode(payload) as Map<String, dynamic>;
          } catch (_) {
            // malformed JSON — skip
          }
        }
      }
      // keepalive comments (`: keepalive`) are silently ignored
    }
  }

  void dispose() => _http.close();
}
