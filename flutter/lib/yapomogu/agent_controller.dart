import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bridge_client.dart';
import 'build_info.dart';
import 'sse_client.dart';

/// text — a chat bubble; note — a centred status line; solve / rate — action cards for a ticket.
enum ChatKind { text, note, solve, rate }

/// Colour of a status note: info (blue), good (green), muted (grey).
enum NoteTone { info, good, muted }

class ChatMessage {
  final int? id;
  final String content;
  final bool isOutgoing; // true = from the IT department to the client
  final String time;
  final ChatKind kind;
  final NoteTone tone;
  final AgentTicket? ticket;
  final Uint8List? image;
  ChatMessage({this.id, required this.content, required this.isOutgoing, required this.time,
      this.kind = ChatKind.text, this.tone = NoteTone.info, this.ticket, this.image});
}

// Shown to clients who cannot be identified (e.g. company INN not found).
const kYpHotlinePhone = '8 800 775-75-75';

enum SetupStep { inn, contact, needsClarification, waiting, confirmed, rejected }

class AgentController extends GetxController {
  final BridgeClient bridgeClient;
  final SseClient sseClient;
  final Future<String> Function() getPeerId;
  final Future<Map<String, dynamic>?> Function()? collectSysinfo;

  AgentController({
    required this.bridgeClient,
    required this.sseClient,
    required this.getPeerId,
    this.collectSysinfo,
  });

  static const _sysinfoInterval = Duration(hours: 6);
  Timer? _sysinfoTimer;

