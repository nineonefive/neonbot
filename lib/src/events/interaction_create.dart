import 'package:nyxx/nyxx.dart';

class InteractionComponentCreatedEvent {
  final String topic;
  final Message message;

  InteractionComponentCreatedEvent(this.topic, this.message);
}
