import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../events.dart';

abstract class MessageFormHandler {
  final ChatContext context;
  final Message message;
  final Duration expiration;
  MessageComponentInteraction? lastInteraction;

  StreamSubscription? _subscription;
  final Completer<void> _completer = Completer();

  MessageFormHandler(this.context, this.message,
      {this.expiration = Duration.zero});

  Future<bool> handle();
  Future<void> onDone() async {}
  Future<void> onExpire() async {}

  Future<void> complete() async {
    // Listen for interactions on our event bus, and call the handle function.
    _subscription = eventBus
        .on<InteractionCreateEvent>()
        .where(_listenPredicate)
        .listen(_processEvent);

    // Expire the form after a certain amount of time
    if (expiration > Duration.zero) {
      Future.delayed(expiration, () async {
        if (_subscription != null) {
          await _subscription?.cancel();
          _subscription = null;
          await message.update(
              MessageUpdateBuilder(content: ":x: Expired", components: []));

          await onExpire();

          _completer.complete();
        }
      });
    }

    return await _completer.future;
  }

  Future<void> _processEvent(InteractionCreateEvent event) async {
    // Handle function tells us that the form is done and we should stop listening
    lastInteraction = event.interaction as MessageComponentInteraction;
    var isDone = await handle();
    if (isDone) {
      await _subscription?.cancel();
      _subscription = null;

      await onDone();
      _completer.complete();
    }
  }

  /// Function that filters interactions to those specific
  /// to this form
  bool _listenPredicate(InteractionCreateEvent event) {
    if (event.interaction is MessageComponentInteraction) {
      if (event.interaction.message == message) {
        // Member is sent in guilds, user is sent in DMs
        var interactingMember = event.interaction.member;
        var originalUser = context.user;
        return interactingMember?.id == originalUser.id;
      }
    }

    return false;
  }
}
