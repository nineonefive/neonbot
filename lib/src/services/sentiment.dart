import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

import 'credentials.dart';

enum Sentiment {
  positive("positive"),
  negative("negative"),
  neutral("neutral");

  final String name;

  const Sentiment(this.name);

  static Sentiment fromName(String name) {
    for (var sentiment in values) {
      if (sentiment.name == name) {
        return sentiment;
      }
    }

    throw StateError("Unknown sentiment $name");
  }
}

class SentimentService {
  static late final SentimentService _instance;

  factory SentimentService() => _instance;

  static void init() {
    _instance = SentimentService._();
  }

  late final String huggingFaceToken;

  SentimentService._() {
    CredentialsService()
        .getToken("huggingFace")
        .then((t) => huggingFaceToken = t);
  }

  Future<Sentiment> getSentiment(String text) async {
    var url = Uri.https('api-inference.huggingface.co',
        '/models/cardiffnlp/twitter-roberta-base-sentiment-latest');
    var headers = {"Authorization": "Bearer $huggingFaceToken"};

    // Send our text to hugging face model
    var response =
        await http.post(url, headers: headers, body: {"inputs": text});
    var output = (jsonDecode(response.body)[0] ?? []) as List<dynamic>;

    // Sort the output by weight and return the sentiment with the
    // largest predicted value.
    var label = output.sortedBy((e) => e["score"] as num).last["label"];
    return Sentiment.fromName(label);
  }
}
