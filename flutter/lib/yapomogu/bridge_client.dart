import 'dart:convert';
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
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) throw BridgeException(resp.statusCode, data['detail']?.toString() ?? resp.body);
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

  Future<void> ackMessage(String peerId, int messageId) async {
    await _post('/api/device/$peerId/ack', {'message_id': messageId});
  }

  void dispose() => _http.close();
}
