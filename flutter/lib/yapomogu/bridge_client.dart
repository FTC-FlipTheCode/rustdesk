import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CompanyInfo {
  final int entityId;
  final String companyName;
  CompanyInfo({required this.entityId, required this.companyName});
  factory CompanyInfo.fromJson(Map<String, dynamic> j) =>
      CompanyInfo(entityId: j['entity_id'] as int, companyName: j['company_name'] as String);
}

class ContactResult {
  final String status; // "pending", "needs_clarification"
  final int? glpiContactId;
  final String? hint; // "add_phone" | "add_name"
  ContactResult({required this.status, this.glpiContactId, this.hint});
  factory ContactResult.fromJson(Map<String, dynamic> j) => ContactResult(
        status: j['status'] as String,
        glpiContactId: j['glpi_contact_id'] as int?,
        hint: j['hint'] as String?,
      );
}

class DeviceStatus {
  final String status; // "pending", "confirmed", "rejected"
  final int? glpiContactId;
  DeviceStatus({required this.status, this.glpiContactId});
  factory DeviceStatus.fromJson(Map<String, dynamic> j) =>
      DeviceStatus(status: j['status'] as String, glpiContactId: j['glpi_contact_id'] as int?);
}

class AgentMessage {
  final int id;
  final String content;
  final String createdAt;
  AgentMessage({required this.id, required this.content, required this.createdAt});
  factory AgentMessage.fromJson(Map<String, dynamic> j) => AgentMessage(
        id: j['id'] as int,
        content: j['content'] as String,
        createdAt: j['created_at'] as String,
      );
}

/// GLPI ticket of this computer as the bridge shows it (status: 1 new … 5 solved, 6 closed).
class AgentTicket {
  final int id;
  final String title;
  final int status;
  final String statusLabel;
  final String date;
  final String technician;
  final int? rating;
  final bool isOpen;
  const AgentTicket({required this.id, required this.title, required this.status, required this.statusLabel,
      this.date = '', this.technician = '', this.rating, this.isOpen = true});

  factory AgentTicket.fromJson(Map<String, dynamic> j) => AgentTicket(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        status: j['status'] as int? ?? 0,
        statusLabel: j['status_label'] as String? ?? '',
        date: j['date'] as String? ?? '',
        technician: j['technician'] as String? ?? '',
        rating: j['rating'] as int?,
        isOpen: j['is_open'] as bool? ?? true,
      );

  /// The technician marked it solved; the client confirms or reopens it.
  bool get awaitsConfirmation => status == 5;

  AgentTicket copyWith({int? status, String? statusLabel, int? rating, bool? isOpen}) => AgentTicket(
      id: id, title: title, status: status ?? this.status, statusLabel: statusLabel ?? this.statusLabel,
      date: date, technician: technician, rating: rating ?? this.rating, isOpen: isOpen ?? this.isOpen);
}

/// A newer agent build the bridge wants this computer to install.
class AgentUpdate {
  final int build;
  final String sha256;
  final String url;
  const AgentUpdate({required this.build, required this.sha256, required this.url});
  factory AgentUpdate.fromJson(Map<String, dynamic> j) =>
      AgentUpdate(build: j['build'] as int, sha256: j['sha256'] as String, url: j['url'] as String);
}

class BridgeException implements Exception {
  final int statusCode;
  final String detail;
  BridgeException(this.statusCode, this.detail);
  @override
  String toString() => 'BridgeException($statusCode): $detail';
}

class BridgeClient {
  final String baseUrl;
  final http.Client _http;

  BridgeClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      String detail;
      try {
        final errData = jsonDecode(resp.body) as Map<String, dynamic>;
        detail = errData['detail']?.toString() ?? resp.body;
      } catch (_) {
        detail = resp.body;
      }
      throw BridgeException(resp.statusCode, detail);
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final resp = await _http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    final data = jsonDecode(resp.body);
    if (resp.statusCode >= 400) throw BridgeException(resp.statusCode, (data is Map ? data['detail'] : resp.body).toString());
    return data as Map<String, dynamic>;
  }

  Future<CompanyInfo> identifyCompany(String inn, String peerId) async {
    final data = await _post('/api/identify/company', {'inn': inn, 'peer_id': peerId});
    return CompanyInfo.fromJson(data);
  }

  Future<ContactResult> identifyContact({
    required String peerId,
    required int entityId,
    String? phone,
    String? name,
  }) async {
    final data = await _post('/api/identify/contact', {
      'peer_id': peerId,
      'entity_id': entityId,
      if (phone != null) 'phone': phone,
      if (name != null) 'name': name,
    });
    return ContactResult.fromJson(data);
  }

  Future<DeviceStatus> deviceStatus(String peerId) async {
    final data = await _get('/api/device/status/$peerId');
    return DeviceStatus.fromJson(data);
  }

  Future<void> sendMessage(String peerId, String content) async {
    await _post('/api/device/$peerId/message', {'content': content});
  }

  Future<List<AgentMessage>> getMessages(String peerId, {int since = 0}) async {
    final resp = await _http.get(
      Uri.parse('$baseUrl/api/device/$peerId/messages?since=$since'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw BridgeException(resp.statusCode, resp.body);
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => AgentMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Hardware snapshot; the bridge answers 204 with an empty body.
  Future<void> reportSysinfo(String peerId, Map<String, dynamic> report) async {
    final resp = await _http.post(
      Uri.parse('$baseUrl/api/device/$peerId/sysinfo'),
      headers: _headers,
      body: jsonEncode(report),
    );
    if (resp.statusCode >= 400) {
      String detail = resp.body;
      try {
        detail = (jsonDecode(resp.body) as Map<String, dynamic>)['detail']?.toString() ?? resp.body;
      } catch (_) {}
      throw BridgeException(resp.statusCode, detail);
    }
  }

  Future<List<AgentTicket>> getTickets(String peerId) async {
    final resp = await _http.get(Uri.parse('$baseUrl/api/device/$peerId/tickets'), headers: _headers);
    if (resp.statusCode >= 400) throw BridgeException(resp.statusCode, resp.body);
    final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
    return list.map((e) => AgentTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> answerSolution(String peerId, int ticketId, {required bool accepted, String comment = ''}) async {
    await _post('/api/device/$peerId/tickets/$ticketId/solution', {'accepted': accepted, 'comment': comment});
  }

  Future<void> rateTicket(String peerId, int ticketId, int value, {String comment = ''}) async {
    await _post('/api/device/$peerId/tickets/$ticketId/rating', {'value': value, 'comment': comment});
  }

  Future<void> sendScreenshot(String peerId, Uint8List png) async {
    final resp = await _http.post(Uri.parse('$baseUrl/api/device/$peerId/screenshot'),
        headers: {'Content-Type': 'image/png'}, body: png);
    if (resp.statusCode >= 400) throw BridgeException(resp.statusCode, resp.body);
  }

  /// Staff name for a technician's RustDesk ID, or null when the panel does not know it.
  Future<String?> technicianName(String peerId, String rustdeskId) async {
    final resp = await _http.get(Uri.parse('$baseUrl/api/device/$peerId/technician/$rustdeskId'), headers: _headers);
    if (resp.statusCode != 200) return null;
    return (jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>)['name'] as String?;
  }

  Future<void> sessionEnded(String peerId) async {
    await _post('/api/device/$peerId/session-ended', {});
  }

  /// The build to install, or null when this one is current (HTTP 204).
  Future<AgentUpdate?> checkUpdate(String peerId, int build) async {
    final resp = await _http.get(Uri.parse('$baseUrl/api/device/$peerId/update?build=$build'), headers: _headers);
    if (resp.statusCode == 204) return null;
    if (resp.statusCode >= 400) throw BridgeException(resp.statusCode, resp.body);
    return AgentUpdate.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<int>> download(String path) async {
    final resp = await _http.get(Uri.parse('$baseUrl$path'));
    if (resp.statusCode != 200) throw BridgeException(resp.statusCode, 'download failed');
    return resp.bodyBytes;
  }

  Future<void> ackMessage(String peerId, int messageId) async {
    await _post('/api/device/$peerId/ack', {'message_id': messageId});
  }

  void dispose() => _http.close();
}
