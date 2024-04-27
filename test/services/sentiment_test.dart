@Skip("Github doesn't have api keys")

import 'package:neonbot/src/services/sentiment.dart';
import 'package:test/test.dart';

void main() {
  SentimentService.init();

  test('Test query', () async {
    var sentiment = await SentimentService().getSentiment("We hate neonbot");
    expect(sentiment, Sentiment.negative);
  });
}
