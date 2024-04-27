import 'package:neonbot/src/services/credentials.dart';
import 'package:test/test.dart';

void main() {
  test('Test discord token', () async {
    // This should throw a StateError if none is found
    var discordToken = await CredentialsService().getToken("discord");
    expect(discordToken, isNotEmpty);
  }, skip: "Github doesn't have api keys");

  test('Test huggingface token', () async {
    // This should throw a StateError if none is found
    var hfToken = await CredentialsService().getToken("huggingFace");
    expect(hfToken, isNotEmpty);
  }, skip: "Github doesn't have api keys");

  test('Test unknown token', () async {
    // This should throw a StateError
    expect(() => CredentialsService().getToken("unknown"), throwsStateError,
        skip: "Github doesn't have api keys");
  });
}
