# Naija Kitchen: Generative UI in Flutter

Workshop app for **"Stop Building Screens: Generative UI in Flutter with Gemini
and Firebase AI Logic"**, DevFest Ado Ekiti 2026.

You describe a dish. Gemini (through Firebase AI Logic) decides which widgets to
show, and the [`genui`](https://pub.dev/packages/genui) package renders them as
real Flutter widgets: a recipe card, a servings stepper, an ingredient checklist.

**Following along in the workshop?** Open [WORKSHOP.md](WORKSHOP.md) for the copy-paste walkthrough, step by step.

## Checkpoints

Each step is a git tag. Jump to any of them with `git checkout <tag>`.

| Tag      | What you have                                                   |
| -------- | --------------------------------------------------------------- |
| `step-1` | Text chatbot: Firebase AI Logic + Gemini, streaming             |
| `step-2` | genui wired in: Gemini builds UI from the basic catalog         |
| `step-3` | Custom `RecipeCard` catalog item with a "Start cooking" action  |
| `step-4` | `ServingsStepper` + `IngredientChecklist` sharing the data model |
| `step-5` | Steered system prompt, guardrails, logging, DevFest theme      |
| `step-6` | Final: idiomatic Dart 3 (patterns, extension types, dot shorthands) |

## Setup (10 minutes, do it before the workshop)

1. Flutter 3.35 or newer (`flutter --version`).
2. Install the Firebase CLI (`npm i -g firebase-tools`) and log in (`firebase login`).
3. Install FlutterFire: `dart pub global activate flutterfire_cli`.
4. In the [Firebase console](https://console.firebase.google.com), create a
   project, open **AI Logic**, and enable the **Gemini Developer API**
   (free tier, no billing needed).
5. From this folder run `flutterfire configure` and pick that project.
   It overwrites `lib/firebase_options.dart`, and that file then carries over
   when you check out each step.
6. Run on Chrome. It is the fastest option and needs no Xcode or Gradle:

   ```bash
   flutter pub get
   flutter run -d chrome
   ```

## Model

`lib/gemini.dart` uses `gemini-3.8-flash`. If you hit a quota, change it to
`gemini-3.5-flash-lite`.

## No Wi-Fi? Offline demo mode

```bash
flutter run -d chrome --dart-define=OFFLINE_DEMO=true
```

This replays a recorded Gemini conversation (jollof recipe, then cooking
steps) through the same genui parser and catalog. Firebase is never touched,
so it works without running `flutterfire configure`.

## Tests

`flutter test` streams canned Gemini replies through the real genui pipeline.
The tests check that surfaces render, that the servings stepper rescales the
checklist through the data model, and that "Start cooking" sends the event
back to the model. No network is needed.
