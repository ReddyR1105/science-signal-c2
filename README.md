# Science Signal C2

CSC 4360 Mobile App Development · In-Class Activity #15 · Index2

Science Signal is a Flutter quiz for Android. Each round has five medium-difficulty true-or-false questions in Science & Nature.

## Run on Android

From the project folder, use Flutter 3.47.4 with Dart 3.13.3 or a compatible SDK. Start an Android emulator or connect an Android device with USB debugging enabled.

```sh
flutter pub get
flutter devices
flutter run
```

If multiple devices are listed, use `flutter run -d <device-id>`. The Android main manifest declares the Internet permission.

## Questions and rounds

The app uses `Uri.https` to send an asynchronous GET request to Open Trivia DB.

```text
https://opentdb.com/api.php?amount=5&category=17&difficulty=medium&type=boolean&encode=url3986
```

The parameters request five results from category 17 (Science & Nature) with medium difficulty, boolean questions, and RFC 3986 URL encoding. The client requires HTTP 200, integer API response code 0, and exactly five entries. Each entry must have a nonblank question and one correct and one opposing incorrect boolean answer. The client decodes the question and both answer fields with `Uri.decodeComponent` and creates a `ScienceQuestion` for each entry. An invalid entry invalidates the entire round.

The screen uses `setState` to move through loading, error, ready, answered, and finished states. A request guard prevents overlapping fetches, and asynchronous completions check `mounted` before updating the screen. Network failures and timeouts show Retry. A monotonic timer spaces requests by at least five seconds. Code 5 and HTTP 429 show rate-limit guidance and restart the cooldown.

Selecting True or False stores one answer and immediately locks both buttons. The score is computed from saved answers, so extra taps cannot award extra points. Continue reveals the next question. At the end, the scrollable review shows the final score and percentage, counts, and the original question, saved selection, and correct answer for all five questions.

Play Again clears the answers and submission state and requests a fresh round. Open Trivia DB can return questions seen in previous rounds. If the request fails, the screen offers Retry.

## Score simulation

GET retrieves quiz questions. A POST could submit scores to a backend that provides a score endpoint. **Simulate Score Submission** builds a JSON payload with the actual score, total, and category, waits briefly, and displays the payload. The controls prevent repeated submission during processing. The simulation completes locally without a cloud write.

Trivia questions are provided by [Open Trivia DB](https://opentdb.com/api_config.php) under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
