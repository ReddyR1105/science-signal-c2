import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:science_signal_c2/main.dart';
import 'package:science_signal_c2/trivia_api.dart';

import 'trivia_fixture.dart';

TriviaApi mockApi(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 12),
}) => TriviaApi(
  MockClient(handler),
  requestInterval: Duration.zero,
  timeout: timeout,
);

Future<void> openQuiz(WidgetTester tester, {TriviaApi? api}) async {
  await tester.pumpWidget(
    ScienceSignalApp(
      api: api ?? mockApi((_) async => http.Response(responseBody(), 200)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String answer) async {
  final button = find.widgetWithText(OutlinedButton, answer);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> advance(WidgetTester tester) async {
  final next = find.widgetWithText(FilledButton, 'Continue');
  await tester.ensureVisible(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> finishRound(WidgetTester tester, List<String> answers) async {
  for (final answer in answers) {
    await choose(tester, answer);
    await advance(tester);
  }
}

const allCorrect = ['True', 'False', 'True', 'False', 'True'];
const allIncorrect = ['False', 'True', 'False', 'True', 'False'];
const mixed = ['True', 'True', 'True', 'True', 'True'];

void main() {
  testWidgets('T09: pending GET shows loading with quiz controls absent', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await tester.pumpWidget(
      ScienceSignalApp(api: mockApi((_) => response.future)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading science questions...'), findsOneWidget);
    expect(find.text('True'), findsNothing);

    response.complete(http.Response(responseBody(), 200));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('T10: failed request has a working Retry action', (tester) async {
    var requests = 0;
    await openQuiz(
      tester,
      api: mockApi(
        (_) async => ++requests == 1
            ? http.Response('', 503)
            : http.Response(responseBody(), 200),
      ),
    );

    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(find.text('True'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Question 1 of 5'), findsOneWidget);
  });

  testWidgets('T11–T19: answers lock, Continue advances, and score is 3/5', (
    tester,
  ) async {
    await openQuiz(tester);
    expect(find.text('Continue'), findsNothing);

    final trueButton = find.widgetWithText(OutlinedButton, 'True');
    final falseButton = find.widgetWithText(OutlinedButton, 'False');
    // Tap without pumping to exercise the guard before disabled UI rebuilds.
    await tester.tap(trueButton);
    await tester.tap(trueButton);
    await tester.tap(falseButton);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(trueButton).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(falseButton).onPressed, isNull);
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Question 1 of 5'), findsOneWidget);

    await advance(tester);
    expect(find.text('Question 2 of 5'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.4,
    );
    await choose(tester, 'True');
    expect(
      find.text('Incorrect. The correct answer is False.'),
      findsOneWidget,
    );
    await advance(tester);
    expect(find.text('Question 3 of 5'), findsOneWidget);
    await choose(tester, 'False');
    expect(find.text('Incorrect. The correct answer is True.'), findsOneWidget);
    await advance(tester);
    expect(find.text('Question 4 of 5'), findsOneWidget);
    await choose(tester, 'False');
    expect(find.text('Correct!'), findsOneWidget);
    await advance(tester);
    expect(find.text('Question 5 of 5'), findsOneWidget);
    await choose(tester, 'True');
    await advance(tester);

    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('3 correct'), findsOneWidget);
    expect(find.text('2 incorrect'), findsOneWidget);
  });

  testWidgets('T20–T21: review shows all saved answers on a small screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openQuiz(tester);
    await finishRound(tester, mixed);

    for (var index = 1; index <= 5; index++) {
      final heading = find.text('Question $index');
      await tester.scrollUntilVisible(
        heading,
        130,
        scrollable: find.byType(Scrollable),
      );
      final card = find
          .ancestor(of: heading, matching: find.byType(Column))
          .first;
      final isCorrect = index.isOdd;
      for (final label in [
        'Science #$index: π + energy?',
        'Your Answer: True',
        'Correct Answer: ${isCorrect ? 'True' : 'False'}',
        isCorrect ? 'Correct' : 'Incorrect',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('T22–T23: replay loads fresh questions and clears prior round', (
    tester,
  ) async {
    var requests = 0;
    final replay = Completer<http.Response>();
    await openQuiz(
      tester,
      api: mockApi(
        (_) async => ++requests == 1
            ? http.Response(responseBody(), 200)
            : replay.future,
      ),
    );
    await finishRound(tester, allCorrect);
    await tester.tap(find.text('Simulate Score Submission'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('No score was saved'), findsOneWidget);
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    expect(requests, 2);
    expect(find.text('Loading science questions...'), findsOneWidget);
    expect(find.text('5 / 5'), findsNothing);
    replay.complete(http.Response(responseBody(prefix: 'New round'), 200));
    await tester.pumpAndSettle();
    expect(find.text('New round #1: π + energy?'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await finishRound(tester, allIncorrect);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.textContaining('No score was saved'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Simulate Score Submission'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('T24: a failed replay shows Retry and hides the prior round', (
    tester,
  ) async {
    var requests = 0;
    await openQuiz(
      tester,
      api: mockApi(
        (_) async => ++requests == 1
            ? http.Response(responseBody(), 200)
            : http.Response('', 503),
      ),
    );
    await finishRound(tester, allCorrect);
    await tester.tap(find.text('Play Again'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(find.text('Answer review'), findsNothing);
  });

  testWidgets('T25–T27: submission locks controls and displays local payload', (
    tester,
  ) async {
    var requests = 0;
    await openQuiz(
      tester,
      api: mockApi((request) async {
        expect(request.method, 'GET');
        requests++;
        return http.Response(responseBody(), 200);
      }),
    );
    await finishRound(tester, mixed);
    final submit = find.text('Simulate Score Submission');
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final (type, label) in [
      (FilledButton, 'Simulating submission...'),
      (OutlinedButton, 'Play Again'),
    ]) {
      expect(
        tester
            .widget<ButtonStyleButton>(find.widgetWithText(type, label))
            .onPressed,
        isNull,
      );
    }

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Simulation completed. No score was saved to a server.'),
      findsOneWidget,
    );
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      '{\n  "score": 3,\n  "total": 5,\n  "category": "Science & Nature"\n}',
    );
    expect(requests, 1);
  });

  for (final (id, expected, answers) in [
    ('T28', 0, allIncorrect),
    ('T29', 5, allCorrect),
  ]) {
    testWidgets('$id: scores $expected out of five', (tester) async {
      await openQuiz(tester);
      await finishRound(tester, answers);
      expect(find.text('$expected / 5'), findsOneWidget);
      expect(find.text('${expected * 20}%'), findsOneWidget);
    });
  }

  testWidgets('T30: timeout is visible and recoverable via Retry', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    await tester.pumpWidget(
      ScienceSignalApp(
        api: mockApi(
          (_) async => ++requests == 1
              ? response.future
              : http.Response(responseBody(), 200),
          timeout: const Duration(milliseconds: 100),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pumpAndSettle();
    expect(find.textContaining('timed out'), findsOneWidget);
    expect(find.text('True'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 5'), findsOneWidget);
    response.complete(http.Response(responseBody(prefix: 'Old'), 200));
    await tester.pumpAndSettle();
    expect(find.text('Science #1: π + energy?'), findsOneWidget);
    expect(find.text('Old #1: π + energy?'), findsNothing);
  });
}
