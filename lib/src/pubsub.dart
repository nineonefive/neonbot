import 'dart:async';

import 'package:event_bus/event_bus.dart';

final eventBus = EventBus();

mixin class Subscriber {
  /// The list of topics we're subscribed to
  final subscriptions = Map<Type, StreamSubscription>();
  final Finalizer<Subscriber> _finalizer =
      Finalizer<Subscriber>((s) => s.unsubscribeAll());

  /// Subscribe to events of type [T] and execute the callback [callback]
  StreamSubscription<T> subscribe<T>(void Function(T) callback) {
    if (subscriptions.containsKey(T)) {
      throw Exception('Already subscribed to topic $T');
    }

    var subscription = eventBus.on<T>().listen(callback);
    subscriptions[T] = subscription;

    // Cleanup subscriptions when this Subscriber goes out of scope
    if (subscriptions.isEmpty) {
      _finalizer.attach(this, this);
    }

    return subscription;
  }

  /// Unsubscribe from event type [T]
  void unsubscribe<T>() {
    if (subscriptions.containsKey(T)) {
      subscriptions.remove(T)?.cancel();
    }
  }

  /// Unsubscribe from all events
  void unsubscribeAll() {
    for (var sub in subscriptions.values) {
      sub.cancel();
    }

    subscriptions.clear();
  }
}
