---
name: ci-cd
description: Continuous integration and delivery — GitHub Actions workflow for analyze/test/build, Firebase App Distribution, and release practices. Use when setting up or modifying CI pipelines, GitHub Actions workflows, automated builds, or app distribution.
---

# CI/CD

Source: *Real-World Flutter by Tutorials* ch. 15 (Automating Test Executions &
Build Distributions). Ready-to-copy workflow in
[references/cicd.yml](references/cicd.yml).

## Principles (ch. 15 Key Points)

- Automating test execution, building, and deployment saves time and removes
  repetitive, error-prone manual work — that practice is CI/CD.
- Pick a branching workflow and let CI mirror it: **Gitflow** (feature → develop →
  release → main) or **trunk-based** — the book's pipeline triggers on PRs to and
  pushes of `develop`.
- Split the pipeline into jobs so failures are cheap to locate: a fast **test** job
  gating everything, and platform **build/distribute** jobs.
- Distribute pre-release builds to an internal tester group via **Firebase App
  Distribution**; end users get store releases (that step uses **fastlane**, which
  the book recommends especially for iOS pipelines).
- Improve on the book's own known gaps: automate build-number incrementing and add
  failure reporting/notifications to the workflow.

## The workflow shape

`.github/workflows/cicd.yml` — modernized from the book (current action majors,
single-package commands instead of the makefile, pinned stable Flutter channel):

```yaml
name: Test, build and deploy
on:
  pull_request:
    branches: [develop]
  push:
    branches: [develop]
permissions: read-all

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: flutter analyze
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter test

  android:
    needs: test
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: flutter build apk --dart-define=app-token=${{ secrets.APP_TOKEN }}
      - uses: wzieba/Firebase-Distribution-Github-Action@v1
        with:
          appId: ${{ secrets.FIREBASE_APP_ID_ANDROID }}
          serviceCredentialsFileContent: ${{ secrets.FIREBASE_SERVICE_CREDENTIALS }}
          groups: ${{ secrets.TESTERS_GROUPS }}
          file: build/app/outputs/flutter-apk/app-release.apk
```

## Rules

- **Secrets stay in GitHub Secrets** — API tokens enter builds via
  `--dart-define`; Firebase credentials via secrets. Nothing sensitive in the
  workflow file or the repo.
- CI runs the same commands developers run locally (`flutter analyze`,
  `dart format --set-exit-if-changed`, `flutter test`) — no CI-only magic.
- Build jobs `needs: test` — never distribute an untested build.
- Keep `permissions: read-all` (or narrower) on workflows.
- Integration tests need an emulator/device runner (e.g. a separate job using
  `reactivecircus/android-emulator-runner`) — don't put them in the unit-test job.
- iOS: building/signing requires a macOS runner and certificates; prefer fastlane
  (`match` + `gym` + `pilot`) per the book's recommendation when iOS delivery is
  needed.

## Local parity commands

```bash
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
flutter test --coverage
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```
