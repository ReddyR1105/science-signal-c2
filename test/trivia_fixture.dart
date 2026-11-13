import 'dart:convert';

Map<String, Object> questionEntry(int index, {String prefix = 'Science'}) => {
  'question': Uri.encodeComponent('$prefix #$index: π + energy?'),
  'correct_answer': index.isOdd ? '%54rue' : '%46alse',
  'incorrect_answers': [index.isOdd ? '%46alse' : '%54rue'],
};

String responseBody({String prefix = 'Science'}) => jsonEncode({
  'response_code': 0,
  'results': [
    for (var index = 1; index <= 5; index++)
      questionEntry(index, prefix: prefix),
  ],
});
