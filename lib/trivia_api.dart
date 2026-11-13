import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum Answer {
  trueAnswer('True'),
  falseAnswer('False');

  const Answer(this.label);

  final String label;

  static Answer fromEncoded(Object? value) {
    if (value is String) {
      switch (_decode(value)) {
        case 'True':
          return Answer.trueAnswer;
        case 'False':
          return Answer.falseAnswer;
      }
    }
    throw const FormatException('Invalid boolean answer');
  }
}

String _decode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    throw const FormatException('Invalid URL encoding');
  }
}

class ScienceQuestion {
  const ScienceQuestion._(this.text, this.correctAnswer, this.incorrectAnswer);

  final String text;
  final Answer correctAnswer;
  final Answer incorrectAnswer;

  factory ScienceQuestion.fromJson(Object? entry) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('Invalid question entry');
    }
    final encodedText = entry['question'];
    final incorrectAnswers = entry['incorrect_answers'];
    if (encodedText is! String ||
        incorrectAnswers is! List ||
        incorrectAnswers.length != 1) {
      throw const FormatException('Missing question or answer');
    }
    final text = _decode(encodedText).trim();
    final correct = Answer.fromEncoded(entry['correct_answer']);
    final incorrect = Answer.fromEncoded(incorrectAnswers.single);
    if (text.isEmpty || correct == incorrect) {
      throw const FormatException('Empty question or duplicate answers');
    }
    return ScienceQuestion._(text, correct, incorrect);
  }
}

class TriviaException implements Exception {
  const TriviaException(this.message);

  final String message;
}

class TriviaApi {
  TriviaApi(
    this._client, {
    this.timeout = const Duration(seconds: 12),
    this.requestInterval = const Duration(seconds: 5),
  });

  static const questionCount = 5;
  static const category = 'Science & Nature';

  static final endpoint = Uri.https('opentdb.com', '/api.php', {
    'amount': '$questionCount',
    'category': '17',
    'difficulty': 'medium',
    'type': 'boolean',
    'encode': 'url3986',
  });

  final http.Client _client;
  final Duration timeout;
  final Duration requestInterval;
  final _sinceRequest = Stopwatch();

  Future<List<ScienceQuestion>> fetchQuestions() async {
    // Recheck after each wait in case another caller started a request.
    while (_sinceRequest.isRunning && _sinceRequest.elapsed < requestInterval) {
      await Future<void>.delayed(requestInterval - _sinceRequest.elapsed);
    }
    _sinceRequest
      ..reset()
      ..start();

    try {
      final response = await _client.get(endpoint).timeout(timeout);
      if (response.statusCode == 429) {
        _rateLimited();
      }
      if (response.statusCode != 200) {
        throw TriviaException(
          'Open Trivia DB returned HTTP ${response.statusCode}. Please try again.',
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['response_code'] is! int) {
        throw const FormatException('Missing response code');
      }
      final code = data['response_code'];
      if (code == 5) {
        _rateLimited();
      }
      if (code != 0) {
        throw TriviaException(
          'Open Trivia DB could not provide questions (code $code). Please try again.',
        );
      }

      final results = data['results'];
      if (results is! List || results.length != questionCount) {
        throw const FormatException('Expected five questions');
      }
      return List.unmodifiable(results.map(ScienceQuestion.fromJson));
    } on TimeoutException {
      throw const TriviaException(
        'The request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const TriviaException(
        'Could not reach Open Trivia DB. Check your connection and try again.',
      );
    } on FormatException {
      throw const TriviaException(
        'Open Trivia DB returned incomplete or invalid questions. Please try again.',
      );
    }
  }

  Never _rateLimited() {
    // Give the service a full cooldown after it reports a rate limit.
    _sinceRequest.reset();
    throw const TriviaException(
      'Open Trivia DB is receiving requests too quickly. Retry will wait '
      'for the five-second cooldown before sending another request.',
    );
  }
}
