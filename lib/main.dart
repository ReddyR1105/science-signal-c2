import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'trivia_api.dart';

void main() => runApp(const ScienceSignalApp());

const _ink = Color(0xFF262443);
const _muted = Color(0xFF585670);
const _paper = Color(0xFFF5F3FC);
const _lavender = Color(0xFFEAE4F8);
const _line = Color(0xFFDCD6EC);
const _teal = Color(0xFF126761);
const _green = Color(0xFF176240);
const _greenSurface = Color(0xFFE3F5E9);
const _red = Color(0xFF9C2D43);
const _redSurface = Color(0xFFFFE9ED);

class ScienceSignalApp extends StatelessWidget {
  const ScienceSignalApp({super.key, this.api});

  final TriviaApi? api;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: _teal,
      primary: _teal,
      surface: _paper,
      onSurface: _ink,
    );
    return MaterialApp(
      title: 'Science Signal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: _paper,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: _QuizScreen(api: api),
    );
  }
}

enum _RoundState { loading, error, ready, answered, finished }

class _QuizScreen extends StatefulWidget {
  const _QuizScreen({this.api});

  final TriviaApi? api;

  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<_QuizScreen> {
  late final http.Client? _ownedClient;
  late final TriviaApi _api;
  _RoundState _state = _RoundState.loading;
  List<ScienceQuestion> _questions = const [];
  final _answers = <Answer>[];
  String? _error;
  bool _isFetching = false;
  bool _isSubmitting = false;
  String? _submittedPayload;

  int get _score => _answers.indexed
      .where((entry) => entry.$2 == _questions[entry.$1].correctAnswer)
      .length;

  @override
  void initState() {
    super.initState();
    _ownedClient = widget.api == null ? http.Client() : null;
    _api = widget.api ?? TriviaApi(_ownedClient!);
    _startRound();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  Future<void> _startRound() async {
    if (_isFetching || _isSubmitting) return;
    setState(() {
      _isFetching = true;
      _state = _RoundState.loading;
      _questions = const [];
      _answers.clear();
      _error = null;
      _submittedPayload = null;
    });

    try {
      final questions = await _api.fetchQuestions();
      if (!mounted) return;
      setState(() {
        _isFetching = false;
        _questions = questions;
        _state = _RoundState.ready;
      });
    } on TriviaException catch (error) {
      if (!mounted) return;
      setState(() {
        _isFetching = false;
        _error = error.message;
        _state = _RoundState.error;
      });
    }
  }

  void _select(Answer answer) {
    if (_state != _RoundState.ready) return;
    setState(() {
      _answers.add(answer);
      _state = _RoundState.answered;
    });
  }

  void _continue() {
    if (_state != _RoundState.answered) return;
    setState(() {
      _state = _answers.length == _questions.length
          ? _RoundState.finished
          : _RoundState.ready;
    });
  }

  Future<void> _simulateSubmission() async {
    if (_state != _RoundState.finished ||
        _isSubmitting ||
        _submittedPayload != null) {
      return;
    }
    final payload = {
      'score': _score,
      'total': _questions.length,
      'category': TriviaApi.category,
    };
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submittedPayload = const JsonEncoder.withIndent('  ').convert(payload);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_state) {
      _RoundState.loading => _loading(),
      _RoundState.error => _failure(),
      _RoundState.ready || _RoundState.answered => _question(),
      _RoundState.finished => _results(),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _paper,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _lavender,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.science_outlined, color: _ink),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Science Signal',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _loading() => ListView(
    key: const ValueKey('loading'),
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
    children: const [
      _Panel(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading science questions...', textAlign: TextAlign.center),
          ],
        ),
      ),
    ],
  );

  Widget _failure() => ListView(
    key: const ValueKey('error'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Icon(Icons.cloud_off_outlined, color: _teal, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load questions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _startRound,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _question() {
    final answered = _state == _RoundState.answered;
    final index = _answers.length - (answered ? 1 : 0);
    final question = _questions[index];
    final selected = answered ? _answers[index] : null;
    final correct = selected == question.correctAnswer;
    final progressLabel = 'Question ${index + 1} of ${_questions.length}';

    return ListView(
      key: ValueKey('question-$index'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          TriviaApi.category,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: _teal, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(progressLabel, style: const TextStyle(color: _muted)),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (index + 1) / _questions.length,
          semanticsLabel: progressLabel,
          minHeight: 7,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: _line,
        ),
        const SizedBox(height: 20),
        _Panel(
          child: Text(
            question.text,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
          ),
        ),
        const SizedBox(height: 18),
        for (final answer in Answer.values) ...[
          _answerButton(answer, question.correctAnswer, selected),
          const SizedBox(height: 10),
        ],
        if (answered) ...[
          Semantics(
            liveRegion: true,
            child: _Panel(
              background: correct ? _greenSurface : _redSurface,
              border: Colors.transparent,
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Icon(
                    correct ? Icons.check_circle_outline : Icons.info_outline,
                    color: correct ? _green : _red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      correct
                          ? 'Correct!'
                          : 'Incorrect. The correct answer is ${question.correctAnswer.label}.',
                      style: TextStyle(
                        color: correct ? _green : _red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _continue, child: const Text('Continue')),
        ],
      ],
    );
  }

  Widget _answerButton(Answer answer, Answer correctAnswer, Answer? selected) {
    final showCorrect = selected != null && answer == correctAnswer;
    final showIncorrect = selected == answer && !showCorrect;
    final foreground = showCorrect ? _green : (showIncorrect ? _red : _ink);
    final background = showCorrect
        ? _greenSurface
        : (showIncorrect ? _redSurface : Colors.white);

    return OutlinedButton(
      onPressed: selected == null ? () => _select(answer) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background,
        side: BorderSide(
          color: showCorrect || showIncorrect ? foreground : _line,
        ),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        children: [
          Icon(
            showCorrect
                ? Icons.check_circle_outline
                : (showIncorrect
                      ? Icons.cancel_outlined
                      : Icons.circle_outlined),
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              answer.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results() {
    final score = _score;
    final total = _questions.length;
    final feedback = score == total
        ? 'Perfect round!'
        : score >= 3
        ? 'Good work!'
        : 'Keep exploring!';
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _Panel(
          background: _ink,
          border: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Final score',
                style: TextStyle(
                  color: Color(0xFFDCD3F3),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                children: [
                  Text(
                    '$score / $total',
                    style: textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${(100 * score / total).round()}%',
                    style: textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFA5E6D9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(feedback, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 4,
                children: [
                  Text(
                    '$score correct',
                    style: const TextStyle(color: Color(0xFFA5E6D9)),
                  ),
                  Text(
                    '${total - score} incorrect',
                    style: const TextStyle(color: Color(0xFFFFCCD4)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _isSubmitting || _submittedPayload != null
              ? null
              : _simulateSubmission,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            _isSubmitting
                ? 'Simulating submission...'
                : 'Simulate Score Submission',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _startRound,
          icon: const Icon(Icons.replay),
          label: const Text('Play Again'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        if (_submittedPayload case final payload?) ...[
          const SizedBox(height: 14),
          _Panel(
            background: _lavender,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simulation completed. No score was saved to a server.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  payload,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Answer review',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < total; index++) ...[
          _review(index),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _review(int index) {
    final question = _questions[index];
    final selected = _answers[index];
    final isCorrect = selected == question.correctAnswer;
    final accent = isCorrect ? _green : _red;

    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(color: _muted),
              ),
              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'Your Answer: ${selected.label}',
            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
          ),
          Text(
            'Correct Answer: ${question.correctAnswer.label}',
            style: const TextStyle(color: _green, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.background = Colors.white,
    this.border = _line,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final Color background;
  final Color border;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Padding(padding: padding, child: child),
  );
}
