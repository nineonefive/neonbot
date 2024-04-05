import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:neonbot/src/events/interaction_create.dart';

final eventBus = EventBus();

extension InteractComponent on EventBus {
  Stream<InteractionComponentCreatedEvent> onInteractionComponentCreated(
      String topic) {
    return on<InteractionComponentCreatedEvent>()
        .where((event) => event.topic == topic);
  }
}
