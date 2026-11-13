import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:science_signal_c2/trivia_api.dart';

import 'trivia_fixture.dart';

void main() {
  TriviaApi apiFor(String body, {int status = 200}) =>
      TriviaApi(MockClient((_) async => http.Response(body, status)));

  Matcher errorWith(String message) => isA<TriviaException>().having(
    (error) => error.message,
    'message',
    contains(message),
  );

  test('T01–T03, T08: GET contract and five decoded question models', () async {
    final api = TriviaApi(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'opentdb.com');
        expect(request.url.path, '/api.php');
        expect(request.url.queryParameters, {
          'amount': '5',
          'category': '17',
          'difficulty': 'medium',
          'type': 'boolean',
          'encode': 'url3986',
        });
        return http.Response(responseBody(), 200);
      }),
    );

    final questions = await api.fetchQuestions();
    expect(questions, hasLength(5));
    expect(questions.first.text, 'Science #1: π + energy?');
    expect(questions.first.correctAnswer, Answer.trueAnswer);
    expect(questions.first.incorrectAnswer, Answer.falseAnswer);
    expect(questions[1].correctAnswer, Answer.falseAnswer);
    expect(questions[1].incorrectAnswer, Answer.trueAnswer);
  });

  test('T04: rejects non-200 HTTP even when its body looks successful', () {
    return expectLater(
      apiFor(responseBody(), status: 503).fetchQuestions(),
      throwsA(errorWith('HTTP 503')),
    );
  });

  test('T05: rejects a nonzero API response code', () {
    return expectLater(
      apiFor('{"response_code":1}').fetchQuestions(),
      throwsA(errorWith('code 1')),
    );
  });

  test('T05: API code 5 and HTTP 429 explain rate limiting', () async {
    for (final api in [
      apiFor('{"response_code":5}'),
      apiFor('', status: 429),
    ]) {
      await expectLater(
        api.fetchQuestions(),
        throwsA(errorWith('five-second cooldown')),
      );
    }
  });

  test('T06: rejects malformed JSON', () {
    return expectLater(
      apiFor('{').fetchQuestions(),
      throwsA(errorWith('invalid questions')),
    );
  });

  final invalidBodies = <String, Object>{
    'missing response code': {'results': List.filled(5, questionEntry(1))},
    'string response code': {
      'response_code': '0',
      'results': List.filled(5, questionEntry(1)),
    },
    'missing results': {'response_code': 0},
    'non-list results': {'response_code': 0, 'results': {}},
    'four entries': {
      'response_code': 0,
      'results': List.filled(4, questionEntry(1)),
    },
    'six entries': {
      'response_code': 0,
      'results': List.filled(6, questionEntry(1)),
    },
  };

  final invalidEntries = <String, Object>{
    'non-object question': 42,
    'blank question': {...questionEntry(1), 'question': '%20'},
    'missing question': questionEntry(1)..remove('question'),
    'missing correct answer': questionEntry(1)..remove('correct_answer'),
    'non-boolean answer': {...questionEntry(1), 'correct_answer': 'Maybe'},
    'duplicate answers': {
      ...questionEntry(1),
      'incorrect_answers': ['True'],
    },
    'extra incorrect answers': {
      ...questionEntry(1),
      'incorrect_answers': ['False', 'False'],
    },
    'invalid percent encoding': {...questionEntry(1), 'question': 'A%ZZ'},
    'invalid encoded UTF-8': {...questionEntry(1), 'question': '%FF'},
  };

  for (final MapEntry(:key, :value) in invalidEntries.entries) {
    invalidBodies[key] = {
      'response_code': 0,
      'results': [...List.filled(4, questionEntry(1)), value],
    };
  }
  for (final MapEntry(:key, :value) in invalidBodies.entries) {
    test('T07: rejects $key', () {
      return expectLater(
        apiFor(jsonEncode(value)).fetchQuestions(),
        throwsA(errorWith('invalid questions')),
      );
    });
  }

  test('client exceptions have readable network guidance', () {
    final api = TriviaApi(
      MockClient((_) async => throw http.ClientException('offline')),
    );
    return expectLater(
      api.fetchQuestions(),
      throwsA(errorWith('Check your connection')),
    );
  });

  test('T30: times out when the server does not answer', () {
    final response = Completer<http.Response>();
    final api = TriviaApi(
      MockClient((_) => response.future),
      timeout: const Duration(milliseconds: 10),
    );
    return expectLater(api.fetchQuestions(), throwsA(errorWith('timed out')));
  });

  test('successive requests, including rate-limit retry, are spaced', () async {
    final stopwatch = Stopwatch()..start();
    final requestTimes = <Duration>[];
    final api = TriviaApi(
      MockClient((_) async {
        requestTimes.add(stopwatch.elapsed);
        return requestTimes.length == 1
            ? http.Response('{"response_code":5}', 200)
            : http.Response(responseBody(), 200);
      }),
    );
    await expectLater(api.fetchQuestions(), throwsA(errorWith('cooldown')));
    await api.fetchQuestions();
    expect(
      requestTimes.last - requestTimes.first,
      greaterThanOrEqualTo(const Duration(seconds: 5)),
    );
  }, timeout: const Timeout(Duration(seconds: 15)));
}
