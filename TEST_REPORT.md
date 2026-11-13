# Science Signal C2 test report

CSC 4360 Mobile App Development · In-Class Activity #15 · Index2

## Environment

- Flutter 3.47.4 (stable), Dart 3.13.3, Windows host.
- Pixel 4a Android Virtual Device, Android 17 (API 37), x86-64, `emulator-5554`.
- Android debug APK built with `flutter build apk --debug` and installed and launched using Android SDK Platform Tools (`adb install -r` and `adb shell am start`).

## Local checks

| Command | Result |
| --- | --- |
| `flutter doctor -v` | Flutter and Android toolchain available |
| `flutter pub add http` and `flutter pub get` | Dependencies resolved, including HTTP 1.6.0 |
| `dart format .` | All five Dart files formatted |
| `flutter analyze` | No issues found |
| `flutter test --reporter expanded` | 33 passed, covering T01–T30 |
| `flutter devices` | Detected the Pixel 4a emulator |
| `flutter build apk --debug` | Built the Android debug APK in the project and from a clean copy of the submission folder |

One initial widget test failed because it tapped Continue before the small-screen test viewport updated after a scroll. The test now settles the viewport before tapping. The final run had no failing or blocked automated tests.

| Assignment tests | Coverage |
| --- | --- |
| T01–T03, T08 | HTTPS GET path and parameters, HTTP 200 and API code 0, exactly five models, Unicode and percent-encoded fields |
| T04–T07 | HTTP error, nonzero code, code 5 and HTTP 429, malformed JSON and invalid response or question fields |
| T09–T10 | Pending-request loading and successful Retry after HTTP failure |
| T11–T19 | Both answer choices, answer locking, repeated taps, Continue guard, progress, completion, and 3/5 score |
| T20–T21 | Scroll to all five review cards at 320 × 568 logical pixels and check the saved answers, correct answers, and status |
| T22–T24 | Replay clears prior results and submission state, requests another round, and shows a recoverable failure |
| T25–T27 | Dynamic score payload, duplicate-submission protection, and local-only confirmation |
| T28–T30 | 0/5 and 5/5 results, network timeout, successful Retry, and ignored late response |

Additional API tests verify readable client errors and the default five-second request spacing after a rate-limit response. Automated tests use mocked HTTP responses.

## Android runtime

1. Installed and opened the debug APK on the Pixel 4a emulator. A live Open Trivia DB fetch provided five decoded questions.
2. Selected the correct answer to question 1 and observed green feedback. Repeated the original tap and tapped the opposite button before continuing. The first answer stayed locked, and the round score matched the saved selections.
3. Selected an incorrect answer and observed a red selection, green correct answer, and written feedback. Continued through question 5.
4. Observed 3/5 (60%), three correct and two incorrect. Scrolled through all five review entries and checked the saved and correct answers.
5. Ran Simulate Score Submission. The screen displayed score 3, total 5, category Science & Nature, and the confirmation that no score was saved to a server.
6. Disabled emulator Wi-Fi and mobile data, then selected Play Again. The app showed a connection error and Retry. Restored connectivity, selected Retry, observed loading, and received a fresh question 1 with enabled answer choices.
7. Completed the recovered round, selected Play Again online, observed the loading indicator, and verified that a new live round started at question 1 with no selection or review on screen.
8. No overflow or fatal exception appeared in the exercised flow or the inspected app log. The small-screen widget test also passed.

## Screenshots

All screenshots are direct captures from the running Android emulator.

- [01_question.png](screenshots/01_question.png)
- [02_correct_feedback.png](screenshots/02_correct_feedback.png)
- [03_incorrect_feedback.png](screenshots/03_incorrect_feedback.png)
- [04_results_review.png](screenshots/04_results_review.png)
- [05_score_simulation.png](screenshots/05_score_simulation.png)
- [06_error_retry.png](screenshots/06_error_retry.png)
- [07_retry_recovered.png](screenshots/07_retry_recovered.png)
- [08_replay_loading.png](screenshots/08_replay_loading.png)

## Scope and limitations

Android runtime verification used the emulator. Open Trivia DB availability affects live rounds, and the service may return a question seen in an earlier round. Rate-limit and timeout branches were exercised with mocks. Score submission was verified as a local simulation.