  final Rx<SetupStep> step = SetupStep.inn.obs;
  final RxString peerId = ''.obs;
  final RxString companyName = ''.obs;
  final RxInt entityId = 0.obs;
  final RxString contactName = ''.obs;
  final RxString error = ''.obs;
  final RxBool isLoading = false.obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxString clarificationHint = ''.obs; // "add_phone" | "add_name"
  final RxList<AgentTicket> tickets = <AgentTicket>[].obs;
  final RxBool ticketsLoading = false.obs;
  final RxString ticketsError = ''.obs;

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
    final lastBuild = prefs.getInt('yp_build');
    if (lastBuild != null && lastBuild < kYpBuild) _note('Агент обновлён (сборка $kYpBuild)', NoteTone.good);
    await prefs.setInt('yp_build', kYpBuild);
    final savedStep = prefs.getString('yp_step');
    if (savedStep == null) return;
    companyName.value = prefs.getString('yp_company') ?? '';
    entityId.value = prefs.getInt('yp_entity_id') ?? 0;
    contactName.value = prefs.getString('yp_contact_name') ?? '';
    step.value = SetupStep.values.firstWhere((s) => s.name == savedStep, orElse: () => SetupStep.inn);
    if (step.value == SetupStep.waiting) startPolling();
    if (step.value == SetupStep.confirmed) {
      connectSse();
      loadTickets();
    }
    if (step.value == SetupStep.waiting || step.value == SetupStep.confirmed) startSysinfoReports();
  }

  Future<void> persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yp_step', step.value.name);
    await prefs.setString('yp_company', companyName.value);
    await prefs.setInt('yp_entity_id', entityId.value);
    await prefs.setString('yp_contact_name', contactName.value);
  }

  // On first launch RustDesk may still be generating the ID when onInit runs.
  Future<String> _ensurePeerId() async {
    if (peerId.value.isEmpty) peerId.value = await getPeerId();
    return peerId.value;
  }

  Future<void> submitInn(String inn) async {
    error.value = '';
    isLoading.value = true;
    try {
      await _ensurePeerId();
      final result = await bridgeClient.identifyCompany(inn.trim(), peerId.value);
      companyName.value = result.companyName;
      entityId.value = result.entityId;
      step.value = SetupStep.contact;
      await persistState();
    } on BridgeException catch (e) {
      error.value = e.statusCode == 404
          ? 'Организацию с таким ИНН не нашли. Проверьте цифры или позвоните на горячую линию: $kYpHotlinePhone'
          : 'Ошибка: ${e.detail}';
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
      await _ensurePeerId();
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
        startSysinfoReports();
      }
      await persistState();
    } on BridgeException catch (e) {
      if (e.statusCode == 422 && e.detail == 'company_not_identified') {
        // Saved company is unknown to the bridge (e.g. an old registration): start over.
        step.value = SetupStep.inn;
        entityId.value = 0;
        companyName.value = '';
        error.value = 'Организация не определена. Введите ИНН ещё раз.';
        await persistState();
        return;
      }
      error.value = 'Ошибка: ${e.detail}';
    } catch (e) {
      error.value = 'Нет соединения с сервером.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Send the hardware snapshot now and every few hours; failures only wait for the next round.
  void startSysinfoReports() {
    if (collectSysinfo == null) return;
    _sysinfoTimer?.cancel();
    reportSysinfo();
    _sysinfoTimer = Timer.periodic(_sysinfoInterval, (_) => reportSysinfo());
  }

  Future<void> reportSysinfo() async {
    try {
      final report = await collectSysinfo?.call();
      if (report == null) return;
      await bridgeClient.reportSysinfo(await _ensurePeerId(), report);
    } catch (_) {}
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
        loadTickets();
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
      handleEvent,
      onError: (_) {
        // SSE disconnected — reconnect after 5s
        Future.delayed(const Duration(seconds: 5), () {
          if (step.value == SetupStep.confirmed) connectSse();
        });
      },
    );
  }

  /// One SSE event: a technician's chat message, or a ticket status change.
  void handleEvent(Map<String, dynamic> event) {
    if (event['type'] == 'ticket') {
      onTicketEvent(AgentTicket.fromJson(event['ticket'] as Map<String, dynamic>), created: event['created'] == true);
      return;
    }
    final content = event['content'] as String? ?? '';
    final id = event['id'] as int?;
    messages.add(ChatMessage(id: id, content: content, isOutgoing: true, time: _nowTime()));
    if (id != null) {
      _lastMessageId = id > _lastMessageId ? id : _lastMessageId;
      bridgeClient.ackMessage(peerId.value, id).catchError((_) {});
    }
  }

  void _note(String text, [NoteTone tone = NoteTone.info]) =>
      messages.add(ChatMessage(content: text, isOutgoing: true, time: _nowTime(), kind: ChatKind.note, tone: tone));

  void _upsertTicket(AgentTicket t) {
    final i = tickets.indexWhere((x) => x.id == t.id);
    if (i < 0) {
      tickets.insert(0, t);
    } else {
      tickets[i] = t;
    }
  }

  void onTicketEvent(AgentTicket t, {bool created = false}) {
    _upsertTicket(t);
    final who = t.technician.isEmpty ? '' : ' · ${t.technician}';
    if (created) {
      _note('Заявка #${t.id} создана · «${t.title}»');
      return;
    }
    switch (t.status) {
      case 2:
      case 3:
        _note('Заявка #${t.id} взята в работу$who');
        break;
      case 4:
        _note('Заявка #${t.id} ждёт вашего ответа$who');
        break;
      case 5:
        _note('Заявка #${t.id} отмечена как решённая', NoteTone.good);
        _removeCards(t.id);
        messages.add(ChatMessage(content: '', isOutgoing: true, time: _nowTime(), kind: ChatKind.solve, ticket: t));
        break;
      case 6:
        _note('Заявка #${t.id} закрыта', NoteTone.muted);
        break;
    }
  }

  void _removeCards(int ticketId) =>
      messages.removeWhere((m) => (m.kind == ChatKind.solve || m.kind == ChatKind.rate) && m.ticket?.id == ticketId);

  Future<void> loadTickets() async {
    ticketsLoading.value = true;
    ticketsError.value = '';
    try {
      tickets.assignAll(await bridgeClient.getTickets(await _ensurePeerId()));
    } catch (_) {
      ticketsError.value = 'Не удалось загрузить заявки. Проверьте интернет и попробуйте ещё раз.';
    } finally {
      ticketsLoading.value = false;
    }
  }

  /// "Проблема решена?" — yes closes the ticket and asks for a rating, no reopens it.
  Future<bool> answerSolution(AgentTicket t, {required bool accepted, String comment = ''}) async {
    try {
      await bridgeClient.answerSolution(await _ensurePeerId(), t.id, accepted: accepted, comment: comment);
    } catch (_) {
      _note('Не удалось отправить ответ по заявке #${t.id}. Попробуйте ещё раз.', NoteTone.muted);
      return false;
    }
    _removeCards(t.id);
    if (accepted) {
      final closed = t.copyWith(status: 6, statusLabel: 'Закрыта', isOpen: false);
      _upsertTicket(closed);
      messages.add(ChatMessage(content: 'Да, всё работает', isOutgoing: false, time: _nowTime()));
      messages.add(ChatMessage(content: '', isOutgoing: true, time: _nowTime(), kind: ChatKind.rate, ticket: closed));
    } else {
      _upsertTicket(t.copyWith(status: 2, statusLabel: 'В работе'));
      messages.add(ChatMessage(content: 'Нет, проблема осталась', isOutgoing: false, time: _nowTime()));
      _note('Заявка #${t.id} снова в работе. Техник получил ваше сообщение.');
    }
    return true;
  }

  Future<bool> rateTicket(AgentTicket t, int value, {String comment = ''}) async {
    try {
      await bridgeClient.rateTicket(await _ensurePeerId(), t.id, value, comment: comment);
    } catch (_) {
      _note('Не удалось сохранить оценку. Попробуйте ещё раз.', NoteTone.muted);
      return false;
    }
    _removeCards(t.id);
    _upsertTicket(t.copyWith(rating: value));
    _note('Спасибо! Оценка ${'★' * value} сохранена в заявке #${t.id}', NoteTone.good);
    return true;
  }

  void postponeRating(AgentTicket t) {
    _removeCards(t.id);
    _note('Оценить можно позже в разделе «Мои заявки»', NoteTone.muted);
  }

  Future<bool> sendScreenshot(Uint8List png) async {
    try {
      await bridgeClient.sendScreenshot(await _ensurePeerId(), png);
    } catch (_) {
      _note('Снимок не отправился. Попробуйте ещё раз.', NoteTone.muted);
      return false;
    }
    messages.add(ChatMessage(content: 'Снимок экрана', isOutgoing: false, time: _nowTime(), image: png));
    _note('Снимок отправлен в IT-отдел и приложен к заявке', NoteTone.muted);
    return true;
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
    _sysinfoTimer?.cancel();
    _sseSub?.cancel();
    super.onClose();
  }
}
