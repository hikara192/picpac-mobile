import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../core/orders/orders_repository.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_service.dart';
import '../../_shared/application/async_retry.dart';

final class SupportInbox {
  const SupportInbox({required this.tickets, required this.supportMode});

  final List<SupportTicket> tickets;

  final bool supportMode;

  bool get isEmpty => tickets.isEmpty;
}

final class SupportInboxController extends AsyncNotifier<SupportInbox> {
  @override
  Future<SupportInbox> build() async {
    final session = ref.watch(sessionControllerProvider);
    if (!session.isAccount) {
      return const SupportInbox(tickets: <SupportTicket>[], supportMode: false);
    }
    final result = await ref
        .watch(sessionServiceProvider)
        .ensureSession(() => ref.read(apiPortProvider).supportTickets());
    switch (result) {
      case Ok<List<SupportTicket>>(:final value):
        unawaited(ref.read(pendingActionsControllerProvider.notifier).run());
        return SupportInbox(
          tickets: value,
          supportMode: session.isSupportAgent,
        );
      case Err<List<SupportTicket>>(:final error):
        await signOutIfUnauthorized(ref, error);
        throw error;
    }
  }

  Future<Failure?> reload() async {
    final result = await ref.read(apiPortProvider).supportTickets();
    if (!ref.mounted) return result.failureOrNull;
    switch (result) {
      case Ok<List<SupportTicket>>(:final value):
        state = AsyncData<SupportInbox>(
          SupportInbox(
            tickets: value,
            supportMode: ref.read(sessionControllerProvider).isSupportAgent,
          ),
        );
        return null;
      case Err<List<SupportTicket>>(:final error):
        await signOutIfUnauthorized(ref, error);
        return error;
    }
  }
}

final supportInboxProvider =
    AsyncNotifierProvider<SupportInboxController, SupportInbox>(
      SupportInboxController.new,
      isAutoDispose: true,
      retry: noProviderRetry,
    );

final class TicketThreadController extends AsyncNotifier<SupportTicket> {
  TicketThreadController(this.ticketId);

  final String ticketId;

  @override
  Future<SupportTicket> build() async {
    final result = await ref
        .watch(sessionServiceProvider)
        .ensureSession(() => ref.read(apiPortProvider).supportTicket(ticketId));
    switch (result) {
      case Ok<SupportTicket>(:final value):
        return value;
      case Err<SupportTicket>(:final error):
        await signOutIfUnauthorized(ref, error);
        throw error;
    }
  }

  Future<MessageOutcome> send(String body) async {
    final current = state.value;
    final text = body.trim();
    if (current == null || text.isEmpty) {
      return const MessageOutcome(MessageStatus.failed);
    }
    final key = const Uuid().v4();
    final local = TicketMessage(
      id: 'local_${const Uuid().v4()}',
      authorRole: ref.read(sessionControllerProvider).role,
      body: text,
      createdAt: ref.read(clockProvider).now().toUtc(),
    );
    state = AsyncData<SupportTicket>(_appended(current, local));
    final result = await ref
        .read(apiPortProvider)
        .postTicketMessage(
          PostTicketMessageRequest(ticketId: ticketId, body: text),
          idempotencyKey: key,
        );
    switch (result) {
      case Ok<SupportTicket>(:final value):
        if (ref.mounted) state = AsyncData<SupportTicket>(value);
        ref.invalidate(supportInboxProvider);
        return const MessageOutcome(MessageStatus.sent);
      case Err<SupportTicket>(:final error):
        if (OfflineQueue.shouldQueue(error)) {
          await ref
              .read(offlineQueueProvider)
              .enqueueMessage(
                PostTicketMessageRequest(ticketId: ticketId, body: text),
                idempotencyKey: key,
              );
          await ref.read(pendingActionsControllerProvider.notifier).refresh();
          return const MessageOutcome(MessageStatus.queued);
        }
        if (ref.mounted) state = AsyncData<SupportTicket>(current);
        await signOutIfUnauthorized(ref, error);
        return MessageOutcome(MessageStatus.failed, error);
    }
  }

  static SupportTicket _appended(SupportTicket ticket, TicketMessage message) =>
      SupportTicket(
        id: ticket.id,
        subject: ticket.subject,
        type: ticket.type,
        status: ticket.status,
        createdAt: ticket.createdAt,
        updatedAt: message.createdAt,
        orderId: ticket.orderId,
        messages: <TicketMessage>[...ticket.messages, message],
        slaDueAt: ticket.slaDueAt,
      );
}

final ticketThreadProvider =
    AsyncNotifierProvider.family<TicketThreadController, SupportTicket, String>(
      TicketThreadController.new,
      isAutoDispose: true,
      retry: noProviderRetry,
    );

enum MessageStatus {
  sent,

  queued,

  failed,
}

final class MessageOutcome {
  const MessageOutcome(this.status, [this.failure]);

  final MessageStatus status;

  final Failure? failure;
}

final class TicketComposerState {
  const TicketComposerState({
    this.busy = false,
    this.failure,
    this.queued = false,
  });

  final bool busy;

  final Failure? failure;

  final bool queued;
}

final class TicketComposerController extends Notifier<TicketComposerState> {
  String? _key;

  @override
  TicketComposerState build() => const TicketComposerState();

  String get attemptKey => _key ??= const Uuid().v4();

  Future<SupportTicket?> create({
    required TicketType type,
    required String subject,
    required String body,
    String? orderId,
  }) async {
    if (state.busy) return null;
    state = const TicketComposerState(busy: true);
    final request = CreateTicketRequest(
      subject: subject.trim(),
      body: body.trim(),
      type: type,
      orderId: orderId,
    );
    final result = await ref
        .read(apiPortProvider)
        .createSupportTicket(request, idempotencyKey: attemptKey);
    switch (result) {
      case Ok<SupportTicket>(:final value):
        _key = null;
        if (ref.mounted) state = const TicketComposerState();
        ref.invalidate(supportInboxProvider);
        return value;
      case Err<SupportTicket>(:final error):
        if (OfflineQueue.shouldQueue(error)) {
          await ref
              .read(offlineQueueProvider)
              .enqueueTicket(request, idempotencyKey: attemptKey);
          await ref.read(pendingActionsControllerProvider.notifier).refresh();
          _key = null;
          if (ref.mounted) {
            state = const TicketComposerState(queued: true);
          }
          return null;
        }
        await signOutIfUnauthorized(ref, error);
        if (ref.mounted) state = TicketComposerState(failure: error);
        return null;
    }
  }

  void reset() {
    _key = null;
    state = const TicketComposerState();
  }
}

final ticketComposerProvider =
    NotifierProvider<TicketComposerController, TicketComposerState>(
      TicketComposerController.new,
    );

final ticketOrderChoicesProvider = FutureProvider<List<Order>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isCustomer) return const <Order>[];
  final result = await ref.watch(ordersRepositoryProvider).page(limit: 5);
  return result.valueOrNull?.orders ?? const <Order>[];
}, retry: noProviderRetry);
