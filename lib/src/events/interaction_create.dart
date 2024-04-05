import 'package:nyxx/nyxx.dart';

class InteractionComponentCreatedEvent {
  final String topic;
  final Message message;
  final Snowflake guildId;

  InteractionComponentCreatedEvent(this.topic, this.message, this.guildId);
}
