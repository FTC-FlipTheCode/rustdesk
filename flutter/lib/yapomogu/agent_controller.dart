import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bridge_client.dart';
import 'sse_client.dart';

class ChatMessage {
  final int? id;
  final String content;
  final bool isOutgoing;
  final String time;
  ChatMessage({this.id, required this.content, required this.isOutgoing, required this.time});
}

enum SetupStep { inn, contact, needsClarification, waiting, confirmed, rejected }

class AgentController extends GetxController {
  final BridgeClient bridgeClient;
  final SseClient sseClient;
  final Future<String> Function() getPeerId;

  AgentController({
    required this.bridgeClient,
    required this.sseClient,
    required this.getPeerId,
  });

  final Rx<SetupStep> step = SetupStep.inn.obs;
  final RxString peerId = ''.obs;
  final RxString companyName = ''.obs;
  final RxInt entityId = 0.obs;
  final RxString contactName = ''.obs;
  final RxString error = ''.obs;
  final RxBool isLoading = false.obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxString clarificationHint = ''.obs; // "add_phone" | "add_name"

  Timer? _pollTimer;
  StreamSubscription? _sseSub;
  int _pollInterval = 10; // seconds
  int _pollElapsed = 0;
  int _lastMessageId = 0;

  @override
  void onInit() {
    super.onInit();
    _initPeerId();
  }

  Future<void> _initPeerId() async {
    peerId.value = await getPeerId();
    await loadPersistedState();
  }

  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStep = prefs.getString('yp_step');
    if (savedStep == null) return;
    companyName.value = prefs.getString('yp_company') ?? '';
    entityId.value = prefs.getInt('yp_entity_id') ?? 0;
    contactName.value = prefs.getString('yp_contact_name') ?? '';
    step.value = SetupStep.values.firstWhere((s) => s.name == savedStep, orElse: () => SetupStep.inn);
    if (step.value == SetupStep.waiting) startPolling();
    if (step.value == SetupStep.confirmed) connectSse();
  }

  Future<void> persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yp_step', step.value.name);
    await prefs.setString('yp_company', companyName.value);
    await prefs.setInt('yp_entity_id', entityId.value);
    await prefs.setString('yp_contact_name', contactName.value);
  }

  Future<void> submitInn(String inn) async {
    error.value = '';
    isLoading.value = true;
    try {
      final result = await bridgeClient.identifyCompany(inn.trim(), peerId.value);
      companyName.value = result.companyName;
      entityId.value = result.entityId;
      step.value = SetupStep.contact;
      await persistState();
    } on BridgeException catch (e) {
      error.value = e.statusCode == 404 ? 'Компания не найдена. Проверьте ИНН.' : 'Ошибка: ${e.detail}';
    } catch (e) {
      error.value = 'Нет соединения с сервером.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitContact({String? phone, String? name}) async {
    error.value = '';
    isLoading.value = true;
    try {
      final result = await bridgeClient.identifyContact(
        peerId: peerId.value,
        entityId: entityId.value,
        phone: phone?.trim(),
        name: name?.trim(),
      );
      if (result.status == 'needs_clarification') {
        clarificationHint.value = result.hint ?? '';
        step.value = SetupStep.needsClarification;
      } else {
        step.value = SetupStep.waiting;
        startPolling();
      }
      await persistState();
    } on BridgeException catch (e) {
      error.value = 'Ошибка: ${e.detail}';
    } catch (e) {
      error.value = 'Нет соединения с сервером.';
    } finally {
      isLoading.value = false;
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollElapsed = 0;
    _pollInterval = 10;
    _poll();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleNextPoll() {
    _pollElapsed += _pollInterval;
    if (_pollElapsed >= 600) {
      _pollInterval = 60;
    } else if (_pollElapsed >= 120) {
      _pollInterval = 30;
    }
    _pollTimer = Timer(Duration(seconds: _pollInterval), _poll);
  }

  Future<void> _poll() async {
    if (step.value != SetupStep.waiting) return;
    try {
      final status = await bridgeClient.deviceStatus(peerId.value);
      if (status.status == 'confirmed') {
        step.value = SetupStep.confirmed;
        stopPolling();
        connectSse();
        await persistState();
      } else if (status.status == 'rejected') {
        step.value = SetupStep.rejected;
        stopPolling();
        await persistState();
      } else {
        _scheduleNextPoll();
      }
    } catch (_) {
      _scheduleNextPoll();
    }
  }

  void connectSse() {
    _sseSub?.cancel();
    _sseSub = sseClient.subscribe(peerId.value).listen(
      (event) {
        final content = event['content'] as String? ?? '';
        final id = event['id'] as int?;
        messages.add(ChatMessage(
          id: id,
          content: content,
          isOutgoing: true,
          time: _nowTime(),
        ));
        if (id != null) {
          _lastMessageId = id > _lastMessageId ? id : _lastMessageId;
          bridgeClient.ackMessage(peerId.value, id).catchError((_) {});
        }
      },
      onError: (_) {
        // SSE disconnected — reconnect after 5s
        Future.delayed(const Duration(seconds: 5), () {
          if (step.value == SetupStep.confirmed) connectSse();
        });
      },
    );
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final msg = ChatMessage(content: content.trim(), isOutgoing: false, time: _nowTime());
    messages.add(msg);
    await bridgeClient.sendMessage(peerId.value, content.trim());
  }

  String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    stopPolling();
    _sseSub?.cancel();
    super.onClose();
  }
}
